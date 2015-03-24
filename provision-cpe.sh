#!/bin/bash
##!/usr/bin/env bash

HOSTNAME=$1
OPENVPN=$2
DISCOVERY=$3

echo "Fix ssh to allow password login"
ROOTPWD="secret"
echo "root:secret"|chpasswd
sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# Disable LANG_ALL to avoid warnings when logging in from OSX
sed -i 's/^AcceptEnv LANG LC_*/#AcceptEnv LANG LC_*/' /etc/ssh/sshd_config

service ssh restart

echo "Setting hostname to $HOSTNAME"
hostname $HOSTNAME
cat <<EOF > /etc/hostname
$HOSTNAME
EOF

# add opencontrail binary repository
curl -L http://www.opencontrail.org/ubuntu-repo/repo_key | sudo apt-key add -
APT_SOURCES_FILE=${APT_SOURCES_FILE:-/etc/apt/sources.list.d/opencontrail.list}
echo "deb [arch=amd64] http://ubuntu-repo.opencontrail.org.s3-website-us-east-1.amazonaws.com opencontrail-stock-ubuntu1404-icehouse main" >> ${APT_SOURCES_FILE}
echo "deb [arch=amd64] http://ubuntu-repo.opencontrail.org.s3-website-us-east-1.amazonaws.com/opencontrail-r200-icehouse opencontrail-r200-icehouse main" >> ${APT_SOURCES_FILE}

echo "apt-get update ..."
apt-get update >/dev/null 2>&1
echo "installing openvpn client"
apt-get install -y openvpn bridge-utils

# disable the annoying 'waiting for network connectivity' delay
sed -i 's/sleep/#sleep/' /etc/init/failsafe.conf

cat > /etc/openvpn/client.conf <<EOF
client
dev tap
proto udp
remote $OPENVPN 1194
resolv-retry infinite
nobind
persist-key
persist-tun
ca ca.crt
cert $HOSTNAME.crt
key $HOSTNAME.key
ns-cert-type server
comp-lzo
verb 3
EOF

cp /vagrant/$HOSTNAME.* /etc/openvpn/
cp /vagrant/ca.crt /etc/openvpn/

sed -i 's/#net.ipv4.ip_forward/net.ipv4.ip_forward/' /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

# we don't want openvpn to start before vrouter. Disable auto-enable
#update-rc.d -f openvpn remove

echo "starting openvpn client"
service openvpn start


#echo "Creating testbed.py ..."
#cd /opt/contrail/utils/fabfile/testbeds/
#cp testbed_singlebox_example.py testbed.py
#sed -i "s/1.1.1.1/$IPADDR/" testbed.py

#echo "login and launch postprocess.sh"

apt-get install -y contrail-setup contrail-vrouter-agent contrail-vrouter-init contrail-vrouter-dkms contrail-utils contrail-nodemgr

cat > /etc/contrail/agent_param <<EOF
LOG=/var/log/contrail.log
CONFIG=/etc/contrail/agent.conf
prog=/usr/bin/contrail-vrouter-agent
kmod=vrouter
pname=contrail-vrouter-agent
LIBDIR=/usr/lib64
DEVICE=vhost0
dev=tap0
vgw_subnet_ip=("0.0.0.0/0")
vgw_intf=(vgw)
LOGFILE=--log-file=/var/log/contrail/vrouter.log
EOF

# Get HW address of tap0 into default_pmac
HWADDR=`ifconfig tap0|head -1|cut -d ' ' -f11`
echo -n "$HWADDR" > /etc/contrail/default_pmac

echo "Setting discovery server"
cat > /etc/contrail/vrouter_nodemgr_param <<EOF
DISCOVERY=$DISCOVERY
EOF

IPADDR=`ifconfig tap0|grep 'inet addr'|cut -d':' -f2|cut -d' ' -f1`
GATEWAY=`ip route|grep tap0|grep 0.0.0.0|cut -d' ' -f3`
SUBNET=`ip route|grep tap0|grep link|cut -d' ' -f1`
echo "tap0: address $IPADDR on subnet $SUBNET with default gateway $GATEWAY"

cat > /etc/contrail/contrail-vrouter-agent.conf <<EOF
[CONTROL-NODE]
[DEFAULT]
log_file=/var/log/contrail/contrail-vrouter-agent.log
log_level=SYS_NOTICE
log_local=1
[DISCOVERY]
server=$DISCOVERY
max_control_nodes=1
[DNS]
[HYPERVISOR]
[FLOWS]
[METADATA]
[NETWORKS]
control_network_ip=$IPADDR
[VIRTUAL-HOST-INTERFACE]
name=vhost0
ip=$IPADDR
gateway=$GATEWAY
physical_interface=tap0
[GATEWAY-0]
routing_instance=default-domain:admin:$HOSTNAME-lan:$HOSTNAME-lan
interface=vgw
ip_blocks=0.0.0.0/0
routes=192.168.2.0/24 10.0.2.0/24

[SERVICE-INSTANCE]
netns_command=/usr/bin/opencontrail-vrouter-netns
EOF

echo "adding vhost0 entry to /etc/network/interfaces"
cat >> /etc/network/interfaces <<EOF

#CONTRAIL-BEGIN
auto vhost0
iface vhost0 inet static
    pre-up echo -n "\`ifconfig tap0|head -1|cut -d ' ' -f11\`" > /etc/contrail/default_pmac
    pre-up ip route del $SUBNET dev tap0
    pre-up ip route del 0.0.0.0/1 dev tap0
    pre-up ip route del default dev eth0
    pre-up /opt/contrail/bin/if-vhost0
    netmask 255.255.255.0
    network_name application
    address $IPADDR
    gateway $GATEWAY
#CONTRAIL-END
EOF

#cat > /etc/static-routes <<EOF
#echo "before static-routes removed" >>/tmp/my.log
#ifconfig -a >> /tmp/my.log
#ip route >> /tmp/my.log
#ip route del $SUBNET dev tap0
#ip route add 192.168.100.0/24 via $GATEWAY
#ip route >> /tmp/my.log
#echo "done" >> /tmp/my.log
#EOF
#chmod a+rx /etc/static-routes

# to avoid complaints from contrail-vrouter-nodemgr...
mkdir /var/crashes

apt-get -y --purge autoremove  cloud-init cloud-guest-utils

cat > /etc/rc.local <<EOF
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

echo "waiting for openvpn to be up and running"
sleep 20

ip route del 192.168.100.0/24
ip route add 192.168.100.0/24 via $GATEWAY
ip route add 192.168.0.0/24 dev vgw

exit 0
EOF

echo "all done."

echo "***************************************************"
echo "*   PLEASE RELOAD THIS VAGRANT BOX BEFORE USE     *"
echo "***************************************************"

exit 0


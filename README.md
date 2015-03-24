opencontrail-vrouter-openvpn
============================

This is a proof-of-concept to create an opencontrail based vrouter that connects via SSL (OpenVPN tap interface) to a Contrail setup. 
The provisioning of the OpenVPN server and Contrail server installation are out-of-scope for this write-up and assumedto be up and running prior to launching and provisioning the vagrant VM cpe3:

                      +----------+
                     +----------+|   Contrail UI/Discover/Config/Control
                     | Contrail |+   Openstack Nova/neutron/glance etc
                     +----+-----+    
           192.168.100/24 |.10
         ---+-------------+---
            |.1
    +-------+--------+
    | OpenVPN Server |    OpenVPN server using tap interface and
    |  10.8.0.0/24   |    certificate based authentication. 
    +-------+--------+
            |5.9.31.84
            |
      Public Internet
            |
         +--+--+
         | NAT |  Optional FW/NAT offering private IP address to vrouter
         +--+--+
            |
     +=======+========+
     | OpenVPN client |   
     | cpe3 / vrouter |
     +================+

"vagrant up " downloads Ubuntu 14.04 (ubuntu/trusty64) for the selected vagrant provider (Virtualbox, VMWare Fusion or kvm), installs OpenVPN client and Opencontrail 2.0 from the binary repository documented in the opencontrail quick start guide at http://www.opencontrail.org/opencontrail-quick-start-guide/.
Finally a simple gateway is provisioned for a virtual network containing the CPE's hostname (cpe3 in the example). More about the simple gateway function can be found at https://github.com/Juniper/contrail-controller/wiki/Simple-Gateway


Requirements:

Valid OpenVPN client certificate must be generated and placed in the project directory, so they can be accessed by the provivisioning script provision-cpe.sh. The certificate name must match the hostname for the script to work. The example given here assumes the files cpe3.crt, cpe3.csr and cpe3.key plus the root certificate ca.crt. Consult the various howto's on the web on howto create an OpenVPN server and the required certificates, e.g. here: http://www.slsmk.com/getting-started-with-openvpn/installing-openvpn-on-ubuntu-server-12-04-or-14-04-using-tap/
Its important to use tap interfaces instead of tun, because the vrouter deals with ethernet frames.

the Vagrantfile contains 3 user changeable parameters to match your actual lab setup:

    hostname = "cpe3"       # used to build the virtual network name and must match the client certificate
    openvpn_server = "5.9.31.84"   # OpenVPN tap server to connect to
    contrail_discovery_server = "192.168.100.10"  # Contrail discovery server IP address

Howto use it:

Clone this repository to an empty directory:

    $ mkdir temp
    $ cd temp
    $ git clone git://github.com/mwiget/opencontrail-vrouter-openvpn.git
    Cloning into 'opencontrail-vrouter-openvpn'...
    remote: Counting objects: 11, done.
    remote: Compressing objects: 100% (11/11), done.
    remote: Total 11 (delta 2), reused 4 (delta 0)
    Receiving objects: 100% (11/11), 10.44 KiB | 0 bytes/s, done.
    Resolving deltas: 100% (2/2), done.
    Checking connectivity... done.
    $

This will create the following files under temp/opencontrail-vrouter-openvpn:

    $ cd opencontrail-vrouter-openvpn
    $ ls
    LICENSE   README.md Vagrantfile provision-cpe.sh
    $

Create the OpenVPN client certificates on your OpenVPN server and place them in the directory, cpe3 being assumed
as the hostname here:

    $ cp $EASYRSA/keys/cpe3.* .
    $ cp $EASYRSA/keys/ca.crt .
    $ ls
    LICENSE     ca.crt      cpe3.key
    README.md   cpe3.crt    install.log
    Vagrantfile   cpe3.csr    provision-cpe.sh

Bring up the virtual machine:

    $ vagrant up
    ==> cpe3: You assigned a static IP ending in ".1" to this machine.
    ==> cpe3: This is very often used by the router and can cause the
    ==> cpe3: network to not work properly. If the network doesn't work
    ==> cpe3: properly, try changing this IP.
    ==> cpe3: Importing base box 'ubuntu/trusty64'...
    ==> cpe3: Matching MAC address for NAT networking...
    ==> cpe3: You assigned a static IP ending in ".1" to this machine.
    ==> cpe3: This is very often used by the router and can cause the
    ==> cpe3: network to not work properly. If the network doesn't work
    ==> cpe3: properly, try changing this IP.
    ==> cpe3: Checking if box 'ubuntu/trusty64' is up to date...
    ...
    ==> cpe3: all done.
    ==> cpe3: ***************************************************
    ==> cpe3: *   PLEASE RELOAD THIS VAGRANT BOX BEFORE USE     *
    ==> cpe3: ***************************************************

See file install.log for a complete log of a successful bringup and connection of cpe3 to a contrail node at 192.168.100.10.

From here, please reboot the virtual machine in order for the vrouter kernel module to be loaded and configured correctly:

    $ vagrant reload
    
Log into contrail via ssh and check that all the services are running correctly and the vpn is established:
    
    $ vagrant ssh
    Welcome to Ubuntu 14.04.2 LTS (GNU/Linux 3.13.0-46-generic x86_64)

     * Documentation:  https://help.ubuntu.com/

     System information as of Sun Mar 22 19:25:41 UTC 2015

     System load: 0.0               Memory usage: 6%   Processes:       84
     Usage of /:  3.3% of 39.34GB   Swap usage:   0%   Users logged in: 0

     Graph this data and manage this system at:
     https://landscape.canonical.com/

     Get cloud support with Ubuntu Advantage Cloud Guest:
     http://www.ubuntu.com/business/services/cloud


     Last login: Sun Mar 22 19:25:27 2015 from 10.0.2.2
     vagrant@cpe3:~$ sudo bash
     root@cpe3:~# ping 192.168.100.10
     PING 192.168.100.10 (192.168.100.10) 56(84) bytes of data.
     64 bytes from 192.168.100.10: icmp_seq=1 ttl=62 time=60.7 ms
     ^C
     --- 192.168.100.10 ping statistics ---
     1 packets transmitted, 1 received, 0% packet loss, time 0ms
     rtt min/avg/max/mdev = 60.766/60.766/60.766/0.000 ms
     root@cpe3:~# 

     A successful ping shows connectivity from the vrouter to the Contrail discovery server.

The vrouter cpe3 will show up in the Contrail UI dashboard, though complaining about lack of configuration. This can be fixed by adding the vrouter into the Contrail configuration using the following python command (replacing the IP address 10.8.0.51 with the actual IP address assigned by the OpenVPN server and the correct admin password):

    python /opt/contrail/utils/provision_vrouter.py --host_name cpe3 --host_ip 10.8.0.51 --api_server_ip 192.168.100.10 --oper add --admin_user admin --admin_password secret123 --admin_tenant_name admin

Even without adding this configuration to Contrail config, the vrouter is fully functional and the virtual network 'cpe3-lan' (see /etc/contrail/contrail-vrouter-agent.conf) useable.


Packet header overhead in this particular setup:

    14  Ethernet header
    20  IPv4 header
     4  GRE
     4  MPLS
    --
    42 Bytes overhead

Given an IP MTU of 1500 (1514 including Ethernet header), ICMP ping packets up to a payload packetsize of 1444 can be transmitted without fragmentation:

    root@cpe2# tcpdump -n -i tap0 -e -vvv ip host 10.8.0.51
    04:52:21.134489 da:09:23:48:34:fa > 46:b2:0e:46:8b:13, ethertype IPv4 (0x0800), length 1514: (tos 0x0, ttl 63, id 31796, offset 0, flags [none], proto GRE (47), length 1500)
        192.168.100.10 > 10.8.0.51: GREv0, Flags [none], proto MPLS unicast (0x8847), length 1480
            MPLS (label 17, exp 0, [S], ttl 63)
            (tos 0x0, ttl 63, id 31796, offset 0, flags [DF], proto ICMP (1), length 1472)
        192.168.0.3 > 10.0.2.15: ICMP echo request, id 24321, seq 0, length 1452
    04:52:21.134540 46:b2:0e:46:8b:13 > da:09:23:48:34:fa, ethertype IPv4 (0x0800), length 1514: (tos 0x0, ttl 64, id 21155, offset 0, flags [none], proto GRE (47), length 1500)
        10.8.0.51 > 192.168.100.10: GREv0, Flags [none], proto MPLS unicast (0x8847), length 1480
            MPLS (label 17, exp 0, [S], ttl 63)
            (tos 0x0, ttl 63, id 21155, offset 0, flags [none], proto ICMP (1), length 1472)
        10.0.2.15 > 192.168.0.3: ICMP echo reply, id 24321, seq 0, length 1452





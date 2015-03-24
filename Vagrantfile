# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.
  # Every Vagrant virtual environment requires a box to build off of.
  #

  hostname = "cpe3"
  openvpn_server = "5.9.31.84"
  contrail_discovery_server = "192.168.100.10"

  config.vm.box = "ubuntu/trusty64"
  config.vm.provider "vmware_fusion" do |v, override|
      override.vm.box_url = "https://oss-binaries.phusionpassenger.com/vagrant/boxes/latest/ubuntu-14.04-amd64-vmwarefusion.box"
  end

  config.vm.define "#{hostname}", autostart:true do |vrouter|
    vrouter.vm.provider "virtualbox" do |v|
      v.memory = 1024
      v.cpus = 1
#      v.gui = true
    end
    vrouter.vm.provider "vmware_fusion" do |vf|
        vf.vmx["numvcpus"] = "1"
        vf.vmx["memsize"] = "1024"
    end
    vrouter.vm.provision "shell", path: "provision-cpe.sh", args: "#{hostname} #{openvpn_server} #{contrail_discovery_server}"
    vrouter.vm.network "private_network", ip: "192.168.2.1"
  end

end

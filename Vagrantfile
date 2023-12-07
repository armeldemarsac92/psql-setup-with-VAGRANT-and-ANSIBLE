# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrant configuration


  
Vagrant.configure("2") do |config|

  config.vm.define "vm_master" do |vm_master|

    vm_master.vm.box = "debian/bullseye64"

    vm_master.vm.synced_folder ".", "/vagrant", disabled: true

    vm_master.vm.network "forwarded_port", guest: 22, host: "2235", host_ip: "127.0.0.1"

    vm_master.vm.hostname = "vm-master"

    vm_master.vm.network "private_network", ip: "192.168.56.10", virtualbox_intnet: true
    
    vm_master.vm.provider "virtualbox" do |vb|

      vb.gui = false
      vb.name = "vm_master"
      vb.memory = 2048
      vb.cpus = 2

    end

    vm_master.vm.provision "ansible" do |ansible|

      ansible.playbook = "playbook_master.yml"  

    end

  end

  config.vm.define "vm_slave" do |vm_slave|

    vm_slave.vm.box = "debian/bullseye64"

    vm_slave.vm.synced_folder ".", "/vagrant", disabled: true

    vm_slave.vm.network "forwarded_port", guest: 22, host: "2236", host_ip: "127.0.0.1"

    vm_slave.vm.hostname = "vm-slave"

    vm_slave.vm.network "private_network", ip: "192.168.56.11", virtualbox_intnet: true

    vm_slave.vm.provider "virtualbox" do |vb|

      vb.gui = false
      vb.name= "vm_slave"
      vb.memory = 2048
      vb.cpus = 2

    end

    vm_slave.vm.provision "ansible" do |ansible|

      ansible.playbook = "playbook_slave.yml"

    end

  end

end

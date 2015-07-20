# vim: set ft=ruby :

Vagrant.configure(2) do |config|
    config.vm.define 'slave' do |slave|
        slave.vm.network 'private_network', ip: '192.168.123.223'
        slave.vm.box = 'hashicorp/precise32'

        slave.vm.provision 'chef_solo' do |chef|
            chef.add_recipe 'percona'
            chef.node_name = 'slave'
        end
    end
    config.vm.define 'master' do |master|
        master.vm.network 'private_network', ip: '192.168.123.222'
        master.vm.box = 'hashicorp/precise32'

        master.vm.provision 'chef_solo' do |chef|
            chef.add_recipe 'percona'
            chef.node_name = 'master'
        end
    end
end

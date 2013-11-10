# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "inf-vagrant"
  config.vm.provision :shell, :path => "bootstrap.sh"
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"

  # Enable provisioning with chef solo, specifying a cookbooks path, roles
  # path, and data_bags path (all relative to this Vagrantfile), and adding
  # some recipes and/or roles.
  #
  config.vm.provision :chef_solo do |chef|
     chef.cookbooks_path = "./cookbooks"
     chef.roles_path = "./roles"
     chef.data_bags_path = "./data_bags"
     chef.add_recipe "infantium::vagrant"

  end

end

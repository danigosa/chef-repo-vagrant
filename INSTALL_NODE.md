Chef-solo
=========

ssh key generation
==================

ssh-keygen
ssh-keygen -f key.pub -e -m pem


Provisioning Node
=================

Set up node with minimal requirements from minimal base Azure Ubuntu 12.04 LTS image
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Azure console:
- Create VM
- From gallery: Ubuntu 12.04 LTS
- User: ubuntu
- DNS: HOSTANME.cloudapp.net

./provision-node.sh HOSTNAME.cloudapp.net


Securing Node
==============

Adds some specific security configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

./securify-node.sh HOSTNAME.cloudapp.net

See:
- http://library.linode.com/securing-your-server


Runnning chef
=============

Run chef and full-provision with specific cookbooks the node
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

./update-node.sh HOSTNAME.cloudapp.net


Set up chef-repo (dev workstation)
==================================

git clone git://github.com/opscode/chef-repo.git

See:
- http://wiki.opscode.com/display/chef/Working+with+Git+and+Cookbooks


Coobooks
=========

See:
- http://wiki.opscode.com/display/chef/Resources

Postgresql:

- https://github.com/opscode-cookbooks/postgresql

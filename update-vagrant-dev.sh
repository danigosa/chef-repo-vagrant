#! /bin/bash

rsync -a $(dirname $0)/ /srv/chef-solo

sudo chef-solo -c /srv/chef-solo/solo.rb -j /srv/chef-solo/nodes/vagrant-dev.json

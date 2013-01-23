#! /bin/bash

set -e

node="$1"
user="ubuntu"
domain="cloudapp.net"

rsync -a $(dirname $0)/ ${user}@${node}.${domain}:/srv/chef-solo

#Provide fresh git source copy
git archive --format zip --output /tmp/infantium.zip --remote ssh://git@bitbucket.org/danigosa/infantium-repo.git master
scp /tmp/infantium.zip ${node}:/tmp

#Provide media folder
cd /home/vagrant/chef-repo
zip -r /tmp/media.zip ./media
scp /tmp/media.zip ${node}:/tmp

#Provide dumps & fixtures
scp /home/vagrant/chef-repo/database/infantiumdb_dump_chef.dump ${node}:/tmp

ssh -t ${node} \
    sudo chef-solo -c /srv/chef-solo/solo.rb -j /srv/chef-solo/nodes/${node}.json


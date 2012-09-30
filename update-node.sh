#! /bin/bash

set -e

node="$1"
user="ubuntu"

rsync -a $(dirname $0)/ ${user}@${node}:/srv/chef-solo

#Provide fresh git source copy
git archive --format zip --output /tmp/infantium.zip --remote ssh://git@bitbucket.org/danigosa/infantium-repo.git master
scp /tmp/infantium.zip ubuntu@${node}:/tmp

#Provide media folder
cd /home/vagrant/chef-repo
zip -r /tmp/media.zip ./media
scp /tmp/media.zip ubuntu@${node}:/tmp

#Provide dumps & fixtures
scp /home/vagrant/chef-repo/database/infantiumdb_dump_chef.dump ubuntu@${node}:/tmp
scp /home/vagrant/chef-repo/fixtures/all.json ubuntu@${node}:/tmp

ssh -t ${user}@${node} \
    sudo chef-solo -c /srv/chef-solo/solo.rb -j /srv/chef-solo/nodes/${node}.json


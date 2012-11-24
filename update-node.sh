#! /bin/bash

set -e

node="$2"
user="$1"

rsync -a $(dirname $0)/ ${user}@${node}:/srv/chef-solo

#Provide fresh git source copy
git archive --format zip --output /tmp/infantium.zip --remote ssh://git@bitbucket.org/danigosa/infantium-repo.git master
scp /tmp/infantium.zip ${user}@${node}:/tmp

#Provide media folder
cd /home/vagrant/chef-repo
zip -r /tmp/media.zip ./media
scp /tmp/media.zip ${user}@${node}:/tmp

#Provide dumps & fixtures
scp /home/vagrant/chef-repo/database/infantiumdb_dump_chef.dump ${user}@${node}:/tmp
scp /home/vagrant/chef-repo/fixtures/all.json ${user}@${node}:/tmp

ssh -t ${user}@${node} \
    sudo chef-solo -c /srv/chef-solo/solo.rb -j /srv/chef-solo/nodes/${node}.json


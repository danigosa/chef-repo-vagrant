#! /bin/bash

set -e

node="$1"

rsync -a $(dirname $0)/ ${node}:/srv/chef-solo

#Provide fresh git source copy
git archive --format zip --output /tmp/infantium.zip --remote git@bitbucket.org:infantiumdevteam/infantium-repo.git master
scp /tmp/infantium.zip ${node}:/tmp

#Provide media folder
cd /home/ubuntu/chef-repo
zip -r /tmp/media.zip ./media
scp /tmp/media.zip ${node}:/tmp

#Provide dumps & fixtures
scp /home/ubuntu/chef-repo/database/infantiumdb_dump_chef.dump ${node}:/tmp

ssh -t ${node} \
    sudo chef-solo -c /srv/chef-solo/solo.rb -j /srv/chef-solo/nodes/${node}.json


#! /bin/bash

set -e

node="$1"
user="ubuntu"

rsync -a $(dirname $0)/ ${user}@${node}:/srv/chef-solo

ssh -t ${user}@${node} \
    sudo chef-solo -c /srv/chef-solo/solo.rb -j /srv/chef-solo/nodes/${node}.json

#!/usr/bin/env bash

#Patch if not found keying
touch /etc/apt/trusted.gpg.d/opscode-keyring.gpg && gpg --fetch-key http://apt.opscode.com/packages@opscode.com.gpg.key && gpg --export 83EF826A | apt-key --keyring /etc/apt/trusted.gpg.d/opscode-keyring.gpg add - && gpg --yes --delete-key 83EF826A

cp /etc/apt/trusted.gpg.d/opscode-keyring.gpg /tmp

# Install chef-client
echo "deb http://apt.opscode.com/ `lsb_release -cs`-0.10 main" | tee /etc/apt/sources.list.d/opscode.list
cp /tmp/opscode-keyring.gpg /etc/apt/trusted.gpg.d/opscode-keyring.gpg
apt-get update
apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install chef opscode-keyring

# Set up remote chef-solo
install -d -o vagrant -g vagrant /srv/chef-solo

# Install Taskel
apt-get -y install tasksel

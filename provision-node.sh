#!/bin/bash

set -e
set -x

user="$1"
node="$2"

ssh-copy-id -i ~/.ssh/dani-inf-azure.pub ${user}@${node}

scp /etc/apt/trusted.gpg.d/opscode-keyring.gpg ubuntu@${node}:/tmp

ssh -t ubuntu@${node} "cat > /tmp/provision.sh" <<'EOF'
#!/bin/bash
# Allow ubuntu user to execute sudo without prompting password through The Windows Azure Linux Agent
sudo chmod 666 /etc/sudoers.d/waagent
sudo echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/waagent
sudo chmod 440 /etc/sudoers.d/waagent

# Set up repos for Nginx
wget http://nginx.org/keys/nginx_signing.key
sudo apt-key add nginx_signing.key
sudo add-apt-repository "deb http://nginx.org/packages/ubuntu/ precise nginx"
# Gives error but should be possibly uncommented in a future
#sudo add-apt-repository "deb-src http://nginx.org/packages/ubuntu/ precise nginx"

# Set up repos for Postgresql 9.2
sudo add-apt-repository ppa:pitti/postgresql

# Install chef-client
echo "deb http://apt.opscode.com/ `lsb_release -cs`-0.10 main" | sudo tee /etc/apt/sources.list.d/opscode.list
sudo cp /tmp/opscode-keyring.gpg /etc/apt/trusted.gpg.d/opscode-keyring.gpg
sudo apt-get update
sudo apt-get install chef opscode-keyring

# Set up remote chef-solo
sudo install -d -o ${user} -g ${user} /srv/chef-solo

# Install GIT
sudo apt-get git

# Upgrade System
sudo apt-get upgrade

# Might require reboot
sudo reboot
EOF

ssh -t ${user}@${node} bash /tmp/provision.sh

#!/bin/bash

set -e
set -x

node="$1"

ssh-copy-id -i ~/.ssh/dani-inf-azure.pub ${node}

scp /etc/apt/trusted.gpg.d/opscode-keyring.gpg ${node}:/tmp

ssh -t ${node} "cat > /tmp/sudoers.sh" <<'EOF'
#!/bin/bash
# Allow ubuntu user to execute sudo without prompting password through The Windows Azure Linux Agent
# MUST BE EXECUTED AS ROOT
chmod 666 /etc/sudoers.d/waagent
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/waagent
chmod 440 /etc/sudoers.d/waagent
EOF

ssh -t ${node} "cat > /tmp/provision.sh" <<'EOF'
#!/bin/bash
sudo bash /tmp/sudoers.sh

# Set up repos for Nginx
wget http://nginx.org/keys/nginx_signing.key
sudo apt-key add nginx_signing.key
sudo add-apt-repository "deb http://nginx.org/packages/ubuntu/ precise nginx"
# Gives error but should be possibly uncommented in a future
#sudo add-apt-repository "deb-src http://nginx.org/packages/ubuntu/ precise nginx"

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

ssh -t ${node} bash /tmp/provision.sh

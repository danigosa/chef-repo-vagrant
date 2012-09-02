#!/bin/bash

set -e
set -x

node="$1"

ssh-copy-id -i ~/.ssh/dani-inf-azure.pub ubuntu@${node}

scp /etc/apt/trusted.gpg.d/opscode-keyring.gpg ubuntu@${node}:/tmp

ssh -t ubuntu@${node} "cat > /tmp/provision.sh" <<'EOF'
#!/bin/bash
# Set up repos for Nginx
wget http://nginx.org/keys/nginx_signing.key
sudo apt-key add nginx_signing.key
sudo add-apt-repository "deb http://nginx.org/packages/ubuntu/ precise nginx"
sudo add-apt-repository "deb-src http://nginx.org/packages/ubuntu/ precise nginx"

# Install chef-client
echo "deb http://apt.opscode.com/ `lsb_release -cs`-0.10 main" | sudo tee /etc/apt/sources.list.d/opscode.list
sudo cp /tmp/opscode-keyring.gpg /etc/apt/trusted.gpg.d/opscode-keyring.gpg
sudo apt-get update
sudo apt-get install chef opscode-keyring

# Set up remote chef-solo
sudo install -d -o ubuntu -g ubuntu /srv/chef-solo

sudo apt-get upgrade
EOF

ssh -t ubuntu@${node} bash /tmp/provision.sh

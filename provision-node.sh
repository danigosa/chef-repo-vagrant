#!/bin/bash

set -e
set -x

user="ubuntu"
node="$1"

ssh-copy-id -i ~/.ssh/dani-inf-azure.pub ${node}

#Patch if not found keying
#sudo touch /etc/apt/trusted.gpg.d/opscode-keyring.gpg && sudo gpg --fetch-key http://apt.opscode.com/packages@opscode.com.gpg.key && sudo gpg --export 83EF826A | sudo apt-key --keyring /etc/apt/trusted.gpg.d/opscode-keyring.gpg add - && sudo gpg --yes --delete-key 83EF826A

scp /etc/apt/trusted.gpg.d/opscode-keyring.gpg ${node}:/tmp

ssh -t ${node} "cat > /tmp/sudoers.sh" <<'EOF'
#!/bin/bash
# Allow ubuntu user to execute sudo without prompting password through The Windows Azure Linux Agent
# MUST BE EXECUTED AS ROOT
chmod 666 /etc/sudoers.d/waagent
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/waagent
chmod 440 /etc/sudoers.d/waagent
EOF

ssh -t ${node} "cat > /tmp/fary_setup_db.js" <<'EOF'
//init with $mongo localhost:27017/test fary_init.js
db = new Mongo().getDB('mairena_db');
things={'init': true};
db.things.insert(things);
//Add user auth
if(!db.auth('infantiumongo','1234')){
   db.addUser('infantiumongo','1234');
}

quit();
EOF

ssh -t ${node} "cat > /tmp/mairena_setup_db.js" <<'EOF'
//init with $mongo localhost:27017/test fary_init.js
db = new Mongo().getDB('fary_db');
things={'init': true};
db.things.insert(things);
//Add user auth
if(!db.auth('infantiumongo','1234')){
   db.addUser('infantiumongo','1234');
}

quit();
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
sudo install -d -o ubuntu -g ubuntu /srv/chef-solo

# Install GIT
sudo apt-get git

# Install Taskel
sudo apt-get install tasksel

# Upgrade System
sudo apt-get upgrade

# Might require reboot
sudo reboot
EOF

ssh -t ${node} bash /tmp/provision.sh

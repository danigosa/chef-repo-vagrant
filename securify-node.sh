#!/bin/bash

set -e
set -x

user="ubuntu"
node="$1"

#Configure IPTables Firewall
ssh -t ${node} "cat > /tmp/iptables.firewall.rules" <<'EOF'
*filter

#  Allow all loopback (lo0) traffic and drop all traffic to 127/8 that doesn't use lo0
-A INPUT -i lo -j ACCEPT
-A INPUT -d 127.0.0.0/8 -j REJECT

#  Accept all established inbound connections
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

#  Allow all outbound traffic - you can modify this to only allow certain traffic
-A OUTPUT -j ACCEPT

#  Allow HTTP and HTTPS connections from anywhere (the normal ports for websites and SSL).
-A INPUT -p tcp --dport 80 -j ACCEPT
-A INPUT -p tcp --dport 443 -j ACCEPT
#  Allow PGPOOL connections from anywhere
-A INPUT -p tcp --dport 5433 -j ACCEPT
#  Allow MONGODB connections from anywhere
-A INPUT -p tcp --dport 27017 -j ACCEPT


#  Allow SSH connections
#
#  The -dport number should be the same port number you set in sshd_config
#
-A INPUT -p tcp -m state --state NEW --dport 22 -j ACCEPT

#  Allow ping
-A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT

#  Log iptables denied calls
-A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7

#  Reject all other inbound - default deny unless explicitly allowed policy
-A INPUT -j REJECT
-A FORWARD -j REJECT

COMMIT
EOF

# Activate rules
ssh -t ${node} sudo cp /tmp/iptables.firewall.rules /etc/
ssh -t ${node} "sudo iptables-restore < /etc/iptables.firewall.rules"
ssh -t ${node} "cat > /tmp/firewall" <<'EOF'
#!/bin/sh
/sbin/iptables-restore < /etc/iptables.firewall.rules
EOF
# Activate each restart
ssh -t ${node} sudo cp /tmp/firewall /etc/network/if-pre-up.d/
ssh -t ${node} sudo chmod +x /etc/network/if-pre-up.d/firewall

# Install fail2ban SSH monitoring
ssh -t ${node} sudo apt-get install fail2ban



##########################################################
# NODE VARIABLES: Tunning it from here
##########################################################
# Domain DNS
node[:inf_version] = "mongodev"
node[:inf_domain] = "infantium.com"
# SHMMAX
node[:inf_shmmax] = 17179869184
node[:inf_shmmall] = 4194304

##########################################################
# START PROVISIONING
##########################################################
package "chef"

service "chef-client" do
  action [:stop, :disable]
end

##########################################################
# INSTALL MONGODB: And automated database backup
##########################################################
template "/etc/apt/sources.list.d/10gen.list" do
  owner "root"
  group "root"
  mode "0600"
end

# Set APT for MONGO
script "set_APT_mongo" do
  user "root"
  interpreter "bash"
  code <<-EOH
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10
  sudo apt-get update
  EOH
end

# Set enough SHM for linux limits
script "set_SHMMAX_kernel" do
  user "root"
  interpreter "bash"
  code <<-EOH
  sudo sysctl -w kernel.shmmax=17179869184
  sudo sysctl -w kernel.shmall=4194304
  sudo sysctl -p /etc/sysctl.conf
  EOH
end

package "mongodb-10gen"

service "mongodb" do
  supports :restart => true, :status => true, :reload => false
  start_command "sudo service mongodb start"
  stop_command "sudo service mongodb stop"
  restart_command "sudo service mongodb restart"
  status_command "sudo service mongodb status"
end

# Set mongodb conf file
template "/etc/mongodb.conf" do
  owner "root"
  group "root"
  mode "0755"
  notifies :restart, "service[mongodb]", :immediately
end

# Set enough SHM for postgresqld
template "/etc/rc.local" do
  owner "root"
  group "root"
  mode "0755"
end



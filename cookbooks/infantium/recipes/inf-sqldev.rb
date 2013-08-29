##########################################################
# NODE VARIABLES: Tunning it from here
##########################################################
# Domain DNS
node[:inf_version] = "sql"
node[:inf_domain] = "infantium.com"
# Postgresql
node[:inf_postgre_password] = "postgres"
node[:inf_postgre_hostname] = node[:inf_version] + "." + node[:inf_domain]
node[:inf_postgre_max_cons] = 200
node[:inf_postgre_shared_buff] = 1024
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
# INSTALL POSTGRESQL: And automated database backup
##########################################################
package "postgresql"
package "postgresql-contrib"

service "postgresql" do
  supports :restart => true, :status => true, :reload => false
  start_command "sudo service postgresql start"
  stop_command "sudo service postgresql stop"
  restart_command "sudo service postgresql restart"
  status_command "sudo service postgresql status"
end

template "/etc/postgresql/9.1/main/postgresql.conf" do
  owner "postgres"
  group "postgres"
  mode "0600"
end

template "/etc/postgresql/9.1/main/pg_hba.conf" do
  owner "postgres"
  group "postgres"
  mode "0600"
end

# Set enough SHM for postgresqld
script "set_SHMMAX_kernel" do
  user "root"
  interpreter "bash"
  code <<-EOH
  sudo sysctl -w kernel.shmmax=17179869184
  sudo sysctl -w kernel.shmall=4194304
  sudo sysctl -p /etc/sysctl.conf
  EOH
  notifies :restart, "service[postgresql]", :immediately
end

# Set enough SHM for postgresqld
template "/etc/rc.local" do
  owner "root"
  group "root"
  mode "0755"
end

# From https://github.com/opscode-cookbooks/postgresql/blob/master/recipes/server.rb
#
# Default PostgreSQL install has 'ident' checking on unix user 'postgres'
# and 'md5' password checking with connections from 'localhost'. This script
# runs as user 'postgres', so we can execute the 'role' and 'database' resources
# as 'root' later on, passing the below credentials in the PG client.
##########################################################
# Postgresql start up
# WARN: It refreshes DB with clean backup every time! make sure you have the correct db dump in chef-repo/database
##########################################################
script "setup-postgresql" do
  user "postgres"
  interpreter "bash"
  code <<-EOH
  echo "ALTER ROLE postgres PASSWORD 'postgres';" | psql
  dropdb infantiumdb
  createdb -E UTF8 infantiumdb
  psql infantiumdb < /tmp/infantiumdb_dump_chef.dump
  EOH
  action :run
end

##########################################################
# PGPOOL2 SETUP
##########################################################
package "pgpool2"

service "pgpool2" do
  supports :restart => true, :reload => true
  action :enable
end

template "/etc/pgpool2/pgpool.conf" do
  mode "0644"
  owner "root"
  group "root"
end

template "/etc/pgpool2/pool_hba.conf" do
  mode "0644"
  owner "root"
  group "root"
  notifies :restart, "service[pgpool2]", :immediately
  notifies :restart, "service[postgresql]", :immediately
end

##########################################################
# Automated backuping
##########################################################
script "pg_backup_infantiumdb-setup" do
  user "root"
  interpreter "bash"
  code <<-EOH
  sudo mkdir -p /var/backups/database/postgresql/pg_backup_infantiumdb
  EOH
end

template "/etc/cron.daily/pg_backup.sh" do
  mode "0755"
  owner "root"
  group "root"
end

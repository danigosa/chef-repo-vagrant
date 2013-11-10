##########################################################
# NODE VARIABLES: Tunning it from here
##########################################################
# Postgresql
node[:inf_postgre_password] = "postgres"
node[:inf_postgre_hostname] = node[:inf_version] + "." + node[:inf_domain]
node[:inf_postgre_max_cons] = 10
node[:inf_postgre_shared_buff] = 32
# SHMMAX
node[:inf_shmmax] = 17179869184
node[:inf_shmmall] = 4194304

##########################################################
# START PROVISIONING
##########################################################
package "chef"
package "git"

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

# Set enough SHM for postgresqld
script "set_SHMMAX_kernel" do
  user "root"
  interpreter "bash"
  code <<-EOH
  sudo sysctl -w kernel.shmmax=17179869184
  sudo sysctl -w kernel.shmall=4194304
  sudo sysctl -p /etc/sysctl.conf
  EOH
end

# Set enough SHM for postgresqld
template "/etc/rc.local" do
  owner "root"
  group "root"
  mode "0755"
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

##########################################################
# Postgresql start up
# WARN: It refreshes DB with clean backup every time! make sure you have the correct db dump in chef-repo/database
##########################################################

execute "Psql template1 to UTF8" do
    user "postgres"
    command <<-EOF
    echo "UPDATE pg_database SET datistemplate = FALSE WHERE datname = 'template1';
    DROP DATABASE template1;
    CREATE DATABASE template1 WITH TEMPLATE = template0 ENCODING = 'UNICODE' LC_CTYPE='en_US.utf8' LC_COLLATE='en_US.utf8';
    UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template1';
    \\c template1
    VACUUM FREEZE;" | psql postgres -t
    EOF
    only_if '[ $(echo "select count(*) from pg_database where datname = \'template1\' and datcollate = \'en_US.utf8\'" |psql postgres -t) -eq 0 ]'
end

script "setup-postgresql" do
  user "postgres"
  interpreter "bash"
  code <<-EOH
  echo "ALTER ROLE postgres PASSWORD 'postgres';" | psql
  #dropdb infantiumdb
  createdb -E UTF8 infantiumdb
  psql infantiumdb < /vagrant/database/infantiumdb_dump_latest.dump
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
# INSTALL MEMCACHED
##########################################################
package "memcached"

service "memcached" do
  supports :restart => true, :reload => true
  action :enable
end

# Set init params
template "/etc/memcached.conf" do
  owner "root"
  group "root"
  mode "0664"
end




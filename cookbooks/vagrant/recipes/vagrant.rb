##########################################################
# NODE VARIABLES: Tunning it from here
##########################################################
# Domain DNS
node[:inf_version] = "sql"
node[:inf_domain] = "infantium.com"
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

script "install_mairena_db" do
  user "root"
  interpreter "bash"
  code <<-EOH
  mongo localhost:27017/test /vagrant/database/mairena_setup_db_test.js
  EOH
end

script "install_fary_db" do
  user "root"
  interpreter "bash"
  code <<-EOH
  mongo localhost:27017/test /vagrant/database/fary_setup_db_test.js
  EOH
end

script "install_pozi_db" do
  user "root"
  interpreter "bash"
  code <<-EOH
  mongo localhost:27017/test /vagrant/database/pozi_setup_db_test.js
  EOH
end

##########################################################
# INSTALL NODEJS AND NPM FOR YUGLIFY
##########################################################
package "nodejs"
package "npm"

script "install_yuglify" do
  user "root"
  interpreter "bash"
  code <<-EOH
  sudo npm -g install yuglify
  EOH
end

##########################################################
# INSTALL DJANGO: Previous OS stuff
##########################################################
package "build-essential"
package "g++"
package "python-dev"
package "python2.7-dev"
package "libpq-dev"
package "python-lxml"
package "libxml2-dev"
package "libxslt-dev"
package "gettext"
package "libjpeg-dev"
package "libfreetype6-dev"
package "zlib1g-dev"
package "libpng12-dev"
package "unixodbc-dev"
package "unixodbc-bin"
package "libssl-dev"
package "libssl1.0.0"
package "libssl1.0.0-dbg"

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

##########################################################
# INSTALL RABBITMQ-SERVER: And creates user and vhost
##########################################################
package "rabbitmq-server"

service "rabbitmq-server" do
  supports :restart => true, :reload => true
  action :enable
end

script "install_rabittmq-server" do
  user "root"
  interpreter "bash"
  code <<-EOH
  sudo rabbitmqctl add_user nachovidal inf-nacho_4321
  sudo rabbitmqctl add_vhost infantiumvhost
  sudo rabbitmqctl set_permissions -p infantiumvhost nachovidal ".*" ".*" ".*"
  EOH
  notifies :restart, "service[rabbitmq-server]"
end




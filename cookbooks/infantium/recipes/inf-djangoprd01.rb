##########################################################
# NODE VARIABLES: Tunning it from here
##########################################################
# Domain DNS
node[:inf_version] = "beta"
node[:inf_domain] = "infantium.com"
# Postgresql
node[:inf_postgre_password] = "postgres"
node[:inf_postgre_hostname] = node[:inf_version] + "." + node[:inf_domain]
node[:inf_postgre_max_cons] = 100
node[:inf_postgre_shared_buff] = 16
# Memcached
node[:inf_memcached_mem] = 512
node[:inf_memcached_cons] = 2048
# uWSGI
node[:inf_uwsgi_workers] = 4

##########################################################
# START PROVISIONING
##########################################################
package "chef"

service "chef-client" do
  action [:stop, :disable]
end

##########################################################
# INSTALL NGINX
##########################################################
package "nginx"

template "/etc/nginx/conf.d/default.conf" do
  mode "0600"
  owner "root"
  group "root"
end

##########################################################
# SSL files for Nginx
##########################################################
script "setup_nginx_ssl_conf" do
  user "root"
  interpreter "bash"
  code <<-EOH
  mkdir -p /usr/local/nginx/conf
  EOH
end

cookbook_file '/usr/local/nginx/conf/sslchain.crt' do
  owner 'root'
  group 'root'
  mode 0600
end

cookbook_file '/usr/local/nginx/conf/infantium.com.key' do
  owner 'root'
  group 'root'
  mode 0600
end

##########################################################
# INSTALL UWGSI
##########################################################
package "uwsgi"
package "uwsgi-plugin-python"

template "/etc/init/uwsgi.conf" do
  mode "0600"
  owner "root"
  group "root"
end

execute "uwgsi_useradd" do
  command "useradd -c 'uwsgi user' -g nginx --system uwsgi && touch /home/ubuntu/uwsgi_user_created.donothing"
  creates "/home/ubuntu/uwsgi_user_created.donothing"
  action :run
end

##########################################################
# START SERVICES
##########################################################
service "uwsgi" do
  supports :status => true, :restart => true, :reload => false
  action [:start]
  start_command "sudo service uwsgi start"
  stop_command "sudo service uwsgi stop"
  restart_command "sudo service uwsgi restart"
  status_command "sudo service uwsgi status"
end

service "nginx" do
  supports :status => true, :restart => true, :reload => false
  action [:start]
  start_command "sudo service nginx start"
  stop_command "sudo service nginx stop"
  restart_command "sudo service nginx restart"
  status_command "sudo service nginx status"
end

##########################################################
# INSTALL MEMCACHED
##########################################################
package "memcached"

service "memcached" do
  supports :restart => true, :reload => true
  action :enable
end

##########################################################
# INSTALL VIRTUALENV: And creates the app env
##########################################################
package "python-pip"
package "python-setuptools"

script "install_virtualenv" do
  user "root"
  interpreter "bash"
  code <<-EOH
  mkdir -p /var/www/infantium_portal
  cd /var/www/infantium_portal
  sudo pip install virtualenv
# rm -rf env
  virtualenv env
  EOH
end

###################### BEGIN COMMENT #####################
=begin
##########################################################
GETTING SOURCE IN UPDATE-NODE.SH TO ALLOW SSH LOGIN TO BITBUCKET
INSTALLING GIT IN PROVISION-NODE.SH

package "git"

script "pull_source" do
  ##########################################################
  # TODO: Pull source with ssh auth without promtping passwd
  ##########################################################
  user "root"
  cwd "/var/www"
  interpreter "bash"
  code <<-EOH
  cd /var/www/infantium_portal
  rm -rf infantium
  git clone https://danigosa@bitbucket.org/gloriamh/infantium.git
  rm -rf ./infantium/.git ./infantium/.gitignore
  EOH
end
###################### END COMMENT #######################
=end
##########################################################

##########################################################
# PULL SOURCE: Pull source from /tmp
##########################################################

package "unzip"

script "pull_source" do
  user "root"
  cwd "/var/www"
  interpreter "bash"
  code <<-EOH
  cd /var/www/infantium_portal
  cp -rf infantium /tmp/
  rm -rf infantium
  unzip /tmp/infantium.zip -d /var/www/infantium_portal/infantium
  mv /var/www/infantium_portal/infantium/infantium/settings.py /var/www/infantium_portal/infantium/infantium/settings.dev.py
  mv /var/www/infantium_portal/infantium/infantium/settings.prod.py /var/www/infantium_portal/infantium/infantium/settings.py
  EOH
end


##########################################################
# INSTALL DJANGO: And requirements
##########################################################
package "python-dev"
package "libpq-dev"
package "python-lxml"
package "libxml2-dev"
package "libxslt-dev"
package "gettext"

script "install_django" do
  user "root"
  cwd "/var/www"
  interpreter "bash"
  code <<-EOH
  sudo apt-get install libjpeg libjpeg-dev libfreetype6 libfreetype6-dev zlib1g-dev
  source /var/www/infantium_portal/env/bin/activate
  pip install -r /var/www/infantium_portal/infantium/requirements.txt
  deactivate
  EOH
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
  cwd "/var/www"
  interpreter "bash"
  code <<-EOH
  sudo sysctl -w kernel.shmmax=17179869184
  sudo sysctl -w kernel.shmall=4194304
  sudo sysctl -p /etc/sysctl.conf
  EOH
  notifies :restart, "service[postgresql]", :immediately
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
#script "setup-postgresql" do
  #user "postgres"
  #cwd "/var/www"
  #interpreter "bash"
  #code <<-EOH
  #echo "ALTER ROLE postgres PASSWORD 'postgres';" | psql
  #dropdb infantiumdb
  #createdb -E UTF8 infantiumdb
  #psql infantiumdb < /tmp/infantiumdb_dump_chef.dump
  #EOH
  #action :run
#end

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
# DJANGO SETUP: Set static files
# Monkey Patch: Restart Postgresql manually to avoid migrations fail miserably in random situations (alive connections)
##########################################################
script "django-app-setup" do
  user "root"
  cwd "/var/www"
  interpreter "bash"
  code <<-EOH
  sudo -s
  unzip /tmp/media.zip -d /var/www/infantium_portal/infantium/media
  source /var/www/infantium_portal/env/bin/activate
  cd /var/www/infantium_portal/infantium
  python ./manage.py collectstatic --noinput
  service postgresql restart
  python ./manage.py migrate --all
  python ./manage.py syncdb --noinput
  python ./manage.py update_translation_fields
  deactivate
  EOH
  notifies :restart, "service[uwsgi]"
  notifies :restart, "service[nginx]"
  notifies :restart, "service[pgpool2]", :immediately
  notifies :restart, "service[postgresql]", :immediately
  notifies :restart, "service[memcached]", :immediately
end

##########################################################
# Clean Up
##########################################################
script "django-app-cleanup" do
  user "root"
  cwd "/var/www/infantium_portal"
  interpreter "bash"
  code <<-EOH
  sudo rm -rf media infantium/media
  sudo truncate -s 0 infantium/logs/*.log
  EOH
end

##########################################################
# Restore permissions
##########################################################
script "django-app-permissions" do
  user "root"
  cwd "/var/www"
  interpreter "bash"
  code <<-EOH
  sudo usermod -a -G nginx $USER
  sudo chown -R $USER:nginx /var/www/infantium_portal
  sudo chmod -R g+w /var/www/infantium_portal
  EOH
end

##########################################################
# Automated backuping
##########################################################
script "pg_backup_infantiumdb-setup" do
  user "root"
  cwd "/var/www"
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
# Setup SFTP
##########################################################
package "vsftpd"

template "/etc/vsftpd.conf" do
  mode "0600"
  owner "root"
  group "root"
end

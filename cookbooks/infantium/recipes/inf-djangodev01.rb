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
  action :create_if_missing
  notifies :reload, "service[ssh]"
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
  action :create_if_missing
  notifies :reload, "service[ssh]"
end

template "/etc/uwsgi/apps-enabled/infantium.ini" do
  mode "0600"
  owner "root"
  group "root"
  action :create_if_missing
  notifies :reload, "service[ssh]"
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
  action [:enable, :start]
  start_command "sudo service uwsgi start"
  stop_command "sudo service uwsgi stop"
  restart_command "sudo service uwsgi restart"
  status_command "sudo service uwsgi status"
end

service "nginx" do
  supports :status => true, :restart => true, :reload => false
  action [:enable, :start]
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
  supports :restart => true, :reload => false
  action :enable
end

##########################################################
# INSTALL VIRTUALENV: And creates the app env
##########################################################
package "python-pip"
package "python-setuptools"

script "install_virtualenv" do
  user "ubuntu"
  cwd "/home/ubuntu"
  interpreter "bash"
  code <<-EOH
  mkdir -p /home/ubuntu/infantium_portal
  cd /home/ubuntu/infantium_portal
  sudo pip install virtualenv
  rm -rf env
  virtualenv env
  EOH
end

##########################################################
# Restore permissions
##########################################################
script "usermod_nginx_user" do
  user "ubuntu"
  cwd "/home/ubuntu"
  interpreter "bash"
  code <<-EOH
  sudo usermod -a -G nginx $USER
  sudo chown -R $USER:nginx /home/ubuntu/infantium_portal
  sudo chmod -R g+w /home/ubuntu/infantium_portal
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
  user "ubuntu"
  cwd "/home/ubuntu"
  interpreter "bash"
  code <<-EOH
  cd /home/ubuntu/infantium_portal
  rm -rf infantium
  git clone https://danigosa@bitbucket.org/gloriamh/infantium.git
  rm -rf ./infantium/.git ./infantium/.gitignore
  sudo chown -R $USER:nginx /home/ubuntu/infantium_portal
  sudo chmod -R g+w /home/ubuntu/infantium_portal
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
  user "ubuntu"
  cwd "/home/ubuntu"
  interpreter "bash"
  code <<-EOH
  cd /home/ubuntu/infantium_portal
  rm -rf infantium
  unzip /tmp/infantium.zip -d /home/ubuntu/infantium_portal/infantium
  sudo chown -R $USER:nginx /home/ubuntu/infantium_portal
  sudo chmod -R g+w /home/ubuntu/infantium_portal
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
  user "ubuntu"
  cwd "/home/ubuntu"
  interpreter "bash"
  code <<-EOH
  source /home/ubuntu/infantium_portal/env/bin/activate
  pip install -r /home/ubuntu/infantium_portal/infantium/requirements.txt
  deactivate
  EOH
end

##########################################################
# INSTALL POSTGRESQL: And automated database backup
##########################################################
package "postgresql"
package "postgresql-contrib"

service "postgresql" do
  supports :restart => true, :status => true, :reload => true
  action :nothing
end

template "/etc/postgresql/9.1/main/postgresql.conf" do
  owner "postgres"
  group "postgres"
  mode "0600"
  notifies :restart, resources(:service => "postgresql"), :immediately
end

template "/etc/postgresql/9.1/main/pg_hba.conf" do
  owner "postgres"
  group "postgres"
  mode "0600"
  notifies :restart, resources(:service => "postgresql"), :immediately
end

# From https://github.com/opscode-cookbooks/postgresql/blob/master/recipes/server.rb
#
# Default PostgreSQL install has 'ident' checking on unix user 'postgres'
# and 'md5' password checking with connections from 'localhost'. This script
# runs as user 'postgres', so we can execute the 'role' and 'database' resources
# as 'root' later on, passing the below credentials in the PG client.
##########################################################
# TODO: Pass password as json or attribute not hardcoded
# TODO: Hostname as json or attribute not harcoded
# TODO: SQL dump from GIT repository
# TODO: Restore will fail if not -c (dropping former objects) option enabled
##########################################################
script "assign-postgres-password" do
  user "postgres"
  cwd "/home/ubuntu"
  interpreter "bash"
  code <<-EOH
  echo "ALTER ROLE postgres PASSWORD 'postgres';" | psql
  dropdb infantiumdb
  createdb -E UTF8 -O postgres -h inf-djangodev01.cloudapp.net
  psql < /tmp/infantiumdb_dump_chef.dump
  EOH
  not_if "echo '\connect' | PGPASSWORD=postgres psql --username=postgres --no-password -h localhost"
  action :run
end

##########################################################
# Automated backuping
##########################################################
script "setup_backup_conf" do
  user "root"
  interpreter "bash"
  code <<-EOH
  mkdir -p /var/backups/database/postgresql/infantiumdb
  EOH
end

template "/var/backups/database/postgresql/infantiumdb/pg_backup.config" do
  mode "0400"
  owner "root"
  group "root"
  action :create_if_missing
  notifies :reload, "service[ssh]"
end

template "/var/backups/database/postgresql/infantiumdb/pg_backup_rotated.sh" do
  mode "0500"
  owner "root"
  group "root"
  action :create_if_missing
  notifies :reload, "service[ssh]"
end

template "/var/backups/database/postgresql/infantiumdb/pg_backup.sh" do
  mode "0500"
  owner "root"
  group "root"
  action :create_if_missing
  notifies :reload, "service[ssh]"
end

template "/etc/cron.d/updatedb" do
  mode "0500"
  owner "root"
  group "root"
  action :create_if_missing
  notifies :reload, "service[ssh]"
end

##########################################################
# DJANGO SETUP
##########################################################
script "django-app-setup" do
  user "ubuntu"
  cwd "/home/ubuntu"
  interpreter "bash"
  code <<-EOH
  source /home/ubuntu/infantium_portal/env/bin/activate
  cd /home/ubuntu/infantium_portal/infantium
  python ./manage.py collectstatic --noinput
  python ./manage.py syncdb --all
  python ./manage.py migrate --fake
  python ./manage.py migrate
  deactivate
  EOH
end

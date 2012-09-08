package "chef"

service "chef-client" do
  action [:stop, :disable]
end

package "nginx"

service "nginx" do
  supports :status => true, :restart => true, :reload => true
  action [:enable, :start]
end

package "uwsgi"
package "uwsgi-plugin-python"

template "/etc/init/uwsgi.conf" do
  mode "0600"
  owner "root"
  group "root"
  notifies :reload, "service[ssh]"
end

service "uwsgi" do
  supports :status => true, :restart => true, :reload => true
  action [:enable, :start]
end

execute "uwgsi_useradd" do
  command "useradd -c 'uwsgi user' -g nginx --system uwsgi && touch /home/ubuntu/uwsgi_user_created.donothing"
  creates "/home/ubuntu/uwsgi_user_created.donothing"
  action :run
end

package "memcached"

service "memcached" do
  supports :restart => true, :reload => false
  action :enable
end

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

script "setup_nginx_conf" do
  user "ubuntu"
  cwd "/home/ubuntu"
  interpreter "bash"
  code <<-EOH
  cd /etc/nginx/conf.d
  sudo mv default.conf default.conf.bak
  sudo touch infantium_portal.conf
  EOH
end

template "/etc/nginx/conf.d/infantium_portal.conf" do
  mode "0600"
  owner "root"
  group "root"
  notifies :reload, "service[uwsgi]"
  notifies :reload, "service[nginx]"
end

package "git"

script "pull_source" do
  user "ubuntu"
  cwd "/home/ubuntu"
  interpreter "bash"
  code <<-EOH
  cd /home/ubuntu/infantium_portal
  rm -rf infantium
  git clone https://danigosa@bitbucket.org/gloriamh/infantium.git
  rm -rf .git .gitignore
  sudo chown -R $USER:nginx /home/ubuntu/infantium_portal
  sudo chmod -R g+w /home/ubuntu/infantium_portal
  EOH
end

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
# TODO: SQL dump from GIT repository
# TODO: Restore will fail if not -c (dropping former objects) option enabled
##########################################################
script "assign-postgres-password" do
  user "postgres"
  cwd "/home/ubuntu"
  interpreter "bash"
  code <<-EOH
  echo "ALTER ROLE postgres ENCRYPTED PASSWORD '$1$efcBp33w$Q.trqE9UT3Y8E50BBabcF.';" | psql
  pg_restore -c /tmp/infantiumdb_dump_chef.sql
  EOH
  not_if "echo '\connect' | PGPASSWORD=$1$efcBp33w$Q.trqE9UT3Y8E50BBabcF. psql --username=postgres --no-password -h localhost"
  action :run
end

script "django-app-setup" do
  user "ubuntu"
  cwd "/home/ubuntu"
  interpreter "bash"
  code <<-EOH
  source /home/ubuntu/infantium_portal/env/bin/activate
  cd /home/ubuntu/infantium_portal/infantium
  python ./manage.py collectstatic
  python ./manage.py syncdb --all
  python ./manage.py migrate --fake
  python ./manage.py migrate
  deactivate
  EOH
  notifies :reload, "service[uwsgi]"
  notifies :reload, "service[nginx]"
end
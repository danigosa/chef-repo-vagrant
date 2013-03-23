##########################################################
# NODE VARIABLES: Tunning it from here
##########################################################
# Domain DNS
node[:inf_version] = "alpha"
node[:inf_domain] = "infantium.com"
# SHMMAX
node[:inf_postgre_max_cons] = 100
node[:inf_shmmax] = 17179869184
node[:inf_shmmall] = 4194304
# Memcached
node[:inf_memcached_mem] = 512
node[:inf_memcached_cons] = 2048
# uWSGI
node[:inf_uwsgi_workers] = 4
# Settings
node[:settings] = "settings.dev.py"

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
  rm -rf /var/www/infantium_portal/infantium
  unzip -o /tmp/infantium.zip -d /var/www/infantium_portal/infantium
  mv /var/www/infantium_portal/infantium/infantium/settings.py /var/www/infantium_portal/infantium/infantium/settings.back.py
  mv /var/www/infantium_portal/infantium/infantium/#{node[:settings]} /var/www/infantium_portal/infantium/infantium/settings.py
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
package "libjpeg"
package "libjpeg-dev"
package "libfreetype6"
package "libfreetype6-dev"
package "zlib1g-dev"
package "libpng12-dev"


script "install_django" do
  user "root"
  cwd "/var/www"
  interpreter "bash"
  code <<-EOH
  source /var/www/infantium_portal/env/bin/activate
  pip install -r /var/www/infantium_portal/infantium/requirements.txt
  deactivate
  EOH
end

##########################################################
# DJANGO SETUP: Set static files
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
  mkdir logs
  touch logs/django.log
  touch logs/django_request.log
  python ./manage.py collectstatic --noinput
  python ./manage.py migrate --all --delete-ghost-migrations
  python ./manage.py syncdb --noinput
  python ./manage.py update_translation_fields
  deactivate
  EOH
  notifies :restart, "service[uwsgi]"
  notifies :restart, "service[nginx]"
  notifies :restart, "service[memcached]", :immediately
end

##########################################################
# Start Up Scripts
##########################################################
# Set init params
template "/etc/rc.local" do
  owner "root"
  group "root"
  mode "0755"
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
# Setup SFTP
##########################################################
package "vsftpd"

template "/etc/vsftpd.conf" do
  mode "0600"
  owner "root"
  group "root"
end

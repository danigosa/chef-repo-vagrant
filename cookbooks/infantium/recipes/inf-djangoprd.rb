##########################################################
# NODE VARIABLES: Tunning it from here
##########################################################
# Domain DNS
node[:inf_version] = "www"
node[:inf_domain] = "infantium.com"
# SHMMAX
node[:inf_postgre_max_cons] = 100
node[:inf_shmmax] = 17179869184
node[:inf_shmmall] = 4194304
# Memcached
node[:inf_memcached_mem] = 2048
node[:inf_memcached_cons] = 4048
# uWSGI
node[:inf_uwsgi_workers] = 8
# Settings
node[:settings] = "settings.prd.py"

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
  EOH
end

execute "create_virtualenv" do
  user "root"
  cwd "/var/www/infantium_portal"
  command "virtualenv env"
  creates "/home/ubuntu/virtualenv_created.donothing"
  action :run
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
  mkdir -p /tmp/locales
  cp -rf infantium /tmp/
  cp -rf infantium/locale /tmp/locales/locale$(date +%m%d%y%h%s)
  rm -rf /var/www/infantium_portal/infantium
  unzip -o /tmp/infantium.zip -d /var/www/infantium_portal/infantium
  cd infantium
  mkdir -p whoosh_index
  mv /var/www/infantium_portal/infantium/infantium/settings_local.py /var/www/infantium_portal/infantium/infantium/settings.back.py
  mv /var/www/infantium_portal/infantium/infantium/#{node[:settings]} /var/www/infantium_portal/infantium/infantium/settings_local.py
  EOH
end

##########################################################
# INSTALL DJANGO: Previous OS stuff
##########################################################
package "build-essential"
package "g++"
package "python-dev"
package "python2.7-dev"
#package "cc"
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
package "git"

##########################################################
# DJANGO SETUP: Set static files
##########################################################
=begin
script "install_SQLServerDriver" do
  user "root"
  cwd "/var/www"
  interpreter "bash"
  code <<-EOH
  cd /tmp/
  wget ftp://ftp.unixodbc.org/pub/unixODBC/unixODBC-2.3.0.tar.gz
  tar xvf unixODBC-2.3.0.tar.gz
  wget http://download.microsoft.com/download/6/A/B/6AB27E13-46AE-4CE9-AFFD-406367CADC1D/Linux6/sqlncli-11.0.1790.0.tar.gz
  tar xvf sqlncli-11.0.1790.0.tar.gz
  cd unixODBC-2.3.0/
  ./configure --disable-gui --disable-drivers --enable-iconv --with-iconv-char-enc=UTF8 --with-iconv-ucode-enc=UTF16LE
  sudo make install
  cd ..
  sudo ln -nfs /lib/x86_64-linux-gnu/libssl.so.1.0.0 /usr/lib/libssl.so.10
  sudo ln -nfs /lib/x86_64-linux-gnu/libcrypto.so.1.0.0 /usr/lib/libcrypto.so.10
  sudo ldconfig /usr/local/lib
  cd sqlncli-11.0.1790.0/
  sudo bash ./install.sh install --force
  EOH
end
=end

##########################################################
# DJANGO SETUP: Set requirements
##########################################################
script "install_django" do
  user "root"
  cwd "/var/www"
  interpreter "bash"
  code <<-EOH
  source /var/www/infantium_portal/env/bin/activate
  pip install -r /var/www/infantium_portal/infantium/requirements/prod.txt
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
  #unzip /tmp/media.zip -d /var/www/infantium_portal/infantium/media
  source /var/www/infantium_portal/env/bin/activate
  cd /var/www/infantium_portal/infantium
  mkdir logs
  touch logs/django.log
  touch logs/django_request.log
  python ./manage.py migrate --all --delete-ghost-migrations
  python ./manage.py syncdb --noinput
  python ./manage.py update_translation_fields
  python ./manage.py rebuild_index --noinput
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
# Setup CELERY as daemon
##########################################################
template "/etc/default/celeryd" do
  source "celeryd.default.erb"
  mode "0400"
  owner "root"
  group "root"
end

template "/etc/init.d/celeryd" do
  source "celeryd.init.d.erb"
  mode "0550"
  owner "root"
  group "root"
end

script "celery-setup" do
  user "root"
  cwd "/var/www/infantium_portal/infantium/"
  interpreter "bash"
  code <<-EOH
  sudo mkdir -p /var/log/celery/
  sudo mkdir -p /var/run/celery/
  sudo chown -R nginx:nginx /var/log/celery
  sudo chmod -R g+w /var/log/celery
  sudo chown -R nginx:nginx /var/run/celery
  sudo chmod -R g+w /var/run/celery
  sudo ln -s -f /etc/init.d/celeryd /etc/rc0.d/
  sudo ln -s -f /etc/init.d/celeryd /etc/rc1.d/
  sudo ln -s -f /etc/init.d/celeryd /etc/rc2.d/
  sudo ln -s -f /etc/init.d/celeryd /etc/rc3.d/
  sudo ln -s -f /etc/init.d/celeryd /etc/rc4.d/
  sudo ln -s -f /etc/init.d/celeryd /etc/rc5.d/
  sudo ln -s -f /etc/init.d/celeryd /etc/rc6.d/
  sudo /etc/init.d/celeryd restart
  EOH
end


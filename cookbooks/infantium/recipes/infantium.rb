package "chef"

service "chef-client" do
  action [:stop, :disable]
end

package "nginx"

service "nginx" do
  supports :status => true, :restart => true, :reload => true
  action [:enable, :start]
end

package "postgresql"

service "postgresql" do
  supports :status => true, :restart => true, :reload => true
  action [:enable, :start]
end

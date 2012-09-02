package "openssh-server"

service "ssh" do
  supports :status => true, :restart => true, :reload => true
  action [:enable, :start]
end

template "/etc/ssh/sshd_config" do
  mode "0600"
  owner "root"
  group "root"
  notifies :reload, "service[ssh]"
end

template "/home/ubuntu/.ssh/authorized_keys" do
  mode "0600"
  owner "ubuntu"
  group "ubuntu"
end
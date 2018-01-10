#
# Cookbook:: cookbook
# Recipe:: default
#
# Copyright:: 2017, The Authors, All Rights Reserved.

execute 'timedatectl' do
  command 'timedatectl set-timezone "America/New_York"'
end

package %w(yum-cron tmux bind-utils vim) do
  action :install
end

cookbook_file '/etc/yum/yum-cron-hourly.conf' do
  source 'default/yum/yum-cron-hourly.conf'
  owner 'root'
  group 'root'
  mode '0600'
  action :create
end

service 'yum-cron' do
  action [ :enable, :start ]
end

service 'firewalld' do
  action [ :enable, :start ]
end

user 'brian' do
  home '/home/brian'
  manage_home true
  shell '/bin/bash'
  action :create
end

execute 'ssh-keygen' do
  command 'ssh-keygen -t rsa -N "" -f /home/brian/.ssh/id_rsa'
  creates '/home/brian/.ssh/id_rsa'
  user 'brian'
end

cookbook_file '/home/brian/.ssh/authorized_keys' do
  source 'default/home_ssh/authorized_keys'
  owner 'brian'
  group 'brian'
  mode '0600'
  action :create
end

cookbook_file '/etc/ssh/sshd_config' do
  source 'default/etc_ssh/sshd_config'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
  notifies :restart, 'service[sshd]', :immediately
end

service 'sshd' do
  action :enable
end

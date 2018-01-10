execute 'hostnamectl' do
  command 'hostnamectl set-hostname web.mutualaid.info'
  not_if {node.name == 'web.mutualaid.info'}
end

yum_repository 'nginx' do
  baseurl 'http://nginx.org/packages/rhel/7/$basearch/'
  gpgkey 'https://nginx.org/keys/nginx_signing.key'
  gpgcheck true
  action :create
end

package %w(nginx epel-release) do
  action :install
end

package %w(python2-certbot-nginx) do
  action :install
end

execute 'firewall-cmd' do
  command 'firewall-cmd --add-rich-rule=\'rule service name="http" accept\' --permanent'
end

execute 'firewall-cmd' do
  command 'firewall-cmd --add-rich-rule=\'rule service name="https" accept\' --permanent'
end

service 'firewalld' do
  action :restart
end

execute 'certbot' do
  command 'certbot certonly --standalone -d mutualaid.info -d www.mutualaid.info --agree-tos --email brian@mutualaid.info -n'
  creates '/etc/letsencrypt/live/mutualaid.info/fullchain.pem'
end

cookbook_file '/etc/nginx/nginx.conf' do
  source 'web/nginx/nginx.conf'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
end

cookbook_file '/etc/nginx/conf.d/web.conf' do
  source 'web/nginx/conf.d/web.conf'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
end

remote_directory '/usr/share/nginx/html' do
  source 'web/html'
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

service 'nginx' do
  action [ :enable, :start ]
end

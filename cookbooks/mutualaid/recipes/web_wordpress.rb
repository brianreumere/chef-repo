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
  source 'web/nginx/conf.d/web_php.conf'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
end

package %w(mariadb-server) do
  action :install
  notifies :start, 'service[mariadb]', :immediately  
end

web_mysql_root = data_bag_item('passwords', 'web_mysql_root')
password = web_mysql_root['pw']

service 'mariadb' do
  action :nothing
  notifies :create, 'template[/root/secure.sql]', :immediately
  sensitive true
end

template '/root/secure.sql' do
  action :nothing
  source 'web/sql/secure.sql.erb'
  owner 'root'
  group 'root'
  mode '0744'
  variables :password => password
  notifies :run, 'execute[mysql_secure]', :immediately
  sensitive true
end

execute 'mysql_secure' do
  action :nothing
  command "mysql -u root < /root/secure.sql"
  sensitive true
end

execute 'remove sensitive file' do
    command 'rm -rf /root/secure.sql'
end

service 'mariadb' do
  action :enable
end

package %w(php php-mysql php-fpm php-gd) do
  action :install
end

template '/etc/php.ini' do
  action :create
  source 'web/php.ini.erb'
  owner 'root'
  group 'root'
  mode '0644'
end

template '/etc/php-fpm.d/www.conf' do
  action :create
  source 'web/www.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
end

service 'php-fpm' do
  action [ :enable, :start ]
end

service 'nginx' do
  action [ :enable, :start ]
end

remote_file '/root/wordpress-latest.tgz' do
  source 'https://wordpress.org/latest.tar.gz'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
end

execute 'extract wordpress' do
  command 'tar xzvf /root/wordpress-latest.tgz -C /usr/share/nginx/html --strip-components=1'
  creates '/usr/share/nginx/html/index.php'
end

execute 'set permissions' do
  command 'chown -R nginx:nginx /usr/share/nginx/html'
end

web_mysql_wordpress_user = data_bag_item('passwords', 'web_mysql_wordpress_user')
wordpress_password = web_mysql_wordpress_user['pw']

web_wpconfig = data_bag_item('passwords', 'web_wpconfig')
auth_key = web_wpconfig['auth_key']
secure_auth_key = web_wpconfig['secure_auth_key']
logged_in_key = web_wpconfig['logged_in_key']
nonce_key = web_wpconfig['nonce_key']
auth_salt = web_wpconfig['auth_salt']
secure_auth_salt = web_wpconfig['secure_auth_salt']
logged_in_salt = web_wpconfig['logged_in_salt']
nonce_salt = web_wpconfig['nonce_salt']

execute 'create wordpress database' do
  command "mysql -u root -p#{password} -e \"CREATE DATABASE IF NOT EXISTS wordpress_database\""
  sensitive true
end

execute 'create wordpress database user' do
  command "mysql -u root -p#{password} -e \"GRANT ALL PRIVILEGES ON wordpress_database.* TO wordpress_user@'%' IDENTIFIED BY '#{wordpress_password}'\""
  sensitive true
end

template '/usr/share/nginx/wp-config.php' do
  action :create
  source 'web/wp-config.php.erb'
  variables({
    :database_name => 'wordpress_database',
    :database_username => 'wordpress_user',
    :database_password => wordpress_password,
    :auth_key => auth_key,
    :secure_auth_key => secure_auth_key,
    :logged_in_key => logged_in_key,
    :nonce_key => nonce_key,
    :auth_salt => auth_salt,
    :secure_auth_salt => secure_auth_salt,
    :logged_in_salt => logged_in_salt,
    :nonce_salt => nonce_salt
  })
  sensitive true
end

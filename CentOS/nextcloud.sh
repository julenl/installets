#! /bin/bash
#Name Nextcloud
#Info Installs a LAMP server with Nextcloud file hosting service
#Info with optional SSL (https)
#OS   CentOS 7

################
## Variables

## Set a password for the database
mysql_root='Installets_pw'
mysql_user='Installets_pw'

## Directory where data will be stored
#data_dir_path='/var/www/html/nextcloud/data'
data_dir_path='/data'

## server_name defines the FQDN which should match the address you'll in the your web browser
## Example: server_name=nextcloud.example.com
## Example: server_name=192.168.122.100
server_name=testlamp


## Set the following 7 variables to enable SSL
## Leave the "common_name" unset (or commented) if you don't want SSL
common_name="${server_name}"
country='DE'
state='Bremen'
locality='Bremen'
organization='Your Company'
organization_unit='IT'
email='yourname@example.com'


################
## Begin Install

## Update apt
yum -y update

## Install the apache web server
yum -y install httpd

## Enable http traffic trough the firewall
firewall-cmd --permanent --zone=public --add-service=http 
firewall-cmd --reload

## Set the Server's name (FQDN) to avoid warnings
sed -i "s/#ServerName www.example.com:80/ServerName $server_name/" /etc/httpd/conf/httpd.conf


## Create a virtualhost with our $server_name
vhost_server=\
"
<VirtualHost ${server_name}:80>
   ServerName $server_name
   Redirect permanent / https://$server_name/
</VirtualHost>
"
echo "$vhost_server" > /etc/httpd/conf.d/nextcloud.conf


## Install the mysql (mariadb) database server
yum -y install mariadb-server

systemctl enable mariadb
systemctl start mariadb



## Automated MySQL secure instalation
## CentOS does not set the Password during the installation so we log in directly
mysql -u root <<-EOF
UPDATE mysql.user SET Password=PASSWORD('$mysql_root') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
FLUSH PRIVILEGES;
EOF



## If the "$common_name" variable was set, generate a self signed certificate and enable https

if ! [ -z $common_name ]; then

    yum -y install mod_ssl

    mkdir -p /etc/httpd/ssl
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
        -subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organization_unit/CN=$common_name/emailAddress=$email" \
        -keyout "/etc/httpd/ssl/${server_name}.key"  -out "/etc/httpd/ssl/${server_name}.crt"

    ## Enable SSL in apache
    #a2enmod ssl

    ## Append a default virtual host to answer to https requests
    default_append=\
"
<VirtualHost ${server_name}:443>
    ServerName ${server_name}
    DocumentRoot /var/www/html/nextcloud
    ErrorLog /var/log/httpd/error.log
    CustomLog /var/log/httpd/access.log combined

    SSLEngine On
    SSLCertificateFile    /etc/httpd/ssl/${server_name}.crt
    SSLCertificateKeyFile /etc/httpd/ssl/${server_name}.key
##  For self-signed
    SSLCACertificateFile /etc/httpd/ssl/${server_name}.crt

    <IfModule mod_headers.c>
      Header always set Strict-Transport-Security 'max-age=15552000; includeSubDomains'
    </IfModule>
</VirtualHost>
"
    echo "$default_append" >> /etc/httpd/conf.d/nextcloud.conf


    ## Reload the apache configuration
    systemctl restart httpd

    firewall-cmd --permanent --zone=public --add-service=https
    firewall-cmd --reload
fi



##
## Here comes the Nexcloud part
##

#Source https://www.rosehosting.com/blog/how-to-install-nextcloud-11-on-centos-7/


## Install and enable the EPEL7 and Remi repositories

rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
rpm -Uvh http://rpms.remirepo.net/enterprise/remi-release-7.rpm

yum -y install yum-utils
yum-config-manager --enable remi-php70


## Install php dependencies (notice! php version >7) 
yum -y install php php-mysql php-fpm php-pecl-zip php-xml php-mbstring php-gd php-ldap php-posix

## Check that we have the PHP modules loaded in apache
## It will output "php7_module (shared)"
apachectl -M |grep php

## Change the default php upload limits
sed -i "s/post_max_size = 8M/post_max_size = 100M/" /etc/php.ini
sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 1000M/" /etc/php.ini


## Install caching services to improve the performance
yum -y install memcached php-pecl-memcached php-pecl-apcu redis php-pecl-redis

systemctl enable memcached
systemctl start memcached
systemctl enable redis
systemctl start redis


## Download the Nexcloud package
## Check in https://download.nextcloud.com/server/releases/ for newer versions
cd /tmp
curl -O https://download.nextcloud.com/server/releases/nextcloud-11.0.3.zip

yum -y install unzip
unzip nextcloud-11.0.3.zip -d /var/www/html/

## Fix permissions
chown -R apache:apache /var/www/html/nextcloud/


## Test if we made some mistake in the apache configuration
apachectl configtest

## Restart the apache service to use the configuration we just made
systemctl enable httpd
systemctl restart httpd



## The Nextcloud is now installed
## Let's configure it



## Configure Nextcloud from command line (without using the web interface)
#Source https://docs.nextcloud.com/server/11/admin_manual/installation/command_line_installation.html
cd /var/www/html/nextcloud/



## Setup the database and create the admin user
sudo -u apache php occ  maintenance:install --database "mysql" --database-name "nextcloud"  \
  --database-user "root" --database-pass "${mysql_root}" --admin-user "admin" --admin-pass "${mysql_user}"

## Set the data directory to $data_dir_path
mkdir -p $data_dir_path

(
unalias cp
cp /var/www/html/nextcloud/data/.ocdata $data_dir_path
cp /var/www/html/nextcloud/data/.htaccess $data_dir_path
)

chown -R apache:apache $data_dir_path
## Adjusts permissions on the data directory
setenforce 0
chcon -R unconfined_u:object_r:default_t:s0 $data_dir_path
setenforce 1

sudo -u apache php occ config:system:set datadirectory --value=$data_dir_path


## Set trusted domains
#sudo -u apache php occ config:list
#sudo -u apache php occ config:system:get trusted_domain
sudo -u apache php occ config:system:set trusted_domains 0 --value=$server_name

## Setup caching
sudo -u apache php occ config:system:set memcache.local --value='\OC\Memcache\APCu'
#sudo -u apache php occ config:system:set memcache.distributed --value='\OC\Memcache\Memcached'
## For larger deployments
sudo -u apache php occ config:system:set memcache.locking --value='\OC\Memcache\Redis'
sudo -u apache php occ config:system:set redis host --value='127.0.0.1'
sudo -u apache php occ config:system:set redis port --value='6379'


## If the system is using $http_proxy, use it for Nextcloud too
[ -z $http_proxy ] || sudo -u apache php occ config:system:set proxy --value=$http_proxy

## Remove the /index.php from the URL to make it cleaner
sudo -u apache php occ config:system:set htaccess.RewriteBase --value='/'
sudo -u apache php occ maintenance:update:htaccess





################
## SELinux stuff

yum -y install policycoreutils-python

#Source https://docs.nextcloud.com/server/11/admin_manual/installation/selinux_configuration.html

## Allow apache to use internet (i.e. for the APP store)
setsebool -P httpd_can_network_connect on
## Allow apache to send notifications via e-mail
setsebool -P httpd_can_sendmail on

## Adjust the contexts of some directories

semanage fcontext -a -t httpd_sys_rw_content_t "$data_dir_path"
restorecon "$data_dir_path"
semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/nextcloud/config'
restorecon '/var/www/html/nextcloud/config'
semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/nextcloud/apps'
restorecon '/var/www/html/nextcloud/apps'


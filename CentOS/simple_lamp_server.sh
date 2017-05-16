#! /bin/bash
#Name Lamp Server
#Info Installs a LAMP (Linux Apache MySQL PHP) Server
#Info with optional SSL (https)
#OS CentOS 7

############
## Variables
## Set a password for the database
mysql_root='Installets_pw'

## server_name defines the FQDN which should match the address you'll in the your web browser
## Example: server_name=mylamp.example.com
## Example: server_name=192.168.122.100
server_name=testlamp


## Set the following variables to enable SSL
## Leave the "common_name" unset (or commented) if you don't want SSL
common_name="${server_name}"
country='DE'
state='Bremen'
locality='Bremen'
organization='Your Company'
organization_unit='IT'
email='yourname@example.com'


## Update apt
yum update

## Install the apache web server
yum -y install httpd

## Enable http traffic trough the firewall
firewall-cmd --permanent --zone=public --add-service=http 
firewall-cmd --reload

if ! [ -z $server_name ]; then
  sed -i "s/#ServerName www.example.com:80/ServerName $server_name/" /etc/httpd/conf/httpd.conf || \
  echo "ServerName $server_name" >> /etc/httpd/conf/httpd.conf 
fi

## For some reason these two directories are sometimes missing
## and prevent the apache from starting
mkdir -p /var/www/html /var/log/httpd

## Create an own directory for the site
mkdir -p /var/www/html/$server_name

## Create a virtualhost with our $server_name

vhost_server=\
"Listen ${server_name}:80
<VirtualHost ${server_name}:80>
    DocumentRoot '/var/www/html/${server_name}'
    ServerName $server_name

</VirtualHost>
"
echo "$vhost_server" > /etc/httpd/conf.d/${server_name}.conf


## Generate a sample website

index_html=\
'<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN"
    "http://www.w3.org/TR/html4/strict.dtd">
<html>
  <head>
    <meta http-equiv="content-type" content="text/html; charset=utf-8">
    <title>Apache is working</title>
  </head>
  <body>
    Apache is working properly.		
  </body>
</html>
'
echo "$index_html" > /var/www/html/${server_name}/index.html


## Test if we made some mistake in the apache configuration
apachectl configtest

## Restart the apache service to use the configuration we just made
systemctl enable httpd
systemctl restart httpd

## Enable apache trough the firewall
#

## Install the mysql (mariadb) database server
yum -y install mariadb-server

systemctl enable mariadb
systemctl start mariadb


## Intall php and php libraries for apache
yum -y install php php-pear php-fpm php-mysql

## phpmyadmin can be useful for interacting with the database
#yum -y install phpmyadmin

## Check that we have the PHP modules loaded in apache
## It will output "php5_module (shared)"
apachectl -M |grep php


## Automated MySQL secure instalation
## CentOS does not set the Password during the installation so we log in directly
mysql -u root <<-EOF
UPDATE mysql.user SET Password=PASSWORD('$mysql_root') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
FLUSH PRIVILEGES;
EOF



## If the "machine_name" variable was set, generate a self signed certificate and enable https

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
<VirtualHost *:443>
    ServerName ${server_name}
    DocumentRoot /var/www/html/${server_name}
    ErrorLog /var/log/httpd/error.log
    CustomLog /var/log/httpd/access.log combined

    SSLEngine On
    SSLCertificateFile    /etc/httpd/ssl/${server_name}.crt
    SSLCertificateKeyFile /etc/httpd/ssl/${server_name}.key
##  For self-signed
    SSLCACertificateFile /etc/httpd/ssl/${server_name}.crt
</VirtualHost>
"
    echo "$default_append" >> /etc/httpd/conf.d/${server_name}.conf


    ## Reload the apache configuration
    systemctl reload httpd

    firewall-cmd --permanent --zone=public --add-service=https
    firewall-cmd --reload
fi



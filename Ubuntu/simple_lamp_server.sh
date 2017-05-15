#! /bin/bash
#Name Lamp Server
#Info Installs a LAMP (Linux Apache MySQL PHP) Server
#Info with optional SSL (https)
#OS Ubuntu 16.04

############
## Variables
## Set a password for the database
mysql_root='Installets_pw'

## Set the following variables to enable SSL
## Leave the "machine_name" unset if you don't want SSL
## machine_name defines the FQDN which should match the address you'll in the your web browser
## Example: machine_name=mylamp.example.com
machine_name=
country='DE'
state='Bremen'
locality='Bremen'
organization='Your Company'
organization_unit='IT'
common_name="${machine_name}"
email='yourname@domain.com'


## Update apt
sudo apt update

## Install the apache web server
sudo apt -y install apache2

if [ -z $machine_name ];then
 echo 'ServerName lamp' >> /etc/apache2/apache2.conf 
else
 echo "ServerName $machine_name" >> /etc/apache2/apache2.conf 
fi

## Test if we made some mistake in the apache configuration
apache2ctl configtest

## Restart the apache service to use the configuration we just made
systemctl restart apache2

## Enable apache trough the firewall
#ufw allow in "Apache Full"

## Install the mysql (mariadb) database server
## Set the mysql password in debconf to avoid prompts
echo "mysql-server mysql-server/root_password select ${mysql_root}" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again select ${mysql_root}" | debconf-set-selections
apt -y install mariadb-server

## Intall php and php libraries for apache
apt -y install php libapache2-mod-php php-mcrypt php-mysql

## phpmyadmin can be useful for interacting with the database
#apt-get -y install phpmyadmin

## Check that we have the PHP modules loaded in apache
apache2ctl -M |grep php


# Automated MySQL secure instalation
mysql -u root -p${mysql_root} <<-EOF
UPDATE mysql.user SET Password=PASSWORD('$mysql_root') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
FLUSH PRIVILEGES;
EOF



## If the "machine_name" variable was set, generate a self signed certificate and enable https

if ! [ -z $machine_name ]; then

    mkdir -p /etc/apache2/ssl
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
        -subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organization_unit/CN=$common_name/emailAddress=$email" \
        -keyout "/etc/apache2/ssl/${machine_name}.key"  -out "/etc/apache2/ssl/${machine_name}.crt"

    ## Enable SSL in apache
    a2enmod ssl

    ## Append a default virtual host to answer to https requests
    default_append=\
"
<VirtualHost *:443>
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
    SSLCertificateFile    /etc/apache2/ssl/${machine_name}.crt
    SSLCertificateKeyFile /etc/apache2/ssl/${machine_name}.key
</VirtualHost>
"
    echo "$default_append" >> /etc/apache2/sites-available/000-default.conf

    ## Reload the apache configuration
    systemctl reload apache2

fi



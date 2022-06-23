#!/bin/bash
set -e
############################################################
# Help                                                     #
############################################################
Help()
{  
   # Display Help
   echo "Syntax: task02.sh [-a|h|m|p|s]"
   echo "options:"
   echo "a  ip adress defining from what adress user can have access to MySQL server (default=localhost)"
   echo "h            Print this Help."
   echo "m  ip adress optionally install Apache, PHP, PHPMyAdmin with connection to MySQL on defined IP (default=localhost)"
   echo "p  password  defines password for user. Password is created from random symbols, if not used"
   echo "r  password  defines password for root. Default password = rootpass"
   echo "s            optionally install MySQL server"
   echo "u  username  defines username for MySQL user. Default username = username"
   exit 1
}


############################################################
#Install MySQL                                             #
############################################################
installMySQL()
{
echo "Installing MySQL"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get install -y gnupg
sudo wget -c https://dev.mysql.com/get/mysql-apt-config_0.8.22-1_all.deb
sudo -E dpkg -i mysql-apt-config_0.8.22-1_all.deb
sudo apt update
sudo -E apt install -y mysql-server
sudo rm mysql-apt-config_0.8.22-1_all.deb
sudo systemctl restart mysql
echo "MySQL was installed succesfully"
}

############################################################
#Configure MySQL after installation                        #
############################################################
configureMySQL(){
echo "Configuring MySQL"
sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password by "$rootpass";
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
CREATE USER "$username"@"$useraccessIP" IDENTIFIED BY '$userpass';
GRANT ALL PRIVILEGES ON *.* TO "$username"@"$useraccessIP";
FLUSH PRIVILEGES;
EOF

sudo mysql -u root --password="$rootpass"<<EOF
CREATE USER 'pma'@'$useraccessIP' IDENTIFIED BY 'pmapassnew';
GRANT ALL PRIVILEGES ON phpmyadmin.* TO 'pma'@'$useraccessIP' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

echo "MySQL was configured succesfully"
}
############################################################
#Load MySQL dump   if database "devops" exists             #
############################################################
loadMySQLdump(){
if `mysql -u root --password=rootpass  -e "SHOW DATABASES" | grep -q -w  devops`;
then
    echo "$RESULT database was founded"
    mysql -u root --password="$rootpass" devops < devops.sql
    echo "dump file was loaded succesfully"
else
    echo "database does not exists, creating database"
   mysql -u root --password="$rootpass" -e "create database if not exists devops"
   mysql -u root --password="$rootpass" devops < devops.sql
   echo "dump file was loaded succesfully"
fi
}

############################################################
# Apache server, PHP and PHP MyAdmin installation function #
############################################################
ApacheAndPHPMyAdminInstall(){
PHPMyAdminPort=80
wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
tar xvf phpMyAdmin-*-all-languages.tar.gz
sudo mv phpMyAdmin-*-all-languages /usr/share/phpMyAdmin
rm *gz
sudo apt install -y apache2 apache2-utils php libapache2-mod-php php-pdo php-zip php-json php-common php-fpm php-mbstring php-cli php-xml php-mysql
sudo apt install -y php-json php-mbstring php-xml
sudo cp -pr /usr/share/phpMyAdmin/config.sample.inc.php /usr/share/phpMyAdmin/config.inc.php
blowfish_pass=$(head -c 300 /dev/urandom | tr -dc A-Za-z0-9=+*/.,- | head -c32)
OLD_BLOW_FISH_CONF="\['blowfish_secret'\] = '';"
NEW_BLOW_FISH_CONF="\['blowfish_secret'\] = '$blowfish_pass';"
sudo sed -i "s|$OLD_BLOW_FISH_CONF|$NEW_BLOW_FISH_CONF|g" /usr/share/phpMyAdmin/config.inc.php
sudo sed -i "s|\['host'\] = 'localhost'|\['host'\] = '$MySQLIP'|g" /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['Servers'] = '$MySQLIP'; " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['controlhost'] = '$MySQLIP'; " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['controluser'] = 'pma'; " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['controlpass'] = 'pmapassnew';  " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['pmadb'] = 'null';  " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['bookmarktable'] = 'pma__bookmark';  " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['relation'] = 'pma__relation'; " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['table_info'] = 'pma__table_info';  " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['table_coords'] = 'pma__table_coords';  " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['pdf_pages'] = 'pma__pdf_pages';  " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['column_info'] = 'pma__column_info'; " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['history'] = 'pma__history'; " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['table_uiprefs'] = 'pma__table_uiprefs';  " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['tracking'] = 'pma__tracking';  " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['userconfig'] = 'pma__userconfig';  " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['recent'] = 'pma__recent'; " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['favorite'] = 'pma__favorite';  " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['users'] = 'pma__users';   " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['usergroups'] = 'pma__usergroups';   " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['navigationhiding'] = 'pma__navigationhiding';   " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['savedsearches'] = 'pma__savedsearches';   " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['central_columns'] = 'pma__central_columns';   " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['designer_settings'] = 'pma__designer_settings';   " /usr/share/phpMyAdmin/config.inc.php
sed -i "$ a \ \n \$cfg['Servers'][\$i]['export_templates'] = 'pma__export_templates'; " /usr/share/phpMyAdmin/config.inc.php


sudo touch /etc/apache2/sites-available/phpmyadmin.conf

PHP_MY_ADMIN_CONF_CONTENT=$(
  cat <<-END
<VirtualHost *:$PHPMyAdminPort>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>

Alias /phpmyadmin /usr/share/phpMyAdmin

<Directory /usr/share/phpMyAdmin/>
   AddDefaultCharset UTF-8

   <IfModule mod_authz_core.c>
     # Apache 2.4
     <RequireAny> 
      Require all granted
     </RequireAny>
   </IfModule>
   <IfModule !mod_authz_core.c>
     # Apache 2.2
     Order Deny,Allow
     Deny from All
     Allow from 127.0.0.1
     Allow from ::1
   </IfModule>
</Directory>

<Directory /usr/share/phpMyAdmin/setup/>
   <IfModule mod_authz_core.c>
     # Apache 2.4
     <RequireAny>
       Require all granted
     </RequireAny>
   </IfModule>
   <IfModule !mod_authz_core.c>
     # Apache 2.2
     Order Deny,Allow
     Deny from All
     Allow from 127.0.0.1
     Allow from ::1
   </IfModule>
</Directory>
END
)
echo "$PHP_MY_ADMIN_CONF_CONTENT" | sudo tee -a /etc/apache2/sites-available/phpmyadmin.conf >/dev/null

sudo a2ensite phpmyadmin
sudo mkdir /usr/share/phpMyAdmin/tmp
sudo chmod 777 /usr/share/phpMyAdmin/tmp
sudo chown -R www-data:www-data /usr/share/phpMyAdmin
sudo systemctl restart apache2
echo "Apache, PHP and PHPMyAdmin was installed succesfully"
PHPMyAdminPort=$(grep -w "VirtualHost" /etc/apache2/sites-available/phpmyadmin.conf | grep -o '[[:digit:]]*')
echo "PHPMyAdmin connection port is $PHPMyAdminPort"
}

############################################################
# Main program                                             #
############################################################


# Set variables
userpass=$(head -c 100 /dev/urandom | tr -dc A-Za-z0-9 | head -c6)
username="username"
useraccessIP="localhost"
MySQLIP="localhost"
rootpass="rootpass"
MyAdminFlag=0
MySQLFlag=0

while getopts ":a:hu:p:r:m:s" option; do
   case $option in
      h) # display Help
         Help;;
      u) #reading username for MySQL user
         username=${OPTARG};;
      p) #reading password for MySQL user
         userpass=${OPTARG};;
      r) #reading password for MySQL root user
         rootpass=${OPTARG};;
	  s) #install MySQL
	     MySQLFlag=1;;
      m) #install PHP My Admin
         MyAdminFlag=1
		 MySQLIP=${OPTARG};;
      a) #  defining from where user can have access
          useraccessIP=${OPTARG};;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
 esac
done
if ! grep -q -i 'bullseye' /etc/os-release
then 
echo "This script must be run only on Debian 11 (bullseye) system"
exit 1
fi
sudo apt-get update
if [ $MySQLFlag -eq 1 ]
then
installMySQL
configureMySQL
loadMySQLdump
echo "username is $username"
echo "user password is $userpass"
echo "root password is $rootpass"
echo "user have permission to connect from $useraccessIP"
echo "MySQL connection port is 3306"
fi
if [ $MyAdminFlag -eq 1 ]
then
ApacheAndPHPMyAdminInstall
fi


echo "IP adress of the system is $(hostname -I)"


exit 0

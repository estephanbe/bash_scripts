#! /usr/bin/bash +x

#Get the domain name.
echo "Please enter the domain name and its TLS. For instance: domain name= example, TLD= com; this will generate local domain for http://example.com"
read -p "Domain name (without TLD): " domain_name
read -p "TLD (com, org, funny): " custom_tld
read -p "Enter database username: " db_user
read -p "Enter database password for the user: " db_pass

var_dir="/var/www/$domain_name"
conf_dir="/etc/apache2/sites-available"

# Checking if the domain has been used.
if [ -d "$var_dir" ] 
then
  echo "Error: The domain name you choosed is already in use!"
  echo "Exiting the script.."
  exit
fi

# Create the Dir in /var/www and check if it has been created.
echo "Creating directory for the website.."
mkdir -p $var_dir
if [ ! -d "$var_dir" ] 
then
  echo "Error: The directory was not created for some reason!"
  echo "Exiting the script.."
  exit
fi

# Create the index file.
echo "Creating index.php for the website.."
cat << EOD > $var_dir/index.php
<?php
echo "The website is ready to be used..";
EOD
if [ ! -e "$var_dir/index.php" ] 
then
  echo "Error: $var_dir/index.php was not created for some reason!"
  echo "Rolling back.."
  rm -rf $var_dir
  echo "Exiting the script.."
  exit
fi

# Test apache2 if existed
echo "Testing if apache2 is installed on the machine.."
if [ ! -d "$conf_dir" ] 
then
  echo "Error: Apache2 is not available on the machine!"
  echo "Rolling back.."
  rm -rf $var_dir
  echo "Exiting the script.."
  exit
fi
echo "Apache2 is available.."

# Create the configration file
echo "Creating the configerations file.."
cat << EOD > $conf_dir/$domain_name.conf
<VirtualHost *:80>

ServerAdmin email@$domain_name.com
ServerName $domain_name.$custom_tld
DocumentRoot $var_dir

	<Directory $var_dir>
	    Options Indexes FollowSymLinks
	    AllowOverride all
	    Require all granted
	</Directory>

ErrorLog /var/log/apache2/$domain_name-error.log
CustomLog /var/log/apache2/$domain_name-access.log combined

</VirtualHost>
EOD
if [ ! -e "$conf_dir/$domain_name.conf" ] 
then
  echo "Error: $conf_dir/$domain_name.conf was not created for some reason!"
  echo "Rolling back.."
  rm -rf $var_dir
  echo "Exiting the script.."
  exit
fi
echo "$domain_name.conf was created successfully.."

# Add the domain to 
echo "Adding the domain to /etc/hosts.."
echo -e "127.0.0.1\t$domain_name.$custom_tld" >> /etc/hosts
if ! grep -Pcq "127.0.0.1\t$domain_name.$custom_tld" /etc/hosts
then
  echo "Error: custom domain was not added to /etc/hosts for some reason.."
  echo "Rolling back.."
  rm -rf $var_dir
  rm -rf $conf_dir/$domain_name.conf
  echo "Exiting the script.."
  exit
fi
echo "custom domain was added successfuly to /etc/hosts.."

# Run a2ensite
a2ensite $domain_name.conf
echo "Reloading apache2.."
systemctl reload apache2
echo "Apache2 reloaded.."

#Testing the site
echo "Testing the site if working.."
if ! curl -s --head http://$domain_name.$custom_tld | head -n 1 | grep "HTTP/1.[01] [23].."
then 
  echo "Error: The custom site is not loading for some reason.."
  echo "Rolling back.."
  a2dissite $domain_name.conf
  rm -rf $var_dir
  rm -rf $conf_dir/$domain_name.conf
  sed -Ei "/127.0.0.1\t$domain_name.$custom_tld/d" /etc/hosts
  systemctl reload apache2
  echo "Reloading apache2.."
  echo "Exiting the script.."
  exit
fi
echo "The custom site is working and ready to be used on http://$domain_name.$custom_tld"

#Creating DB
echo "Creating the database.."
mysql -u$db_user -p$db_pass -e "CREATE DATABASE ${domain_name}_db;"

# -z STRING => True of the length if "STRING" is zero.
if [[ ! -z "`mysql -qfsBe "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${domain_name}_db'" 2>&1`" ]];
then
  echo "Database '${domain_name}_db' was successfuly created.."
  chmod -R 777 $var_dir
else
  echo "Database '${domain_name}_db' was not successfuly created.."
  echo "Rolling back.."
  a2dissite $domain_name.conf
  rm -rf $var_dir
  rm -rf $conf_dir/$domain_name.conf
  sed -Ei "/127.0.0.1\t$domain_name.$custom_tld/d" /etc/hosts
  systemctl reload apache2
  echo "Reloading apache2.."
  echo "Exiting the script.."
  exit
fi





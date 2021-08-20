#! /usr/bin/bash +x

#Get the domain name.
echo "Please enter the domain name and its TLS. For instance: domain name= example, TLD= com; this will generate local domain for http://example.com"
read -p "Domain name (without TLD): " domain_name
read -p "TLD (com, org, funny): " custom_tld
read -p "Enter database username: " db_user
read -p "Enter database password for the user: " db_pass
read -p "Enter the WordPress site title: " wp_site_title

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

# Check if WP-CLI is not installed
if ! command -v wp &> /dev/null
then
  echo "installing WP-CLI.."
  curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  # Check if the installation succeeded
  if test -f "./wp-cli.phar";
  then
    chmod +x wp-cli.phar
    sudo mv wp-cli.phar /usr/local/bin/wp
    echo "WP-CLI installed successfully.."
  else
    echo "Error: WP-CLI.phar was not downloaded successfully.."
    echo "Rolling back.."
    mysql -u$db_user -p$db_pass -e "DROP DATABASE ${domain_name}_db;"
    a2dissite $domain_name.conf
    rm -rf $var_dir
    rm -rf $conf_dir/$domain_name.conf
    sed -Ei "/127.0.0.1\t$domain_name.$custom_tld/d" /etc/hosts
    systemctl reload apache2
    echo "Reloading apache2.."
    echo "Exiting the script.."
    exit
  fi
fi

# Installing the WP site
# Download WP Core.
wp core download --path=$var_dir --allow-root

# Generate the wp-config.php file
wp core config --allow-root --path=$var_dir --dbname=${domain_name}_db --dbuser=$db_user --dbpass=$db_pass --extra-php <<PHP
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', true);
define('WP_MEMORY_LIMIT', '256M');
PHP

# Install the WordPress database.
base_url="http://$domain_name.$custom_tld"
wp core install --allow-root --path=$var_dir --url=$base_url --title="$wp_site_title" --admin_user=admin --admin_password=admin --admin_email=example@example.com

# Install Arabic language support
echo "Installing Arabic language support.."
wp language core install ar --allow-root

# Install usful plugins for development
echo "Installing usful plugins.."
wp plugin install query-monitor --activate --allow-root


# Creating the custom theme along with Themalizer
echo "Creating theme's directory, initiating Git, and getting Themalizer.."
mkdir $var_dir/wp-content/themes/${domain_name}_custom_theme
cd $var_dir/wp-content/themes/${domain_name}_custom_theme
git init
git submodule add https://github.com/estephanbe/Themalizer.git
cd Themalizer
php ./themalizer init

chmod -R 777 $var_dir

echo "Your $wp_site_title website was installed successfully with its theme.."
echo "login username: admin"
echo "login password: admin"
echo "You can access your new site on: '$base_url'"


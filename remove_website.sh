#! /usr/bin/bash +x

Get the domain name.
echo "Please enter the domain name and its TLS. For instance: domain name= example, TLD= com; this will generate local domain for http://example.com"
read -p "Domain name (without TLD): " domain_name
read -p "TLD (com, org, funny): " custom_tld

var_dir="/var/www/$domain_name"
conf_dir="/etc/apache2/sites-available"

# Checking if the domain has been used.
if [ -d "$var_dir" ] 
then
  echo "Removing $var_dir"
  rm -rf $var_dir
fi


# Create the configration file
if [ -e "$conf_dir/$domain_name.conf" ] 
then
  echo "Removing $conf_dir/$domain_name.conf"
  rm $conf_dir/$domain_name.conf
fi

# Remove the site from /etc/hosts
if grep -Pcq "127.0.0.1\t$domain_name.$custom_tld" /etc/hosts
then
  echo "Removing the site from /etc/hosts"
  sed -Ei "/127.0.0.1\t$domain_name.$custom_tld/d" /etc/hosts
fi

# Run a2ensite
echo "Disabling site.."
a2dissite $domain_name.conf
echo "Reloading apache2.."
systemctl reload apache2
echo "Apache2 reloaded.."

exit



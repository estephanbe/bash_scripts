#! /usr/bin/bash +x

#Get the domain name.
echo "Please enter the domain name and its TLS. For instance: domain name= example, TLD= com; this will generate local domain for http://example.com"
read -p "Domain name (without TLD): " domain_name
read -p "TLD (com, org, funny): " custom_tld
read -p "Enter database username: " db_user
read -p "Enter database password for the user: " db_pass

var_dir="/var/www/$domain_name"
conf_dir="/etc/apache2/sites-available"

echo "Removing the database.."
mysql -u$db_user -p$db_pass -e "DROP DATABASE ${domain_name}_db;"
echo "Removing conf.."
a2dissite $domain_name.conf
echo "Removing the dir.."
rm -rf $var_dir
rm -rf $conf_dir/$domain_name.conf
sed -Ei "/127.0.0.1\t$domain_name.$custom_tld/d" /etc/hosts
systemctl reload apache2
echo "Reloading apache2.."
echo "Exiting the script.."
exit





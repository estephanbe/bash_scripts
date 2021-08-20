#! /usr/bin/bash +x

var_dir="/var/www/hanan"
conf_dir="/etc/apache2/sites-available"

echo "Rolling back.."
mysql -uadmin -padmin -e "DROP DATABASE hanan_db;"
a2dissite hanan.conf
rm -rf $var_dir
rm -rf $conf_dir/hanan.conf
sed -Ei "/127.0.0.1\thanan.bosh/d" /etc/hosts
systemctl reload apache2
echo "Reloading apache2.."
echo "Exiting the script.."
exit

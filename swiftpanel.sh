#!/bin/bash
#Title          :   swiftpanel.sh
#Author         :   Thomas Bereczky - thomasbereczky@sysopsnet.com
#Date           :   12/06/2015
#Description    :   Preconfiguration script for Swift Media Group's Ubuntu 15.10 Wordpress Environment
mysqlrootpw=""
function changeconfig(){
tee "/etc/network/interfaces" > /dev/null <<EOF
source /etc/network/interfaces.d/*
auto lo
iface lo inet loopback
auto ens32
iface ens32 inet static
        address $ip
        netmask $netmask
        network $network
        broadcast $broadcast
        gateway $gateway
        dns-nameservers $dns
EOF
  service networking restart
}

function valid_ip(){
  local  ip=$1
  local  stat=1
  
  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    ip=($ip)
    IFS=$OIFS
    [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
    && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
    stat=$?
  fi
  return $stat
}

function ipconfig(){
  echo -e "Please select the IP address you wish to use for this server."
  read -r ip
  if ! valid_ip "$ip"; then
    echo -e "Invalid IP address format, the following format should be used: 255.255.255.255"
    ipconfig
  fi
}

function netmaskconfig(){
  echo -e "Please select the Netmask you wish to use for this server."
  read -r netmask
  if ! valid_ip "$netmask"; then
    echo -e "Invalid Netmask format, the following format should be used: 255.255.255.255"
    netmaskconfig
  fi
}

function gatewayconfig(){
  echo -e "Please select the Gateway you wish to use for this server."
  read -r gateway
  if ! valid_ip "$gateway"; then
    echo -e "Invalid Gateway format, the following format should be used: 255.255.255.255"
    gatewayconfig
  fi
}

function networkcf(){
  echo -e "Please select the Network you wish to use for this server."
  read -r network
  if ! valid_ip "$network"; then
    echo -e "Invalid Network format, the following format should be used: 255.255.255.255"
    networkcf
  fi
}

function broadcastconfig(){
  echo -e "Please select the Broadcast you wish to use for this server."
  read -r broadcast
  if ! valid_ip "$broadcast"; then
    echo -e "Invalid Broadcast format, the following format should be used: 255.255.255.255"
    broadcastconfig
  fi
}

function dnsconfig(){
  echo -e "Please select the Primary DNS server you wish to use for this server."
  read -r dns
  if ! valid_ip "$dns"; then
    echo -e "Invalid DNS format, the following format should be used: 255.255.255.255"
    dnsconfig
  fi
}

function shownetworksettings(){
  echo -e "The following network settings will be configured:"
  echo -e "IP Address: " "$ip"
  echo -e "Netmask:" "$netmask"
  echo -e "Gateway: " "$gateway"
  echo -e "Broacast: " "$broadcast"
  echo -e "Network: " "$network"
  echo -e "Primary DNS: " "$dns"
  while true; do
    read -r -p "Are you sure the following settings are correct? " yn
    case $yn in
      [Yy]* ) changeconfig; break;;
      [Nn]* ) networkconfig;;
      * )
    esac
  done
}

function networkconfig(){
  echo -e "\nNetwork Configuration:"
  echo -e "Do not forget to create a Virtual Mac at the datacenter's page before you run this script."
  ipconfig
  netmaskconfig
  networkcf
  broadcastconfig
  gatewayconfig
  dnsconfig
  shownetworksettings
  loadmenu
}

function configuredomain(){
tee "/etc/php5/mods-available/newrelic.ini" > /dev/null <<EOF
extension = "newrelic.so"
[newrelic]
newrelic.license = "d843a02b30c54c79095d141ea2cb818d327404db"
newrelic.logfile = "/var/log/newrelic/php_agent.log"
newrelic.appname = "$domain"
newrelic.daemon.logfile = "/var/log/newrelic/newrelic-daemon.log"
EOF
  /bin/cp -rf /etc/nginx/sites-available/default.sample /etc/nginx/sites-available/default
  sed -i "s/template.swiftmedia.ca/$domain/g" /etc/nginx/sites-available/default
  service php5-fpm restart
  service nginx restart
}

function domainconfignow(){
  echo -e "Please specify the domain name of this server:"
  read -r domain
  if ! echo "$domain" | egrep -q '[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*(\.[A-Za-z]{2,})'; then
    echo -e "Invalid Domain name format, the following format should be used: example.com"
    domainconfignow
  fi
  configuredomain
  loadmenu
}

function adddb(){
  database=$(strings /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
  mysqluser=$(strings /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
  mysqlpw=$(strings /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
  mysql --user="root" --password="$mysqlrootpw" --execute="CREATE DATABASE $database CHARACTER SET utf8 COLLATE utf8_bin;GRANT ALL PRIVILEGES ON $database.* TO '$mysqluser'@'localhost' IDENTIFIED BY '$mysqlpw';FLUSH PRIVILEGES;"
  echo -e "Database login details:"
  echo -e "Username: " "$mysqluser"
  echo -e "Password: " "$mysqlpw"
  echo -e "Database: " "$database"
  echo -e "Host: 127.0.0.1"
  echo -e "The following configuration has been saved to /root/mysqldbdetails"
  echo -e "MySQL Username:" "$mysqluser" "Password:" "$mysqlpw" "Database:" "$database" >> /root/mysqldbdetails
  loadmenu
}

function dbremove(){
  dbs=$(mysql -N -s --user="root" --password="$mysqlrootpw" --execute="SHOW DATABASES;")
  if echo "${dbs[@]}" | grep -qw -e "$dbremove" ; then
    mysql --user="root" --password="$mysqlrootpw" --execute="DROP DATABASE $dbremove;"
    loadmenu
  else
    echo "!!! Wrong database name has been given. !!!"
    removedb
  fi
}

function dbremoveuser(){
  dbsuser=$(mysql -N -s --user="root" --password="$mysqlrootpw" --execute="select User from mysql.user;")
  if echo "${dbsuser[@]}" | grep -qw -e "$dbremoveuser" ; then
    mysql --user="root" --password="$mysqlrootpw" --execute="revoke all privileges, grant option from '$dbremoveuser'@'localhost';drop user '$dbremoveuser'@'localhost';"
    loadmenu
    
  else
    echo "!!! Wrong database username has been given. !!!"
    removedbuser
  fi
}

function removedb(){
  echo -e "!!! DO NOT DROP DATABASE 'mysql' OR 'performance_schema' OR 'information_schema' !!!"
  echo -e "List of databases:"
  mysql --user="root" --password="$mysqlrootpw" --execute="SHOW DATABASES;"
  echo -e "Which database would you like to remove?"
  read -r dbremove
  dbremove
}

function removedbuser(){
  echo -e "!!! DO NOT REMOVE THE 'root' or 'debian-sys-maint' USER !!!"
  echo -e "List of databases users:"
  mysql --user="root" --password="$mysqlrootpw" --execute="select User from mysql.user;"
  echo -e "Which database user would you like to remove?"
  read -r dbremoveuser
  dbremoveuser
}

function swiftdb(){
  swiftdbs=$(mysql -N -s --user="root" --password="$mysqlrootpw" --execute="SHOW DATABASES;")
  if [ -z "$dbprefix" ]; then
    echo -e "!!! Empty database prefix has been given. !!!"
    addswiftusr
  fi
  
  if ! echo "${swiftdbs[@]}" | grep -qw -e "$wpdbname" ; then
    echo -e "!!! Wrong database name has been given. !!!"
    addswiftusr
  fi
  tablecheck=$(mysql -N -s --user="root" --password="$mysqlrootpw" -D "$wpdbname" -e "show tables;")
  if echo "${tablecheck[@]}" | grep -qw -e "$dbprefix"_users ; then
    level='"administrator"'
    mysql --user="root" --password="$mysqlrootpw" -D "$wpdbname" --execute="INSERT INTO "$dbprefix"_users (ID, user_login, user_pass, user_nicename, user_email, user_url, user_registered, user_activation_key, user_status, display_name) VALUES ('555', 'swift', MD5('drePH7yakuXespeq'), 'Swift Media Group', 'support@swiftmedia.ca', 'http://swiftmedia.ca/', '2015-01-01 00:00:00', '', '0', 'Swift Media Group');"
    mysql --user="root" --password="$mysqlrootpw" -D "$wpdbname" --execute="INSERT INTO "$dbprefix"_usermeta (umeta_id, user_id, meta_key, meta_value) VALUES (NULL, '555', '"$dbprefix"_capabilities', 'a:1:{s:13:"$level";b:1;}');"
    mysql --user="root" --password="$mysqlrootpw" -D "$wpdbname" --execute="INSERT INTO "$dbprefix"_usermeta (umeta_id, user_id, meta_key, meta_value) VALUES (NULL, '555', '"$dbprefix"_user_level', '10');"
    loadmenu
  else
    echo -e "!!! The specified database is not a Wordpress database or the database prefix mismatch. !!!"
    loadmenu
  fi
}

function addswiftusr(){
  echo -e "Please specify the Wordpress database name."
  read -r wpdbname
  echo -e "Please specify the Wordpress database table prefix, the default prefix is 'wp'"
  read -r dbprefix
  swiftdb
}

function rsyncnow(){
  if [ -z "$remotehost" ]; then
    echo -e "!!! Empty Hostname or IP address has been given. !!!"
    rsyncwp
  fi
  
  if [ -z "$sshuser" ]; then
    echo -e "!!! Empty SSH User has been given. !!!"
    rsyncwp
  fi
  
  if [ -z "$sshport" ]; then
    echo -e "!!! Empty SSH Port has been given. !!!"
    rsyncwp
  fi
  
  if [ -z "$remotelocation" ]; then
    echo -e "!!! Empty remote location has been given. !!!"
    rsyncwp
  fi
  
  if (( "$sshport" < 1 || "$sshport" > 65535 )) ; then
    echo -e "!!! $sshport is not a valid port !!!"
    rsyncwp
  fi
  
  rsync -avz -e "ssh -p $sshport" "$sshuser"@"$remotehost":"$remotelocation" /home/nginx/httpdocs/
  chown -R nginx:nginx /home/nginx/httpdocs
  loadmenu
}

function rsyncwp(){
  echo -e "Please specify the IP or Hostname of the remote server which we will transfer from: (Example: 192.99.177.50 or domain.com)"
  read -r remotehost
  echo -e "Please specify the SSH user of the remote server (Example: root)"
  read -r sshuser
  echo -e "Please specify the SSH port of the remote server (Example: 22)"
  read -r sshport
  echo -e "Please specify the location of the Wordpress installation in the remote server: (Example: /home/swiftgrp/public_html/)"
  echo -e "IMPORTANT Please write the path with / at the beginning and / at the end."
  read -r remotelocation
  rsyncnow
}

function changehost(){
  if [ -z "$newhostname" ]; then
    echo -e "!!! Empty hostname has been given. !!!"
    changehostname
  fi
  echo "$newhostname">/etc/hostname
  currentipaddr=$(/sbin/ifconfig ens32 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
tee "/etc/hosts" > /dev/null <<EOF
127.0.0.1       localhost
$currentipaddr   $newhostname.swiftmedia.ca     $newhostname
EOF
  loadmenu
}

function changehostname(){
  echo -e "Please specify the Hostname of this Server: (Example: vps10)"
  echo -e "!!! NOTE: Do not write vps10.swiftmedia.ca, write only vps10 !!!"
  read -r newhostname
  changehost
}

function bakdb(){
  dbbaks=$(mysql -N -s --user="root" --password="$mysqlrootpw" --execute="SHOW DATABASES;")
  
  if ! echo "${dbbaks[@]}" | grep -qw -e "$dbbakname" ; then
    echo -e "!!! Wrong database name has been given. !!!"
    mysqlbak
  fi
  mkdir -p /backup/
  mysqldump --user="root" --password="$mysqlrootpw" "$dbbakname" | gzip > /backup/"$dbbakname"-db-"$(date +'%Y-%m-%d')".gz
  loadmenu
}

function mysqlbak(){
  echo -e "Please specify the database name that you wish to backup:"
  read -r dbbakname
  bakdb
}

function rdb(){
  dbbakr=$(mysql -N -s --user="root" --password="$mysqlrootpw" --execute="SHOW DATABASES;")
  
  if ! echo "${dbbakr[@]}" | grep -qw -e "$dbrname" ; then
    echo -e "!!! Wrong database name has been given. !!!"
    restoredb
  fi
  
  if [ -z "$dblocation" ]; then
    echo -e "!!! The Database location cannot be empty. !!!"
    restoredb
  fi
  
  if [ ! -e "$dblocation" ]; then
    echo -e "!!! The specified Database path is wrong !!!"
    restoredb
  fi
  
  mysql --user="root" --password="$mysqlrootpw" "$dbrname" < "$dblocation"
  loadmenu
}

function restoredb(){
  echo -e "Please specify the name of the database you wish to restore:"
  read -r dbrname
  echo -e "Please specify the location of the MySQL dumb file on this server: (Example: /root/mysqldump.sql)"
  read -r dblocation
  rdb
}

function loadmenu(){
  echo -e "Please choose from the following options:"
  echo -e "1) Network Configuration"
  echo -e "2) Change Hostname"
  echo -e "3) System Update"
  echo -e "4) Domain Configuration"
  echo -e "5) Add MySQL Database and User"
  echo -e "6) Remove MySQL Database"
  echo -e "7) Remove MySQL Database User"
  echo -e "8) Add the Swift user to the Wordpress Database (This function only works if you have restored a Wordpress database in this server)"
  echo -e "9) Migrate a Wordpress installation via Rsync"
  echo -e "10) Start Virus Scan for WebRoot"
  echo -e "11) Create a MySQL Database Backup"
  echo -e "12) Restore a MySQL database dump"
  echo -e "13) Quit"
  read -r menu
  case $menu in
    1) networkconfig;;
    2) changehostname;;
    3) apt-get update && apt-get upgrade -y;loadmenu;;
    4) domainconfignow;;
    5) adddb;;
    6) removedb;;
    7) removedbuser;;
    8) addswiftusr;;
    9) rsyncwp;;
    10) clamscan -ir /home/nginx/httpdocs;loadmenu;;
    11) mysqlbak;;
    12) restoredb;;
    13) exit 0;;
    *) echo "Invalid Option";loadmenu;;
  esac
}

echo -e "Welcome to Swift Media Group's Wordpress Control Panel!"
echo -e "!!! THIS APPLICATION SHOULD ONLY BE RUNNING AS ROOT !!!"
loadmenu

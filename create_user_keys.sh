#!/bin/bash

curdir=`pwd`
server=""
port="1194"
proto="udp"


echo -n "Enter username: "
read username

echo -n "Enter password: "
read password

if [ -z $server ]; then
    echo -n "Enter server addr: "
    read server
fi


cd  /usr/share/easy-rsa/
. ./vars
./build-key --batch $username

mkdir -p /tmp/$server_$username
mkdir -p /var/www/keys/$username/{archive,configs,keys}
cp /etc/openvpn/keys/{$username.crt,$username.key,dh2048.pem,ca.crt,ta.key} /var/www/keys/$username/keys/
htpasswd -bc /var/www/keys/$username/passwd $username $password

cp /etc/openvpn/keys/{$username.crt,$username.key,dh2048.pem,ca.crt,ta.key} /tmp/$server_$username

cat > /tmp/$server_$username/$username.ovpn << EOF
client
dev tun
proto udp
#### New server
remote $server 1194

nobind
persist-key
persist-tun
ca "ca.crt"
cert "$username.crt"
key "$username.key"
dh "dh2048.pem"
tls-auth ta.key 1
# comp-lzo
verb 3
topology subnet
cipher AES-256-CBC
keysize 256
EOF

cat > /tmp/$server_$username/$username-inone.conf << EOF
client
dev tun
proto udp
#### New server
remote $server 1194

nobind
persist-key
persist-tun
<ca>
`cat /tmp/$server_$username/ca.crt`

</ca>

<key>
`cat /tmp/$server_$username/$username.key`

</key>

<cert>
`cat /tmp/$server_$username/$username.crt`

</cert>

<dh>
`cat /tmp/$server_$username/dh2048.pem`

</dh>

key-direction 1
<tls-auth>
`cat /tmp/$server_$username/ta.key`

</tls-auth>
# comp-lzo
verb 3
topology subnet
cipher AES-256-CBC
EOF

cat > /tmp/$server_$username/$username.conf << EOF
client
dev tun
proto udp
#### New server
remote $server 1194

nobind
persist-key
persist-tun
ca "ca.crt"
cert "$username.crt"
key "$username.key"
dh "dh2048.pem"
tls-auth ta.key 1
# comp-lzo
verb 3
topology subnet
cipher AES-256-CBC
keysize 256
EOF

cd /tmp/$server_$username/

cat > /tmp/$server_$username/android.conf << EOF
# Enables connection to GUI
management /data/data/de.blinkt.openvpn/cache/mgmtsocket unix
management-client
management-query-passwords
management-hold

# setenv IV_GUI_VER "de.blinkt.openvpn 0.6.57" 
# setenv IV_PLAT_VER "16 4.1.1 armeabi-v7a TCT MTC_970H MTC 970H"
machine-readable-output
ifconfig-nowarn
client
verb 4
connect-retry 2 300
resolv-retry 60
dev tun
remote server 1194 udp
<ca>
`cat ./ca.crt`

</ca>

<key>
`cat ./$username.key`

</key>

<cert>
`cat ./$username.crt`

</cert>

<dh>
`cat ./dh2048.pem`

</dh>

key-direction 1
<tls-auth>
`cat ./ta.key`

</tls-auth>

key-direction 1
# route-ipv6 ::/0
# route 0.0.0.0 0.0.0.0 vpn_gateway
# verify-x509-name $server name
remote-cert-tls server
# Use system proxy setting
management-query-proxy
cipher AES-256-CBC
keysize 256
EOF


cat > /var/www/keys/$username/.htaccess << EOF
AuthType Basic
AuthName "Password Required (user: $username)"
AuthUserFile "/var/www/keys/$username/passwd"
Require valid-user

<Files ./passwd>
    Order Allow,Deny
    Deny from all
</Files>

<FilesMatch "\.(?i:doc|odf|pdf|rtf|txt|conf|key|crt|pem|ovpn)$">
  Header set Content-Disposition attachment
</FilesMatch>
EOF

rm -f /etc/openvpn/clients/$username.tar.gz
tar --no-recursion -zcf /etc/openvpn/clients/$username.tar.gz ./$username.crt ./$username-inone.conf ./$username.key ./dh2048.pem ./ca.crt ./ta.key ./$username.ovpn ./$username.conf ./android.conf
cp ./{$username.ovpn,$username.conf,android.conf,$username-inone.conf} /var/www/keys/$username/configs/
cp /etc/openvpn/clients/$username.tar.gz /var/www/keys/$username/archive/

rm -rf /tmp/$server_$username
chown -R www-data /var/www/keys/$username

echo ""
echo "Created archive to /etc/openvpn/clients/$username.tar.gz"
echo "Files also available via web on https://$server/$username"
echo ""

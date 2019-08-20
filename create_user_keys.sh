#!/bin/bash

curdir=`pwd`
arcs_dir="/etc/openvpn"
server=""
port="1194"
proto="tcp"

genpw() {
    len=16
    tr -dc A-Za-z0-9_ < /dev/urandom | head -c ${len} | xargs
}

if [ ! -d $arcs_dir/pki ]; then
    echo "It seems the easyrsa is not initialized"
    echo ""
    echo "Run commands:"
    echo "easyrsa init-pki"
    echo "easyrsa build-ca nopass"
    echo "easyrsa gen-req srv-openvpn nopass"
    echo "easyrsa sign-req server srv-openvpn"
    exit 1
fi

if [ ! -d $arcs_dir/clients ]; then
    mkdir -p $arcs_dir/clients
fi

if [ -z $1 ]; then
    echo -n "Enter username: "
    read username
else
    username=$1
fi

if [ -z $2 ]; then
    #echo -n "Enter password: "
    #read password
    password=$(genpw)
else
    password=$2
fi

if [ -z $server ]; then
    echo -n "Enter server addr: "
    read server
fi

easyrsa --batch --req-cn=$username gen-req $username nopass
if [ $? -eq 0 ]; then
    easyrsa --batch sign-req client $username
else
    echo "Something went wrong!"
    exit 1
fi

mkdir -p /tmp/$server_$username
cp $arcs_dir/pki/issued/$username.crt /tmp/$server_$username
cp $arcs_dir/pki/private/$username.key /tmp/$server_$username
cp $arcs_dir/pki/ca.crt /tmp/$server_$username
echo >./ccd/$username


cat > /tmp/$server_$username/$username.ovpn << EOF
client
dev tun
proto $proto
#### New server
remote $server $port

nobind
persist-key
persist-tun
ca "ca.crt"
cert "$username.crt"
key "$username.key"
# dh "dh2048.pem"
# tls-auth ta.key 1
# comp-lzo
verb 3
topology subnet
cipher AES-256-CBC
keysize 256
EOF

cat > /tmp/$server_$username/$username-inone.ovpn << EOF
client
dev tun
proto $proto
#### New server
remote $server $port

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

#<dh>
#</dh>

# key-direction 1
# <tls-auth>
# </tls-auth>
# comp-lzo

verb 3
topology subnet
cipher AES-256-CBC

remote-cert-tls server
auth-user-pass
EOF

cat > /tmp/$server_$username/$username.conf << EOF
client
dev tun
proto $proto
#### New server
remote $server $port

nobind
persist-key
persist-tun
ca "ca.crt"
cert "$username.crt"
key "$username.key"
# dh "dh2048.pem"
# tls-auth ta.key 1
# comp-lzo
verb 3
topology subnet
cipher AES-256-CBC
keysize 256
remote-cert-tls server
auth-user-pass
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
remote $server $port $proto
<ca>
`cat ./ca.crt`

</ca>

<key>
`cat ./$username.key`

</key>

<cert>
`cat ./$username.crt`

</cert>

#<dh>
#</dh>

#key-direction 1
#<tls-auth>
#</tls-auth>

# route-ipv6 ::/0
# route 0.0.0.0 0.0.0.0 vpn_gateway
# verify-x509-name $server name
# remote-cert-tls server
# Use system proxy setting

management-query-proxy
cipher AES-256-CBC
keysize 256
EOF

cat > /tmp/$server_$username/lopass.txt << EOF
$username
$password

EOF

# Create user on mikrotik
# /ppp secret add name=$username password=$password service=ovpn

cd /tmp/$server_$username
if [ -f $arcs_dir/clients/$username.tar.gz ]; then
    rm -f $arcs_dir/clients/$username.tar.gz
fi
tar --no-recursion -zcf $arcs_dir/clients/$username.tar.gz ./$username.crt ./$username-inone.ovpn ./$username.key ./ca.crt ./$username.ovpn ./$username.conf ./android.conf ./lopass.txt

rm -rf /tmp/$server_$username

echo ""
echo "Created archive to $arcs_dir/clients/$username.tar.gz"
echo "Username: $username"
echo "Password: $password"
echo ""

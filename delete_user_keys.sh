#!/bin/sh

curdir=`pwd`

echo -n "Enter username: "
read username


#rm /var/www/keys/$username/passwd
cd  /usr/share/easy-rsa/2.0/
. ./vars
./revoke-full $username


echo ""
echo "Certificate for $username revoked"
echo ""

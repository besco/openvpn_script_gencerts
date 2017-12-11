#!/bin/sh

curdir=`pwd`

echo -n "Enter username: "
read username
if [ -z $username ];
then
    echo "Username requeried"
    exit 1
fi

rm -rf /var/www/keys/$username
cd  /usr/share/easy-rsa/
. ./vars
./revoke-full $username


echo ""
echo "Certificate for $username revoked"
echo ""

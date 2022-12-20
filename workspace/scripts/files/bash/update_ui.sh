#!/bin/bash

URL=$1
TAG=$2

UI_FOLDER=/var/www/pioreactorui

# stop services
sudo systemctl stop lighttpd.service
sudo systemctl stop huey.service

# download
wget $URL -O pioreactorui.tar.gz
# & unpack
tar -xvzf pioreactorui.tar.gz

# move data over
cp -rp $UI_FOLDER/contrib/    /tmp/pioreactorui-$TAG
cp -p $UI_FOLDER/huey.db      /tmp/pioreactorui-$TAG
cp -p $UI_FOLDER/huey.db-shm  /tmp/pioreactorui-$TAG
cp -p $UI_FOLDER/huey.db-wal  /tmp/pioreactorui-$TAG
cp -p $UI_FOLDER/.env         /tmp/pioreactorui-$TAG

# swap folders
rm -rf $UI_FOLDER
mkdir $UI_FOLDER 
mv /tmp/pioreactorui-$TAG/* $UI_FOLDER # TODO: this line is broken

# cleanup
rm -rf /tmp/pioreactorui-$TAG
rm pioreactorui.tar.gz

# start services again
sudo systemctl start huey.service
sudo systemctl start lighttpd.service
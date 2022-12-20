#!/bin/bash
set -x
set -e

export LC_ALL=C

SOURCE=$1
TAG=$2

UI_FOLDER=/var/www/pioreactorui

# stop services
sudo systemctl stop lighttpd.service
sudo systemctl stop huey.service

# & unpack
tar -xvzf "$SOURCE" -C /tmp

# move data over
cp -rp $UI_FOLDER/contrib/    /tmp/pioreactorui-"$TAG" 2>/dev/null || :
cp -p $UI_FOLDER/huey.db      /tmp/pioreactorui-"$TAG" 2>/dev/null || :
cp -p $UI_FOLDER/huey.db-shm  /tmp/pioreactorui-"$TAG" 2>/dev/null || :
cp -p $UI_FOLDER/huey.db-wal  /tmp/pioreactorui-"$TAG" 2>/dev/null || :
cp -p $UI_FOLDER/.env         /tmp/pioreactorui-"$TAG" 2>/dev/null || :

# swap folders
rm -rf $UI_FOLDER
mkdir $UI_FOLDER
cp -rp /tmp/pioreactorui-"$TAG"/. $UI_FOLDER
sudo chgrp -R www-data $UI_FOLDER

# cleanup
rm -rf /tmp/pioreactorui-"$TAG"

# start services again
sudo systemctl start huey.service
sudo systemctl start lighttpd.service

#!/bin/bash

# See also: update_ui.sh is a bash script for updating pioreactorui from tar.gz files.

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

UI_FOLDER=/var/www/pioreactorui
SYSTEMD_DIR=/etc/systemd/system/


mkdir /var/www

# needed for fast yaml
apt-get install libyaml-dev -y
# https://github.com/yaml/pyyaml/issues/445
sudo pip3 install --no-cache-dir --no-binary pyyaml pyyaml

# get latest pioreactorUI code from Github.

latest_release=$(curl -sS https://api.github.com/repos/pioreactor/pioreactorui/releases/latest)

tag=$(echo "$latest_release" | sed -Ene '/^ *"tag_name": *"(.+)",$/s//\1/p')


if [ "$PIO_VERSION" == "develop" ]; then
    tag="develop"
fi

echo "Installing UI version $tag"
curl -sS -o pioreactorui.tar.gz -JLO https://github.com/pioreactor/pioreactorui/archive/"$tag".tar.gz
tar -xzf pioreactorui.tar.gz
mv pioreactorui-"$tag" /var/www
mv /var/www/pioreactorui-"$tag" $UI_FOLDER
rm pioreactorui.tar.gz

# install the dependencies
# new: dependencies are installed with Pioreactor app
# sudo pip3 install -r $UI_FOLDER/requirements.txt

# init .env
mv $UI_FOLDER/.env.example $UI_FOLDER/.env

# init sqlite db
touch $UI_FOLDER/huey.db
touch $UI_FOLDER/huey.db-shm
touch $UI_FOLDER/huey.db-wal

# make correct permissions in new www folders and files
# https://superuser.com/questions/19318/how-can-i-give-write-access-of-a-folder-to-all-users-in-linux
chown -R pioreactor:www-data /var/www
chmod -R g+w /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod ug+rw {} \;
chmod +x $UI_FOLDER/main.fcgi

# install lighttp and set up mods
apt-get install lighttpd -y

# install our own lighttpd service
sudo cp /files/system/systemd/lighttpd.service $SYSTEMD_DIR
sudo systemctl enable lighttpd.service


cp /files/system/lighttpd/lighttpd.conf        /etc/lighttpd/lighttpd.conf
cp /files/system/lighttpd/10-expire.conf       /etc/lighttpd/conf-available/10-expire.conf
cp /files/system/lighttpd/50-pioreactorui.conf /etc/lighttpd/conf-available/50-pioreactorui.conf
cp /files/system/lighttpd/51-cors.conf         /etc/lighttpd/conf-available/51-cors.conf
cp /files/system/lighttpd/20-compress.conf     /etc/lighttpd/conf-available/20-compress.conf
cp /files/system/lighttpd/52-api-only.conf     /etc/lighttpd/conf-available/52-api-only.conf

lighttpd-enable-mod expire
lighttpd-enable-mod fastcgi
lighttpd-enable-mod rewrite
lighttpd-enable-mod pioreactorui
lighttpd-enable-mod cors
# lighttpd-enable-mod compress # this wasn't working, and was causing binary data to leak into json responses...

if [ "$LEADER" != "1" ]; then
    # workers only have an api, not served static files.
    lighttpd-enable-mod api-only
fi


# we add entries to mDNS: pioreactor.local (can be modified in config.ini), and we need the following:
# see avahi_aliases.service for how this works
sudo apt-get install avahi-utils -y

# install ufw since this is pretty common in larger networks
sudo apt install ufw -y

# test that tools works:
flask --help
lighttpd -h
huey_consumer -h


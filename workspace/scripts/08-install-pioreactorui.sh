#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

UI_FOLDER=/var/www/pioreactorui

if [ "$LEADER" == "1" ]; then

    # needed for fast yaml
    apt-get install libyaml-dev -y
    # https://github.com/yaml/pyyaml/issues/445
    sudo pip3 install --no-cache-dir --no-binary pyyaml pyyaml

    # get latest pioreactorUI code from Github.
    latest_tag=$(curl -s https://api.github.com/repos/pioreactor/pioreactorui/releases/latest | sed -Ene '/^ *"tag_name": *"(.+)",$/s//\1/p')
    echo "Installing UI version $latest_tag"
    curl -JLO https://github.com/pioreactor/pioreactorui/archive/"$latest_tag".tar.gz
    tar -xvzf pioreactorui-"$latest_tag".tar.gz
    mv pioreactorui-"$latest_tag" $UI_FOLDER

    # install the dependencies
    sudo pip3 install -r $UI_FOLDER/requirements.txt

    # init .env
    mv $UI_FOLDER/.env.example $UI_FOLDER/.env

    # init sqlite db
    touch $UI_FOLDER/huey.db
    touch $UI_FOLDER/huey.db-shm
    touch $UI_FOLDER/huey.db-wal

    # make correct permissions in new www folders and files
    # https://superuser.com/questions/19318/how-can-i-give-write-access-of-a-folder-to-all-users-in-linux
    chgrp -R www-data /var/www
    chmod -R g+w /var/www
    find /var/www -type d -exec chmod 2775 {} \;
    find /var/www -type f -exec chmod ug+rw {} \;
    chmod +x $UI_FOLDER/main.fcgi

    # install lighttp and set up mods
    apt-get install lighttpd -y
    cp /files/system/lighttpd/50-pioreactorui.conf /etc/lighttpd/conf-available/50-pioreactorui.conf

    lighttpd-enable-mod fastcgi
    lighttpd-enable-mod rewrite
    lighttpd-enable-mod pioreactorui

    # Note: update_ui.sh is a bash script for updating pioreactorui from tar.gz files.

    # we add entries to mDNS: pioreactor.local (can be modified in config.ini), and we need the following:
    # see avahi_aliases.service for how this works
    sudo apt-get install avahi-utils -y

fi
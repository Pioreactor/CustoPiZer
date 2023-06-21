#!/bin/bash
set -x
set -e

export LC_ALL=C

SRC_TAR=$1
TAG=$2

UI_FOLDER=/var/www/pioreactorui
SRC_FOLDER=/tmp/pioreactorui-"$TAG"

function finish {
    # cleanup
    rm -rf "$SRC_FOLDER" || true
    sudo systemctl restart lighttpd.service
    sudo systemctl restart huey.service
}
trap finish EXIT


# unpack source provided
tar -xvzf "$SRC_TAR" -C /tmp

# copy data over
# use rsync because we want to merge custom yamls the user has, we any updates to our own yamls.
rsync -ap --ignore-existing $UI_FOLDER/contrib/ "$SRC_FOLDER"/contrib/ 2>/dev/null || :
cp -p $UI_FOLDER/.env         "$SRC_FOLDER" 2>/dev/null || :

# swap folders
sudo rm -rf $UI_FOLDER
mkdir $UI_FOLDER
cp -rp "$SRC_FOLDER"/. $UI_FOLDER
sudo chgrp -R www-data $UI_FOLDER



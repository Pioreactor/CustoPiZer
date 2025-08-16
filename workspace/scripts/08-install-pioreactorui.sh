#!/bin/bash

# Purpose: Install and configure lighttpd to serve the Pioreactor web API.
# Notes:
# - Web API is packaged inside the Python package under pioreactor/web.
# - Lighttpd manages FastCGI (bin-path=/usr/bin/pioreactor-fcgi).
# - Leaders serve static assets via alias; workers enable api-only.

# See also: update_ui.sh is a bash script for updating pioreactorui from tar.gz files.

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

SYSTEMD_DIR=/etc/systemd/system/

# ensure /var/www exists (lighttpd doc-root); static served via alias
mkdir -p /var/www

# install lighttpd and set up mods
apt-get install -y lighttpd

# install our own lighttpd service (enablement handled by pioreactor.target)
sudo cp /files/system/systemd/lighttpd.service $SYSTEMD_DIR


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
    # workers serve API-only (no static assets)
    lighttpd-enable-mod api-only
fi


# we add entries to mDNS: pioreactor.local, see avahi_aliases.service
sudo apt-get install -y avahi-utils

# install ufw since this is pretty common in larger networks
sudo apt-get install -y ufw

# quick tool sanity
lighttpd -h
huey_consumer -h

# add yaml mime type (optional)
echo "application/yaml               yaml yml" | sudo tee -a /etc/mime.types

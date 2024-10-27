#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap


apt-get install -y python3-pip
apt-get install -y python3-dev # needed to build CLoader in pyyaml
sudo rm -rf /usr/lib/python3.11/EXTERNALLY-MANAGED || true # see jeff gerlings blog post
sudo pip3 install pip==24.0
sudo pip3 install wheel==0.41.2

# these live in /root/.config/pip/pip.conf
sudo pip3 config set global.disable-pip-version-check true # don't check for latest pip
sudo pip3 config set global.root-user-action "ignore"
sudo pip3 config set global.extra-index-url 'https://www.piwheels.org/simple'
sudo pip3 config set global.break-system-packages true


sudo pip3 install crudini==0.9.5


# test that crudini works
crudini --help


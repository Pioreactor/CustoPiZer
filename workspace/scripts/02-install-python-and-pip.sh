#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap


apt-get install -y python3-pip
apt-get install -y python3-dev # needed to build CLoader in pyyaml
apt-get install -y python3-venv
sudo rm -rf /usr/lib/python3.13/EXTERNALLY-MANAGED || true # see jeff gerlings blog post
# sudo pip3 install wheel==0.41.2

# these live in /root/.config/pip/pip.conf
# Keep system pip default configs (harmless), though we will use a venv pip
sudo pip3 config set global.disable-pip-version-check true # don't check for latest pip
sudo pip3 config set global.root-user-action "ignore"
sudo pip3 config set global.extra-index-url 'https://www.piwheels.org/simple'
sudo pip3 config set global.break-system-packages true

# Create dedicated Pioreactor virtual environment
PIO_VENV=/opt/pioreactor/venv
sudo mkdir -p /opt/pioreactor
sudo python3 -m venv "$PIO_VENV"

# Ensure venv pip is recent
sudo "$PIO_VENV/bin/pip" install --upgrade pip

# Base utilities used across scripts
sudo "$PIO_VENV/bin/pip" install \
  --index-url https://www.piwheels.org/simple \
  --extra-index-url https://pypi.org/simple \
  crudini==0.9.5 click gpiozero RPi.GPIO


# test that crudini works
"$PIO_VENV/bin/crudini" --help

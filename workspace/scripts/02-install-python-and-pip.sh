#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap


USERNAME=pioreactor
SSH_DIR=/home/$USERNAME/.ssh

apt-get install -y python3-pip
apt-get install -y python3-dev # needed to build CLoader in pyyaml
pip3 install pip -U # update to latest
pip3 config set global.disable-pip-version-check true # don't check for latest pip
pip3 config set global.root-user-action "ignore"


sudo -u $USERNAME rm -rf $SSH_DIR # remove if already exists.

sudo -u $USERNAME mkdir -p $SSH_DIR
sudo cp /files/ssh_config $SSH_DIR/config


#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap


sudo apt-get clean

USERNAME=pioreactor
PIO_DIR=/home/$USERNAME/.pioreactor

sudo -u $USERNAME touch $PIO_DIR/.image_info
sudo -u $USERNAME echo -e "CUSTOPIZER_GIT_COMMIT=$CUSTOPIZER_GIT_COMMIT"  >> $PIO_DIR/.image_info

echo_green "Complete!"
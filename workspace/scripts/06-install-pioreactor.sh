#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

USERNAME=pioreactor
PIO_DIR=/home/$USERNAME/.pioreactor

sudo -u $USERNAME mkdir -p $PIO_DIR
sudo -u $USERNAME mkdir -p $PIO_DIR/storage
sudo -u $USERNAME mkdir -p $PIO_DIR/plugins
sudo -u $USERNAME mkdir -p $PIO_DIR/plugins/ui/contrib/jobs
sudo -u $USERNAME mkdir -p $PIO_DIR/plugins/ui/contrib/automations/{dosing,led,temperature}
sudo -u $USERNAME mkdir -p $PIO_DIR/plugins/ui/contrib/charts
echo "Directory for adding Python code, see docs: https://docs.pioreactor.com/developer-guide/intro-plugins" > $PIO_DIR/plugins/README.txt
echo "Directory for adding to the UI using yaml files, see docs: https://docs.pioreactor.com/developer-guide/adding-plugins-to-ui" > $PIO_DIR/plugins/ui/README.txt


sudo pip3 install wheel
sudo pip3 install crudini

if [ "$LEADER" == "1" ]; then
    sudo apt-get install sshpass
    sudo -u $USERNAME cp /files/config.example.ini $PIO_DIR/config.ini
    sudo pip3 install --ignore-installed "pioreactor[leader] @ https://github.com/Pioreactor/pioreactor/releases/download/$PIO_VERSION/pioreactor-$PIO_VERSION-py3-none-any.whl"
fi


if [ "$WORKER" == "1" ]; then
    sudo -u $USERNAME touch $PIO_DIR/unit_config.ini
    sudo apt-get install -y python3-numpy
    sudo pip3 install --ignore-installed "pioreactor[worker] @ https://github.com/Pioreactor/pioreactor/releases/download/$PIO_VERSION/pioreactor-$PIO_VERSION-py3-none-any.whl"
fi


if [ "$PIO_VERSION" == "develop" ]; then
    sudo pip3 install -U --force-reinstall https://github.com/pioreactor/pioreactor/archive/develop.zip
fi


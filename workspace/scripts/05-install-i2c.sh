#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

if [ "$WORKER" == "1" ]; then
    sudo apt-get install -y i2c-tools
    echo "dtparam=i2c_arm=on"    | sudo tee /boot/config.txt -a
    echo "i2c-dev"               | sudo tee /etc/modules -a

    # add SPI on, too
    echo "dtparam=spi=on" | sudo tee  /boot/config.txt -a

fi
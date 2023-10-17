#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap


echo 'dtparam=watchdog=on' >> /boot/config.txt
sudo apt-get install watchdog
echo 'watchdog-device = /dev/watchdog' >> /etc/watchdog.conf
echo 'watchdog-timeout = 90' >> /etc/watchdog.conf
echo 'max-load-1 = 24' >> /etc/watchdog.conf
echo 'interface = wlan0' >> /etc/watchdog.conf


sudo systemctl enable watchdog

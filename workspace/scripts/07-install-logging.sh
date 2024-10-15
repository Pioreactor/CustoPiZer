#!/bin/bash

set -x
set -e

export LC_ALL=C

source /common.sh
install_cleanup_trap

sudo touch /var/log/pioreactor.log
sudo chown pioreactor:pioreactor /var/log/pioreactor.log
# give free conditions so anyone can write to it if needed, ie. www-data
sudo chmod 666 /var/log/pioreactor.log

# add a logrotate entries
sudo cp /files/system/logrotate/pioreactor /etc/logrotate.d/pioreactor


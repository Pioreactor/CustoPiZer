#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

sudo apt-get install chrony -y


if [ "$LEADER" == "1" ]; then
    # this IP range is for the local-access-point set up by nmcli
    echo "allow all" | sudo tee -a  /etc/chrony/chrony.conf
    echo "local stratum 10" | sudo tee -a  /etc/chrony/chrony.conf
fi


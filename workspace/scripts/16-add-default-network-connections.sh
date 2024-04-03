#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

cp /files/system/NetworkManager/PioreactorAP.nmconnection /etc/NetworkManager/system-connections/
cp /files/system/NetworkManager/PioreactorLocalLink.nmconnection /etc/NetworkManager/system-connections/

# 600 is required for security reasons, and nm won't register them if not 600
sudo chmod 600 /etc/NetworkManager/system-connections/PioreactorAP.nmconnection
sudo chmod 600 /etc/NetworkManager/system-connections/PioreactorLocalLink.nmconnection

sudo nmcli connection reload
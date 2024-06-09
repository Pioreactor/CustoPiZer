#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

cp /files/system/NetworkManager/PioreactorAP.nmconnection /etc/NetworkManager/system-connections/
cp /files/system/NetworkManager/PioreactorLocalLink.nmconnection /etc/NetworkManager/system-connections/
cp /files/system/NetworkManager/PioreactorDefaultEth.nmconnection /etc/NetworkManager/system-connections/

# 600 is required for security reasons, and nm won't register them if not 600
sudo chmod 600 /etc/NetworkManager/system-connections/PioreactorAP.nmconnection
sudo chmod 600 /etc/NetworkManager/system-connections/PioreactorLocalLink.nmconnection
sudo chmod 600 /etc/NetworkManager/system-connections/PioreactorDefaultEth.nmconnection


# turn off avahi ipv6? This seems to solve the "hostname-N" problem some users see.
# Edit1: no, keep use-ipv6=yes, as it significantly improves how fast browsers connect to mqtt.
# nospace is important!
sudo crudini --ini-options=nospace --set /etc/avahi/avahi-daemon.conf publish publish-aaaa-on-ipv4 no
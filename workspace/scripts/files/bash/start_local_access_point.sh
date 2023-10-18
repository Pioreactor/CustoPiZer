#!/bin/bash

set -x
set -e

export LC_ALL=C

rfkill unblock wifi
for filename in /var/lib/systemd/rfkill/*:wlan ; do
   echo 0 > $filename
done

iw reg set "$(head -c 2 /boot/firmware/local_access_point)"

nmcli device wifi hotspot ssid "$(crudini --get /home/pioreactor/.pioreactor/config.ini local_access_point ssid)" password "$(crudini --get /home/pioreactor/.pioreactor/config.ini local_access_point passphrase)"
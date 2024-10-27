#!/bin/bash

set -x
set -e

export LC_ALL=C

rfkill unblock wifi

for filename in /var/lib/systemd/rfkill/*:wlan ; do
   echo 0 > "$filename"
done

sudo nmcli radio wifi on

iw reg set "$(head -c 2 /boot/firmware/local_access_point)"


sudo nmcli connection modify PioreactorAP wifi.ssid "$(crudini --get /home/pioreactor/.pioreactor/config.ini local_access_point ssid)"
sudo nmcli connection modify PioreactorAP 802-11-wireless-security.proto "$(crudini --get /home/pioreactor/.pioreactor/config.ini local_access_point proto  2> /dev/null || echo 'rsn')"
sudo nmcli connection modify PioreactorAP 802-11-wireless-security.psk "$(crudini --get /home/pioreactor/.pioreactor/config.ini local_access_point passphrase)"


sudo nmcli con up PioreactorAP

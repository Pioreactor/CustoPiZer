#!/bin/bash

set -x
set -e

export LC_ALL=C

rfkill unblock wifi
for filename in /var/lib/systemd/rfkill/*:wlan ; do
   echo 0 > $filename
done

iw reg set "$(head -c 2 /boot/firmware/local_access_point)"


sudo nmcli connection delete PioreactorAP || true

sudo nmcli connection add type wifi con-name PioreactorAP autoconnect no wifi.mode ap wifi.ssid $(crudini --get /home/pioreactor/.pioreactor/config.ini local_access_point ssid) ipv4.method shared ipv6.method disabled

sudo nmcli connection modify PioreactorAP 802-11-wireless-security.key-mgmt wpa-psk
sudo nmcli connection modify PioreactorAP 802-11-wireless-security.proto "$(crudini --get /home/pioreactor/.pioreactor/config.ini local_access_point proto  2> /dev/null || echo 'rsn')"
sudo nmcli connection modify PioreactorAP 802-11-wireless-security.psk "$(crudini --get /home/pioreactor/.pioreactor/config.ini local_access_point passphrase)"
sudo nmcli connection modify PioreactorAP 802-11-wireless.band bg
#sudo nmcli connection modify PioreactorAP wifi-sec.pmf disable
#sudo nmcli connection modify PioreactorAP 802-11-wireless-security.pmf 1



sudo nmcli con up PioreactorAP

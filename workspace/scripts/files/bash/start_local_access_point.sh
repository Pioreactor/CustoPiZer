#!/bin/bash

set -x
set -e

export LC_ALL=C


iw reg set "$(head -c 2 /boot/local_access_point)"

nmcli device wifi hotspot ssid "$(crudini --get /home/pioreactor/.pioreactor/config.ini local_access_point ssid)" password "$(crudini --get /home/pioreactor/.pioreactor/config.ini local_access_point passphrase)"
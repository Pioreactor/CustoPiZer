#!/bin/bash

set -e

export LC_ALL=C

VENV_BIN="${PIO_VENV:-/opt/pioreactor/venv}/bin"
CRUDINI="$VENV_BIN/crudini"
WIFI_CONFIG=/boot/firmware/wifi.ini

if [ ! -f "$WIFI_CONFIG" ]; then
    exit 0
fi

SSID=$("$CRUDINI" --get "$WIFI_CONFIG" wifi ssid || :)
PASSPHRASE=$("$CRUDINI" --get "$WIFI_CONFIG" wifi passphrase || :)

if [ -z "$SSID" ] || [ -z "$PASSPHRASE" ]; then
    exit 1
fi

nmcli radio wifi on

nmcli dev wifi connect "$SSID" password "$PASSPHRASE"
rm "$WIFI_CONFIG"

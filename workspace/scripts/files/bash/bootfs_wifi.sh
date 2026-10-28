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

# Recreate matching client profiles: nmcli's password update can fail on saved
# connections. Match the actual SSID, since connection names may differ.
connections=$(nmcli -t -f UUID,TYPE connection show)
while IFS=: read -r uuid type; do
    [ "$type" = "802-11-wireless" ] || continue
    mode=$(nmcli -g 802-11-wireless.mode connection show uuid "$uuid")
    # An unset mode defaults to infrastructure. Preserve hotspots and ad-hoc profiles.
    [ -z "$mode" ] || [ "$mode" = "infrastructure" ] || continue
    saved_ssid=$(nmcli --escape no -g 802-11-wireless.ssid connection show uuid "$uuid")
    if [ "$saved_ssid" = "$SSID" ]; then
        nmcli connection delete uuid "$uuid"
    fi
done <<< "$connections"

nmcli dev wifi connect "$SSID" password "$PASSPHRASE"
rm "$WIFI_CONFIG"

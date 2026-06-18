#!/bin/bash

set -e

export LC_ALL=C

WIFI_CONFIG=/boot/firmware/wifi.ini

if [ ! -f "$WIFI_CONFIG" ]; then
    exit 0
fi

SSID=$(awk -F= '
    /^\[wifi\]$/ { in_wifi=1; next }
    /^\[/ { in_wifi=0 }
    in_wifi && $1 ~ /^[[:space:]]*ssid[[:space:]]*$/ {
        sub(/^[[:space:]]*/, "", $2)
        sub(/[[:space:]]*$/, "", $2)
        print $2
        exit
    }
' "$WIFI_CONFIG")

PASSPHRASE=$(awk -F= '
    /^\[wifi\]$/ { in_wifi=1; next }
    /^\[/ { in_wifi=0 }
    in_wifi && $1 ~ /^[[:space:]]*passphrase[[:space:]]*$/ {
        sub(/^[[:space:]]*/, "", $2)
        sub(/[[:space:]]*$/, "", $2)
        print $2
        exit
    }
' "$WIFI_CONFIG")

if [ -z "$SSID" ] || [ -z "$PASSPHRASE" ]; then
    exit 1
fi

nmcli radio wifi on

nmcli dev wifi connect "$SSID" password "$PASSPHRASE"
rm "$WIFI_CONFIG"

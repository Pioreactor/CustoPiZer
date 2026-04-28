#!/bin/bash

set -x
set -e

export LC_ALL=C

# Get all IPv4 addresses
for i in {1..30}; do
    IP=$(hostname -I)
    if [ -n "$IP" ]; then
        break
    fi
    sleep 1
done

# Get the active Wi-Fi SSID, when connected over Wi-Fi.
WIFI_SSID=$(nmcli -t --escape no -f active,ssid dev wifi 2>/dev/null | awk -F: '$1 == "yes" {print substr($0, 5); exit}')

# Initialize an empty variable for network information
NETWORK_INFO="HOSTNAME=$(hostname)\nIP=$IP\nWIFI_SSID=$WIFI_SSID\n"

# Iterate over all network interfaces
for iface in /sys/class/net/*; do
    IFACE_NAME=$(basename "$iface")
    MAC_ADDR=$(cat "$iface"/address)
    NETWORK_INFO+="${IFACE_NAME}_MAC=$MAC_ADDR\n"
done

# Write the information to a file in key-value format
# Use > since we want to rewrite on every boot (not append)
echo -e "$NETWORK_INFO" > /boot/firmware/network_info.txt

sudo nmcli device status | sudo tee -a /boot/firmware/network_info.txt

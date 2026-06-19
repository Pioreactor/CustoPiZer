#!/bin/bash

set -x
set -e

export LC_ALL=C

# Get all IPv4 addresses
for _ in {1..30}; do
    IP=$(hostname -I)
    if [ -n "$IP" ]; then
        break
    fi
    sleep 1
done

# Get the active Wi-Fi SSID, when connected over Wi-Fi.
WIFI_SSID=$(nmcli -t --escape no -f active,ssid dev wifi 2>/dev/null | awk -F: '$1 == "yes" {print substr($0, 5); exit}')

LOCAL_ACCESS_POINT_PATH=/boot/firmware/local_access_point
LOCAL_ACCESS_POINT_STATUS=not_found
LOCAL_ACCESS_POINT_NOTE="No /boot/firmware/local_access_point file found."

if [ -e "$LOCAL_ACCESS_POINT_PATH" ]; then
    LOCAL_ACCESS_POINT_STATUS=found
    LOCAL_ACCESS_POINT_NOTE="Found /boot/firmware/local_access_point."
elif [ -e "$LOCAL_ACCESS_POINT_PATH (2)" ]; then
    LOCAL_ACCESS_POINT_STATUS=wrong_filename
    LOCAL_ACCESS_POINT_NOTE="Found local_access_point (2). Rename it to exactly local_access_point."
elif [ -e "$LOCAL_ACCESS_POINT_PATH.txt" ]; then
    LOCAL_ACCESS_POINT_STATUS=wrong_filename
    LOCAL_ACCESS_POINT_NOTE="Found local_access_point.txt. Rename it to exactly local_access_point."
fi

# Initialize an empty variable for network information
NETWORK_INFO="HOSTNAME=$(hostname)\nIP=$IP\nWIFI_SSID=$WIFI_SSID\nLOCAL_ACCESS_POINT_STATUS=$LOCAL_ACCESS_POINT_STATUS\nLOCAL_ACCESS_POINT_NOTE=$LOCAL_ACCESS_POINT_NOTE\n"

# Iterate over all network interfaces
for iface in /sys/class/net/*; do
    IFACE_NAME=$(basename "$iface")
    MAC_ADDR=$(cat "$iface"/address)
    NETWORK_INFO+="${IFACE_NAME}_MAC=$MAC_ADDR\n"
done

# Write the information to a file in key-value format
# Do not use tee -a here: rewrite the file on every run.
echo -e "$NETWORK_INFO" | sudo tee /boot/firmware/network_info.txt >/dev/null

sudo nmcli device status | sudo tee -a /boot/firmware/network_info.txt

{
    echo
    echo "Recent NetworkManager logs:"
    journalctl -u NetworkManager -b --no-pager -n 80
} | sudo tee -a /boot/firmware/network_info.txt >/dev/null

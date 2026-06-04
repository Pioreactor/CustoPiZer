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
LOCAL_ACCESS_POINT_STATUS=missing
LOCAL_ACCESS_POINT_FILES=
LOCAL_ACCESS_POINT_COUNTRY_CODE=
LOCAL_ACCESS_POINT_NOTE="No /boot/firmware/local_access_point file found. Add a file named exactly local_access_point to enable the access point."

shopt -s nullglob nocaseglob
LOCAL_ACCESS_POINT_MATCHES=(/boot/firmware/*local*access*point*)
shopt -u nullglob nocaseglob

if [ -f "$LOCAL_ACCESS_POINT_PATH" ]; then
    LOCAL_ACCESS_POINT_STATUS=found
    LOCAL_ACCESS_POINT_FILES=$(basename "$LOCAL_ACCESS_POINT_PATH")
    LOCAL_ACCESS_POINT_COUNTRY_CODE=$(head -c 2 "$LOCAL_ACCESS_POINT_PATH")
    LOCAL_ACCESS_POINT_NOTE="Found /boot/firmware/local_access_point."
elif [ -e "$LOCAL_ACCESS_POINT_PATH" ]; then
    LOCAL_ACCESS_POINT_STATUS=invalid
    LOCAL_ACCESS_POINT_FILES=$(basename "$LOCAL_ACCESS_POINT_PATH")
    LOCAL_ACCESS_POINT_NOTE="Found /boot/firmware/local_access_point, but it is not a regular file. Replace it with a file containing the two-letter country code."
elif [ "${#LOCAL_ACCESS_POINT_MATCHES[@]}" -gt 0 ]; then
    LOCAL_ACCESS_POINT_STATUS=wrong_filename
    for filepath in "${LOCAL_ACCESS_POINT_MATCHES[@]}"; do
        filename=$(basename "$filepath")
        if [ -z "$LOCAL_ACCESS_POINT_FILES" ]; then
            LOCAL_ACCESS_POINT_FILES="$filename"
        else
            LOCAL_ACCESS_POINT_FILES="$LOCAL_ACCESS_POINT_FILES,$filename"
        fi
    done
    LOCAL_ACCESS_POINT_NOTE="Found $LOCAL_ACCESS_POINT_FILES. Rename the intended file to exactly local_access_point. For example, local_access_point (2) will not be used."
fi

# Initialize an empty variable for network information
NETWORK_INFO="HOSTNAME=$(hostname)\nIP=$IP\nWIFI_SSID=$WIFI_SSID\nLOCAL_ACCESS_POINT_STATUS=$LOCAL_ACCESS_POINT_STATUS\nLOCAL_ACCESS_POINT_FILES=$LOCAL_ACCESS_POINT_FILES\nLOCAL_ACCESS_POINT_COUNTRY_CODE=$LOCAL_ACCESS_POINT_COUNTRY_CODE\nLOCAL_ACCESS_POINT_NOTE=$LOCAL_ACCESS_POINT_NOTE\n"

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

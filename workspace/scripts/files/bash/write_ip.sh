#!/bin/bash

set -x
set -e

export LC_ALL=C

# Get all IPv4 addresses
IP=$(hostname -I)

# Initialize an empty variable for network information
NETWORK_INFO="HOSTNAME=$(hostname)\nIP=$IP\n"

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

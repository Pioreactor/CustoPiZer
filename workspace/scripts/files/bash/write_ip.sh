#!/bin/bash

set -x
set -e

export LC_ALL=C

# Get the first IPv4 address
IP=$(hostname -I | awk '{print $1}')

# Check if the network interfaces exist and get their MAC addresses
if [ -d /sys/class/net/wlan0 ]; then
    WLAN_MAC=$(cat /sys/class/net/wlan0/address)
else
    WLAN_MAC="Not available"
fi

if [ -d /sys/class/net/eth0 ]; then
    ETH_MAC=$(cat /sys/class/net/eth0/address)
else
    ETH_MAC="Not available"
fi

# Write the information to a file in key-value format
echo "HOSTNAME=$(hostname)" >> /boot/firmware/network_info.txt
echo "IP=$IP" > /boot/firmware/network_info.txt
echo "WLAN_MAC=$WLAN_MAC" >> /boot/firmware/network_info.txt
echo "ETH_MAC=$ETH_MAC" >> /boot/firmware/network_info.txt

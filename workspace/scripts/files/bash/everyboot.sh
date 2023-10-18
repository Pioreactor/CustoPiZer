#!/bin/bash

# this runs at startup on every boot.

set -x
set -e

export LC_ALL=C


# Check if the file exists
if [ -f "/boot/firmware/config.ini" ]; then
    # If it exists, merge the configurations and remove the file
    crudini --merge /home/pioreactor/.pioreactor/config.ini < /boot/firmware/config.ini
    rm /boot/firmware/config.ini
fi

# Get the IPv4 address
IP=$(hostname -I | awk '{print $1}')

# Write the IP address to be accessible outside
echo "$IP" > /boot/firmware/ip
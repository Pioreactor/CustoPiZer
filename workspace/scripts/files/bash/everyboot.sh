#!/bin/bash

# this runs at startup on every boot.

set -x
set -e

export LC_ALL=C


# Check if the file exists
if [ -f "/boot/config.ini" ]; then
    # If it exists, merge the configurations and remove the file
    crudini --merge /home/pioreactor/.pioreactor/config.ini < /boot/config.ini
    rm /boot/config.ini
fi

# write ip address to /boot/ip
# Get the IPv4 address
IP=$(hostname -I | awk '{print $1}')

# Write the IP address to /boot/ip
echo "$IP" > /boot/ip
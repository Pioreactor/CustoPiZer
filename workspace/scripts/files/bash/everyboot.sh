#!/bin/bash

# this runs at startup on every boot.

set -x
set -e

export LC_ALL=C


# Check if the file exists
if [ -f "/boot/firmware/config.ini" ]; then
    # Merge the configurations and remove the extra file
    # if config.ini doesn't exist, this creates it.
    # so we need to chown, too.
    crudini --merge /home/pioreactor/.pioreactor/config.ini < /boot/firmware/config.ini
    chown pioreactor:pioreactor /home/pioreactor/.pioreactor/config.ini
    rm /boot/firmware/config.ini
fi

# Get the IPv4 address
IP=$(hostname -I)

# Check if the IP variable is empty
if [ -z "$IP" ]; then
    echo "Error: No IP address found." > /boot/firmware/ip
else
    # Write the IP address to be accessible outside
    echo "$IP" > /boot/firmware/ip
fi
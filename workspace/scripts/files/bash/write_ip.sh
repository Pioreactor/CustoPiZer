#!/bin/bash

set -x
set -e

export LC_ALL=C

# Get the IPv4 address
IP=$(hostname -I)

# Check if the IP variable is empty
if [ -z "$IP" ]; then
    echo "Error: No IP address found." > /boot/firmware/ip
else
    # Write the IP address to be accessible outside
    echo "$IP" > /boot/firmware/ip
fi
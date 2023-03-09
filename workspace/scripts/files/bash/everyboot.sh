#!/bin/bash

# this runs at startup on every boot.

set -x
set -e

export LC_ALL=C

# check for and config.ini in the /boot, and merge with current config.ini
# and the delete it.
if [ -e "/boot/config.ini" ]; then
    crudini --merge /home/pioreactor/.pioreactor/config.ini < /boot/config.ini
    rm /boot/config.ini
fi

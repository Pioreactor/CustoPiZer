#!/bin/bash

# this runs at startup on every boot.

set -x
set -e

export LC_ALL=C

# Check if config file exists (if not: likely a worker)
if [ ! -f "/home/pioreactor/.pioreactor/config.ini" ]; then
    # start the blue LED to signal to the user that it's working.
    python /usr/local/bin/led_control.py --static &

fi


# Check if a new config file exists
if [ -f "/boot/firmware/config.ini" ]; then
    # Merge the configurations and remove the extra file
    # if config.ini doesn't exist, this creates it.
    # so we need to chown, too.
    crudini --merge /home/pioreactor/.pioreactor/config.ini < /boot/firmware/config.ini
    chown pioreactor:www-data /home/pioreactor/.pioreactor/config.ini
    rm /boot/firmware/config.ini
fi

# force wifi on, even if CC isn't set
nmcli radio wifi on || :


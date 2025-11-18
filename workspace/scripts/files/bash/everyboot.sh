#!/bin/bash

# this runs at startup on every boot.

set -x
set -e

export LC_ALL=C

VENV_BIN="${PIO_VENV:-/opt/pioreactor/venv}/bin"
CRUDINI="$VENV_BIN/crudini"

PIOREACTOR_DATA_DIR=/home/pioreactor/.pioreactor

# Check if config file exists (if not: likely a worker)
if [ ! -f "$PIOREACTOR_DATA_DIR/config.ini" ]; then
    # start the blue LED to signal to the user that it's working.
    /opt/pioreactor/venv/bin/python /usr/local/bin/led_control.py --static &

fi


# Check if a new config file exists
if [ -f "/boot/firmware/config.ini" ]; then
    # Merge the configurations and remove the extra file
    # if config.ini doesn't exist, this creates it.
    # so we need to chown, too.
    "$CRUDINI" --merge "$PIOREACTOR_DATA_DIR/config.ini" < /boot/firmware/config.ini
    chown pioreactor:www-data "$PIOREACTOR_DATA_DIR/config.ini"
    rm /boot/firmware/config.ini
fi

# force wifi on, even if CC isn't set
nmcli radio wifi on || :

# Ensure cache directory ACLs grant group rw on new files (WAL/SHM)
if [ -d "/run/pioreactor/cache" ]; then
    setfacl -m g:www-data:rwX -m d:g:www-data:rwX /run/pioreactor/cache || :
fi

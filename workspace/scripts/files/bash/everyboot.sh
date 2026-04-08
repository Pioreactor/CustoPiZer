#!/bin/bash

# this runs at startup on every boot.

set -x
set -e

export LC_ALL=C

VENV_BIN="${PIO_VENV:-/opt/pioreactor/venv}/bin"
CRUDINI="$VENV_BIN/crudini"

DOT_PIOREACTOR=/home/pioreactor/.pioreactor

# Check if config file exists (if not: likely a worker)
if [ ! -f "$DOT_PIOREACTOR/config.ini" ]; then
    # start the blue LED to signal to the user that it's working.
    /opt/pioreactor/venv/bin/python /usr/local/bin/led_control.py --static &

fi


# Check if a new config file exists
if [ -f "/boot/firmware/config.ini" ]; then
    # Merge the configurations and remove the extra file
    # if unit_config.ini doesn't exist, this creates it.
    # so we need to chown, too.
    "$CRUDINI" --merge "$DOT_PIOREACTOR/unit_config.ini" < /boot/firmware/config.ini
    chown pioreactor:www-data "$DOT_PIOREACTOR/unit_config.ini"
    rm /boot/firmware/config.ini
fi

# force wifi on, even if CC isn't set
nmcli radio wifi on || :

# Ensure cache directory ACLs grant group rw on new files (WAL/SHM)
if [ -d "/run/pioreactor/cache" ]; then
    setfacl -m g:www-data:rwX -m d:g:www-data:rwX /run/pioreactor/cache || :
fi

RUN_EXPORTS_DIR=/run/pioreactor/exports
EXPORTS_DIR="${PIO_EXPORTS_DIR:-$RUN_EXPORTS_DIR}"

if [ "$EXPORTS_DIR" != "$RUN_EXPORTS_DIR" ]; then
    mkdir -p "$EXPORTS_DIR"
    chown pioreactor:www-data "$EXPORTS_DIR"
    chmod 2775 "$EXPORTS_DIR"

    if [ -e "$RUN_EXPORTS_DIR" ] || [ -L "$RUN_EXPORTS_DIR" ]; then
        rm -rf "$RUN_EXPORTS_DIR"
    fi

    ln -s "$EXPORTS_DIR" "$RUN_EXPORTS_DIR"
fi

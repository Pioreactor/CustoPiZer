#!/bin/bash

# this runs at startup on every boot.

set -x
set -e

export LC_ALL=C

VENV_BIN="${PIO_VENV:-/opt/pioreactor/venv}/bin"
CRUDINI="$VENV_BIN/crudini"

PIOREACTOR_DATA_DIR=/home/pioreactor/.pioreactor

ensure_dot_pioreactor_tree_group_is_www_data() {
    if [ -d "$PIOREACTOR_DATA_DIR" ]; then
        find "$PIOREACTOR_DATA_DIR" -mindepth 0 \( ! -user pioreactor -o ! -group www-data \) -exec chown -h pioreactor:www-data {} +
        find "$PIOREACTOR_DATA_DIR" -type d ! -perm -2000 -exec chmod g+s {} +
    fi
}

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
    "$CRUDINI" --merge /home/pioreactor/.pioreactor/config.ini < /boot/firmware/config.ini
    chown pioreactor:www-data /home/pioreactor/.pioreactor/config.ini
    rm /boot/firmware/config.ini
fi

# force wifi on, even if CC isn't set
nmcli radio wifi on || :

ensure_dot_pioreactor_tree_group_is_www_data

# Ensure cache directory ACLs grant group rw on new files (WAL/SHM)
if [ -d "/run/pioreactor/cache" ]; then
    if command -v setfacl >/dev/null 2>&1; then
        setfacl -m g:www-data:rwX -m d:g:www-data:rwX /run/pioreactor/cache || :
    else
        echo "setfacl not found; skipping ACL setup for /run/pioreactor/cache" >&2 || :
    fi
fi

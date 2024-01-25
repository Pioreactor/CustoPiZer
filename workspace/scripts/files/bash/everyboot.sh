#!/bin/bash

# this runs at startup on every boot.

set -x
set -e

export LC_ALL=C

# Check if config file exists (if not: likely a worker)
if [ ! -f "/home/pioreactor/.pioreactor/config.ini" ]; then
    # start the blue LED to signal to the user that it's working.
    python << EOF &
from gpiozero import LED
led = LED(23)
led.on()
while True:
    pass
EOF

fi


# Check if a new config file exists
if [ -f "/boot/firmware/config.ini" ]; then
    # Merge the configurations and remove the extra file
    # if config.ini doesn't exist, this creates it.
    # so we need to chown, too.
    crudini --merge /home/pioreactor/.pioreactor/config.ini < /boot/firmware/config.ini
    chown pioreactor:pioreactor /home/pioreactor/.pioreactor/config.ini
    rm /boot/firmware/config.ini
fi

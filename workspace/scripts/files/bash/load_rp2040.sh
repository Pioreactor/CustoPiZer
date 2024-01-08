#!/bin/bash

set -x
set -e

export LC_ALL=C


# Check if the Raspberry Pi version is 5
RPI_MODEL=$(grep -o "Raspberry Pi 5" /proc/cpuinfo)

# Choose the correct interface based on Raspberry Pi version
if [ "$RPI_MODEL" = "Raspberry Pi 5" ]; then
    INTERFACE=interface/raspberrypi-linuxgpiod-chip4.cfg
else
    INTERFACE=interface/raspberrypi-linuxgpiod-chip0.cfg
fi

openocd -f $INTERFACE -f target/rp2040.cfg -c "init" -c "reset halt" -c "load_image /usr/local/bin/main.elf" -c "resume 0x20000000" -c "exit" || true
#!/bin/bash

set -x

export LC_ALL=C

# Check if the Raspberry Pi version is 5
RPI_MODEL=$(grep -o "Raspberry Pi 5" /proc/cpuinfo)

# Choose the correct interface based on Raspberry Pi version
if [ "$RPI_MODEL" = "Raspberry Pi 5" ]; then
    INTERFACE=interface/raspberrypi-linuxgpiod-chip4.cfg
else
    INTERFACE=interface/raspberrypi-linuxgpiod-chip0.cfg
fi

# Retry loop for openocd command, mostly for Rpi Zero 1
RETRIES=3
DELAY=2
success=0

for ((i=1; i<=RETRIES; i++)); do
    if openocd -f "$INTERFACE" -f target/rp2040.cfg -c "init" -c "reset halt" -c "load_image /usr/local/bin/main.elf" -c "resume 0x20000000" -c "exit"; then
        success=1
        break
    fi

    if [ $i -lt $RETRIES ]; then
        sleep $DELAY
    fi
done

if [ $success -eq 1 ]; then
    exit 0
fi

echo "Failed to load RP2040 program via openocd after $RETRIES attempts" >&2
exit 1

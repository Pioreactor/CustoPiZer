#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

if [ "$WORKER" == "1" ]; then

    apt-get install -y libftdi-dev libusb-1.0-0-dev

    # move executable

    arch=$(dpkg --print-architecture)
    echo "$arch"
    if [ "$arch" = "arm64" ]; then
        cp /files/system/openocd/openocd64 /usr/local/bin/openocd
    else
        cp /files/system/openocd/openocd /usr/local/bin/openocd
    fi

    # move config
    mkdir /usr/local/share/openocd/
    cp -r /files/system/openocd/scripts   /usr/local/share/openocd/

    # pull latest .elf image
    wget -O /usr/local/bin/main.elf https://github.com/pioreactor/pico-build/releases/latest/download/main.elf


fi
#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap


# add everyboot and other utils
cp /files/system/systemd/everyboot.service /lib/systemd/system/
systemctl enable everyboot.service
cp /files/bash/everyboot.sh /usr/local/bin/everyboot.sh

cp /files/system/systemd/write_ip.service /lib/systemd/system/
systemctl enable write_ip.service
cp /files/bash/write_ip.sh /usr/local/bin/write_ip.sh
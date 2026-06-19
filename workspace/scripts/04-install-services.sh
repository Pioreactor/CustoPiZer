#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

# systemd: add long running pioreactor jobs

SYSTEMD_DIR=/etc/systemd/system/

sudo cp /files/system/systemd/pioreactor_startup_run@.service $SYSTEMD_DIR

# systemd: remove wifi powersave - helps with mdns discovery
sudo cp /files/system/systemd/wifi_powersave.service $SYSTEMD_DIR

# install optional hotspot service, both workers and leaders can do this.
sudo cp /files/system/systemd/bootfs_wifi.service $SYSTEMD_DIR
cp /files/bash/bootfs_wifi.sh /usr/local/bin/bootfs_wifi.sh
if [ "${PIOREACTOR_IMAGE_PROFILE:-standard}" != "zero_w_worker" ]; then
    sudo cp /files/system/systemd/local_access_point.service $SYSTEMD_DIR
    cp /files/bash/local_access_point.sh /usr/local/bin/local_access_point.sh
fi
cp /files/bash/start_pioreactor_huey.sh /usr/local/bin/start_pioreactor_huey.sh

# Keep time roughly monotonic on Raspberry Pis without RTC or internet.
cp /files/bash/fake-hwclock /usr/local/bin/fake-hwclock
chmod +x /usr/local/bin/fake-hwclock
sudo cp /files/system/systemd/fake-hwclock-load.service $SYSTEMD_DIR
sudo cp /files/system/systemd/fake-hwclock-save.service $SYSTEMD_DIR
sudo cp /files/system/systemd/fake-hwclock-save.timer $SYSTEMD_DIR


# Directories under /run are provisioned by tmpfiles.d; no separate cache-prep service needed

# systemd: UI web-workers
sudo cp /files/system/systemd/huey.service $SYSTEMD_DIR
sudo cp /files/system/systemd/pioreactor-web.target $SYSTEMD_DIR

# systemd: log failures and a python blink code that is nearly independent from Pioreactor code.
sudo cp /files/system/systemd/log-failure@.service $SYSTEMD_DIR
sudo cp /files/system/scripts/led_control.py /usr/local/bin/led_control.py


if [ "$LEADER" == "1" ]; then
    # systemd: alias hostname to pioreactor.local
    sudo cp /files/system/systemd/avahi_aliases.service $SYSTEMD_DIR
    sudo systemctl enable avahi_aliases.service
    cp /files/bash/avahi_aliases.sh /usr/local/bin/avahi_aliases.sh
fi

if [ "$WORKER" == "1" ]; then
    # add avahi services
    sudo cp /files/system/avahi/pioreactor_worker.service /etc/avahi/services/
fi

# systemd: add rp2040 chip load unit and helper (available on all images; worker target will control enablement)
cp /files/bash/load_rp2040.sh /usr/local/bin/load_rp2040.sh
sudo cp /files/system/systemd/load_rp2040.service $SYSTEMD_DIR

# systemd: copy timers (not enabled here)
sudo cp /files/system/systemd/network-info.service $SYSTEMD_DIR
sudo cp /files/system/systemd/network-info.timer $SYSTEMD_DIR
sudo cp /files/system/systemd/backup-database.service $SYSTEMD_DIR
sudo cp /files/system/systemd/backup-database.timer $SYSTEMD_DIR
sudo cp /files/system/systemd/ui-exports-cleanup.service $SYSTEMD_DIR
sudo cp /files/system/systemd/ui-exports-cleanup.timer $SYSTEMD_DIR

# Install target units
sudo cp /files/system/systemd/pioreactor.target $SYSTEMD_DIR
sudo cp /files/system/systemd/pioreactor-leader.target $SYSTEMD_DIR
sudo cp /files/system/systemd/pioreactor-worker.target $SYSTEMD_DIR

if [ "${PIOREACTOR_IMAGE_PROFILE:-standard}" = "zero_w_worker" ]; then
    # Keep the boot-time write_ip.service, but avoid waking a Zero W every five minutes.
    # Keep bootfs_wifi.service for wifi.ini bootstrap, but disable local AP support.
    sudo sed -i 's/ local_access_point.service//; s/ network-info.timer//' "$SYSTEMD_DIR/pioreactor.target"
    sudo sed -i 's/ local_access_point.service//' "$SYSTEMD_DIR/pioreactor_startup_run@.service"
fi

# Install tmpfiles.d rules to provision /run/pioreactor paths at boot
sudo install -D -m 0644 /files/system/tmpfiles.d/pioreactor.conf /etc/tmpfiles.d/pioreactor.conf

# Enable only the appropriate targets
sudo systemctl enable fake-hwclock-load.service
sudo systemctl enable fake-hwclock-save.timer
sudo systemctl enable pioreactor.target
if [ "$LEADER" == "1" ]; then
    sudo systemctl enable pioreactor-leader.target
fi
if [ "$WORKER" == "1" ]; then
    sudo systemctl enable pioreactor-worker.target
fi

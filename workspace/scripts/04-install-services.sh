#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

# systemd: add long running pioreactor jobs

SYSTEMD_DIR=/lib/systemd/system/

sudo cp /files/system/systemd/pioreactor_startup_run@.service $SYSTEMD_DIR
sudo systemctl enable pioreactor_startup_run@monitor.service

sudo cp /files/system/systemd/pioreactor_startup_run@.service $SYSTEMD_DIR
sudo systemctl enable pioreactor_startup_run@monitor.service

# systemd: remove wifi powersave - helps with mdns discovery
sudo cp /files/system/systemd/wifi_powersave.service $SYSTEMD_DIR
sudo systemctl enable wifi_powersave.service


if [ "$LEADER" == "1" ]; then
    sudo cp /files/system/systemd/ngrok.service $SYSTEMD_DIR

    # systemd: web UI stuff
    sudo cp /files/system/systemd/huey.service $SYSTEMD_DIR
    sudo systemctl enable huey.service

    sudo cp /files/system/systemd/create_diskcache.service $SYSTEMD_DIR
    sudo systemctl enable create_diskcache.service
    cp /files/bash/create_diskcache.sh /usr/local/bin/create_diskcache.sh

    # systemd: add long running pioreactor jobs
    sudo systemctl enable pioreactor_startup_run@watchdog.service
    sudo systemctl enable pioreactor_startup_run@mqtt_to_db_streaming.service

    # systemd: alias hostname to pioreactor.local
    sudo cp /files/system/systemd/avahi_aliases.service $SYSTEMD_DIR
    sudo systemctl enable avahi_aliases.service
    cp /files/bash/avahi_aliases.sh /usr/local/bin/avahi_aliases.sh


    # add avahi services
    sudo cp /files/system/avahi/mqtt.service /etc/avahi/services/
    sudo cp /files/system/avahi/pioreactorui.service /etc/avahi/services/

    # install hotspot service
    sudo cp /files/system/systemd/local_access_point.service $SYSTEMD_DIR
    cp /files/bash/local_access_point.sh /usr/local/bin/local_access_point.sh
    sudo systemctl enable local_access_point.service
fi


if [ "$WORKER" == "1" ]; then
    # add avahi services
    sudo cp /files/system/avahi/pioreactor_worker.service /etc/avahi/services/

    # systemd: add rp2040 chip load
    cp /files/bash/load_rp2040.sh /usr/local/bin/load_rp2040.sh
    sudo cp /files/system/systemd/load_rp2040.service $SYSTEMD_DIR
    sudo systemctl enable load_rp2040.service
fi




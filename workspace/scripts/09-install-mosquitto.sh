#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap


if [ "$LEADER" == "1" ]; then
    sudo apt-get install -y mosquitto mosquitto-clients
    sudo systemctl enable mosquitto.service

    # create auth file
    echo "pioreactor:raspberry" > /etc/mosquitto/pw.txt
    # hash password
    mosquitto_passwd -U /etc/mosquitto/pw.txt

    grep -qxF 'autosave_interval 1500'  /etc/mosquitto/mosquitto.conf || echo "autosave_interval 1500" | sudo tee /etc/mosquitto/mosquitto.conf -a
    grep -qxF 'listener 1883'          /etc/mosquitto/mosquitto.conf || echo "listener 1883"         | sudo tee /etc/mosquitto/mosquitto.conf -a
    grep -qxF 'protocol mqtt'          /etc/mosquitto/mosquitto.conf || echo "protocol mqtt"         | sudo tee /etc/mosquitto/mosquitto.conf -a
    grep -qxF 'listener 9001'          /etc/mosquitto/mosquitto.conf || echo "listener 9001"         | sudo tee /etc/mosquitto/mosquitto.conf -a
    grep -qxF 'protocol websockets'    /etc/mosquitto/mosquitto.conf || echo "protocol websockets"   | sudo tee /etc/mosquitto/mosquitto.conf -a
    grep -qxF 'allow_anonymous false'  /etc/mosquitto/mosquitto.conf || echo "allow_anonymous false" | sudo tee /etc/mosquitto/mosquitto.conf -a
    grep -qxF 'password_file /etc/mosquitto/pw.txt'  /etc/mosquitto/mosquitto.conf || echo "password_file /etc/mosquitto/pw.txt" | sudo tee /etc/mosquitto/mosquitto.conf -a

fi
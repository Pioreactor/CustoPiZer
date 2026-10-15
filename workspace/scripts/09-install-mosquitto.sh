#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap


# mosquitto is installed and configured on all images, but only leaders run the broker.
sudo apt-get install -y mosquitto mosquitto-clients

# create auth file
echo "pioreactor:raspberry" > /etc/mosquitto/pw.txt
# hash password
mosquitto_passwd -U /etc/mosquitto/pw.txt
sudo chown mosquitto:mosquitto /etc/mosquitto/pw.txt
sudo chmod 0700 /etc/mosquitto/pw.txt


# Shared application defaults; image provisioning still controls broker activation.
while IFS= read -r setting; do
    grep -qxF "$setting" /etc/mosquitto/mosquitto.conf || printf '%s\n' "$setting" >> /etc/mosquitto/mosquitto.conf
done < /files/system/mosquitto/pioreactor.conf


if [ "$LEADER" != "1" ]; then
    # the Debian package enables mosquitto.service on install; workers don't run a broker.
    sudo systemctl disable mosquitto.service
fi

#!/bin/bash

set -x
set -e

export LC_ALL=C


WPA_FILE=/etc/wpa_supplicant/wpa_supplicant.conf
RASPAP_TRIGGER_ON_PIN=20
RASPAP_TRIGGER_OFF_PIN=26


# first, always update the SSID and passphrase to what's in the config.ini
sed -i "s/ssid=.*/ssid=$(crudini --get /home/pioreactor/.pioreactor/config.ini local_access_point ssid)/" /etc/hostapd/hostapd.conf
sed -i "s/wpa_passphrase=.*/wpa_passphrase=$(crudini --get /home/pioreactor/.pioreactor/config.ini local_access_point passphrase)/" /etc/hostapd/hostapd.conf


# If GPIO 26 is pulled HIGH, then stop and disable the RaspAP access point, but only if there are WIFI credentials to use
if [[ (-f $WPA_FILE) && $(raspi-gpio get $RASPAP_TRIGGER_OFF_PIN | cut -d " " -f 3) == "level=1" ]]; then
    # only execute if is enabled
    if [[ $(systemctl is-enabled hostapd.service) == "enabled" ]]; then
        # this order seems to be important.
        systemctl disable raspapd.service
        systemctl disable hostapd.service
        cp /etc/raspap/backups/dhcpcd.conf.original /etc/dhcpcd.conf
        systemctl daemon-reload
        systemctl restart wpa_supplicant.service
        systemctl restart dhcpcd.service
        pio log -m "Turning off hotspot and rebooting" -n raspap
        sudo systemctl reboot
    fi
fi

# If there are no WIFI credentials, or GPIO 20 is pulled HIGH, then enable and start the RaspAP access point
if [[ (! -f $WPA_FILE) || $(raspi-gpio get $RASPAP_TRIGGER_ON_PIN | cut -d " " -f 3) == "level=1" ]]; then
    # only execute if not enabled
    if [[ $(systemctl is-enabled hostapd.service) == "disabled" ]]; then
        cp /etc/raspap/backups/dhcpcd.conf.raspap /etc/dhcpcd.conf
        systemctl daemon-reload
        systemctl restart dhcpcd.service
        systemctl enable raspapd.service
        systemctl enable hostapd.service
        pio log -m "Turning on hotspot and rebooting" -n raspap
        sudo systemctl reboot
    fi
fi
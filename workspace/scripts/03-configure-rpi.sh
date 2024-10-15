#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

if [ "$WORKER" == "1" ]; then

    ######################################################################
    # Optimize power consumption of Rpi - mostly turn off peripherals
    ######################################################################

    # disable audio, camera autodetects
    echo "dtparam=audio=off"    | sudo tee -a /boot/config.txt
    echo "camera_auto_detect=0" | sudo tee -a /boot/config.txt

    # disable USB. This fails for the RPi Zero and A models, hence the starting "-"" to ignore error
    # TODO: -echo '1-1' |sudo tee /sys/bus/usb/drivers/usb/unbind

    # remove activelow LED
    # TODO this doesn't work for RPi Zero, https://mlagerberg.gitbooks.io/raspberry-pi/content/5.2-leds.html
    echo "dtparam=act_led_trigger=none" | sudo tee -a /boot/config.txt
    echo "dtparam=act_led_activelow=off" | sudo tee -a /boot/config.txt

    #####################################################################
    #####################################################################

    # add hardware pwm
    echo "dtoverlay=pwm-2chan,pin=12,func=4,pin2=13,func2=4" | sudo tee -a /boot/config.txt

    if [ "$HEADLESS" == "1" ]; then

        # assign minimal memory to GPU
        echo "gpu_mem=16"            | sudo tee /boot/config.txt -a
        echo "display_auto_detect=0" | sudo tee -a /boot/config.txt
        # disable HDMI:

        #  https://www.cnx-software.com/2021/12/09/raspberry-pi-zero-2-w-power-consumption/
        sed -i '/dtoverlay=vc4-kms-v3d/d' /boot/config.txt
        echo "dtoverlay=vc4-kms-v3d,nohdmi" | sudo tee -a /boot/config.txt
        echo "max_framebuffers=1" | sudo tee -a /boot/config.txt
        echo "disable_fw_kms_setup=1" | sudo tee -a /boot/config.txt
        echo "disable_overscan=1" | sudo tee -a /boot/config.txt
        echo "enable_tvout=0" | sudo tee -a /boot/config.txt
        echo "hdmi_blanking=2" | sudo tee -a /boot/config.txt
        echo "hdmi_ignore_edid=0xa5000080" | sudo tee -a /boot/config.txt
        echo "hdmi_ignore_cec_init=1" | sudo tee -a /boot/config.txt
        echo "hdmi_ignore_cec=1" | sudo tee -a /boot/config.txt

        # disable POE, LDC probing
        echo "disable_poe_fan=1" | sudo tee -a /boot/config.txt
        echo "ignore_lcd=1" | sudo tee -a /boot/config.txt
        echo "disable_touchscreen=1" | sudo tee -a /boot/config.txt
        echo "disable_fw_kms_setup=1" | sudo tee -a /boot/config.txt

        # skip display and camera sensing
        echo "camera_auto_detect=0" | sudo tee -a /boot/config.txt
        echo "display_auto_detect=0" | sudo tee -a /boot/config.txt



        # disable bluetooth
        sudo systemctl disable hciuart
        echo "dtoverlay=disable-bt" | sudo tee -a /boot/config.txt
        sudo systemctl disable bluetooth.service
        sudo apt remove --purge bluez -y
        sudo systemctl disable keyboard-setup.service
    fi

fi

# the below will remove swap, which should help extend the life of SD cards:
# https://raspberrypi.stackexchange.com/questions/169/how-can-i-extend-the-life-of-my-sd-card
sudo apt-get remove dphys-swapfile -y

# remove some redundant programs
sudo apt-get remove system-config-printer -y

# remove depend. of uninstalled programs.
sudo apt-get autoremove -y

# put /tmp into memory, as we write to it a lot.
echo "tmpfs /tmp tmpfs defaults,noatime 0 0" | sudo tee -a /etc/fstab

# add environment variable for TMPDIR
echo "TMPDIR=/tmp/" | sudo tee -a /etc/environment
# add env variable for lgpio working dir
echo "LG_WD=/tmp" | sudo tee -a /etc/environment # no trailing slash!


### faster boot

# from http://himeshp.blogspot.com/2018/08/fast-boot-with-raspberry-pi.html
echo "disable_splash=1" | sudo tee -a /boot/config.txt
echo "initial_turbo=30" | sudo tee -a /boot/config.txt
echo "force_turbo=1" | sudo tee -a /boot/config.txt


# disable services that slow down boot
sudo systemctl disable raspi-config.service
sudo systemctl disable triggerhappy.service
sudo systemctl disable apt-daily.service
sudo systemctl disable apt-daily-upgrade.service
sudo systemctl disable alsa-restore.service
sudo systemctl disable alsa-state.service
sudo systemctl disable userconfig.service
sudo systemctl disable rpi-display-backlight.service
sudo systemctl disable rpi-eeprom-update.service

sudo systemctl mask apt-daily-upgrade
sudo systemctl mask apt-daily
sudo systemctl disable apt-daily-upgrade.timer
sudo systemctl disable apt-daily.timer


# turn off ipv6
file="/etc/sysctl.d/90-disable-ipv6.conf"

lines="net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1"

echo "$lines" | sudo tee "$file" > /dev/null

# remove man page refreshes
sudo rm /var/lib/man-db/auto-update


# reduce the size that journalctl uses. TODO: test this
sudo crudini --set /etc/systemd/journald.conf Journal SystemMaxUse 20M

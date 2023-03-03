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

    # assign minimal memory to GPU
    echo "gpu_mem=16"            | sudo tee /boot/config.txt -a

    # disable bluetooth, audio, camera and display autodetects
    sudo systemctl disable hciuart
    echo "dtoverlay=disable-bt" | sudo tee -a /boot/config.txt
    echo "dtparam=audio=off"    | sudo tee -a /boot/config.txt
    echo "camera_auto_detect=0" | sudo tee -a /boot/config.txt
    echo "display_auto_detect=0" | sudo tee -a /boot/config.txt

    # disable USB. This fails for the RPi Zero and A models, hence the starting "-"" to ignore error
    # TODO: -echo '1-1' |sudo tee /sys/bus/usb/drivers/usb/unbind

    # disable HDMI:
    #  https://www.cnx-software.com/2021/12/09/raspberry-pi-zero-2-w-power-consumption/
    sed -i '/dtoverlay=vc4-kms-v3d/d' /boot/config.txt
    echo "hdmi_blanking=2" | sudo tee -a /boot/config.txt
    # https://forums.raspberrypi.com/viewtopic.php?p=2063523
    echo "dtoverlay=vc4-kms-v3d,nohdmi" | sudo tee -a /boot/config.txt

    # remove activelow LED
    # TODO this doesn't work for RPi Zero, https://mlagerberg.gitbooks.io/raspberry-pi/content/5.2-leds.html
    echo "dtparam=act_led_trigger=none" | sudo tee -a /boot/config.txt
    echo "dtparam=act_led_activelow=off" | sudo tee -a /boot/config.txt

    #####################################################################
    #####################################################################

    # add hardware pwm
    echo "dtoverlay=pwm-2chan,pin=12,func=4,pin2=13,func2=4" | sudo tee -a /boot/config.txt
fi

# the below will remove swap, which should help extend the life of SD cards:
# https://raspberrypi.stackexchange.com/questions/169/how-can-i-extend-the-life-of-my-sd-card
sudo apt-get remove dphys-swapfile -y
sudo apt-get autoremove -y

# put /tmp into memory, as we write to it a lot.
echo "tmpfs /tmp tmpfs defaults,noatime 0 0" | sudo tee -a /etc/fstab

# add environment variable for TMPDIR
echo "TMPDIR=/tmp/" | sudo tee -a /etc/environment


### faster boot

# from http://himeshp.blogspot.com/2018/08/fast-boot-with-raspberry-pi.html
echo "boot_delay=0.5" | sudo tee -a /boot/config.txt
echo "disable_splash=1" | sudo tee -a /boot/config.txt

# from https://raspberrypi.stackexchange.com/questions/78099/how-can-i-lower-my-boot-time-more
# this needs more testing. The imager edits this too, post flashing.
# sed -i 's/tty1/tty3/g' /boot/cmdline.txt
# echo -n ' loglevel=3 quiet logo.nologo' | sudo tee -a /boot/cmdline.txt


# disable services that slow down boot
sudo systemctl disable raspi-config.service
sudo systemctl disable triggerhappy.service
sudo systemctl disable keyboard-setup.service
sudo systemctl disable apt-daily-upgrade.service
sudo systemctl disable alsa-restore.service
sudo systemctl disable bluetooth.service
sudo systemctl disable hciuart.service
sudo systemctl disable alsa-state.service
#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

USERNAME=pioreactor
PASS=raspberry

adduser --gecos "" --disabled-password $USERNAME
chpasswd <<<"$USERNAME:$PASS"
usermod -a -G sudo $USERNAME
usermod -a -G gpio $USERNAME
usermod -a -G spi $USERNAME
usermod -a -G i2c $USERNAME
usermod -a -G www-data $USERNAME
usermod -a -G video $USERNAME
# Note that the following also occurs in firstboot.sh that is created by the RPi imager:
# We should move this into our image eventually...

chmod 755 /home/$USERNAME

# usermod -l "pioreactor" "$FIRSTUSER"
# usermod -m -d "/home/pioreactor" "pioreactor"
# groupmod -n "pioreactor" "$FIRSTUSER"
# if grep -q "^autologin-user=" /etc/lightdm/lightdm.conf ; then
#    sed /etc/lightdm/lightdm.conf -i -e "s/^autologin-user=.*/autologin-user=pioreactor/"
# fi
# if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
#    sed /etc/systemd/system/getty@tty1.service.d/autologin.conf -i -e "s/$FIRSTUSER/pioreactor/"
# fi
# if [ -f /etc/sudoers.d/010_pi-nopasswd ]; then
#    sed -i "s/^$FIRSTUSER /pioreactor /" /etc/sudoers.d/010_pi-nopasswd
# fi


# change default password for the pi user, as per RPi Foundations recommendation. Not sure if this works...
chpasswd <<<"pi:notaraspberry"
rm /etc/ssh/sshd_config.d/rename_user.conf
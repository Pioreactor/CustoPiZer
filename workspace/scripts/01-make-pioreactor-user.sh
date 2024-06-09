#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

SSH_DIR=/home/pioreactor/.ssh

adduser --gecos "" --disabled-password pioreactor
chpasswd <<<"pioreactor:raspberry"
usermod -a -G sudo pioreactor
usermod -a -G gpio pioreactor
usermod -a -G spi pioreactor
usermod -a -G i2c pioreactor
usermod -a -G www-data pioreactor
usermod -a -G video pioreactor
usermod -a -G dialout pioreactor
usermod -a -G systemd-journal pioreactor
usermod -a -G avahi pioreactor
usermod -a -G netdev pioreactor

chmod 755 /home/pioreactor

# make sure pioreactor doesn't require a password when running as sudo
echo 'pioreactor ALL=(ALL) NOPASSWD: ALL' | sudo EDITOR='tee -a' visudo -f /etc/sudoers.d/010_pioreactor-nopasswd

# change default password for the pi user, as per RPi Foundations recommendation. Not sure if this works...
chpasswd <<<"pi:notaraspberry"
rm /etc/ssh/sshd_config.d/rename_user.conf

##### set some SSH stuff, populated on firstboot.
sudo -u pioreactor rm -rf $SSH_DIR # remove if already exists.

sudo -u pioreactor mkdir -p $SSH_DIR
sudo cp /files/ssh_config $SSH_DIR/config
sudo chown pioreactor:pioreactor $SSH_DIR/config
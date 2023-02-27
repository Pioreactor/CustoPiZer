#!/bin/bash

set -x
set -e

export LC_ALL=C

USERNAME=pioreactor
PIO_DIR=/home/$USERNAME/.pioreactor
SSH_DIR=/home/$USERNAME/.ssh
DB_LOC=$(crudini --get $PIO_DIR/config.ini storage database)

# clean up if this needs to run again.
sudo -u $USERNAME rm -f $SSH_DIR/{authorized_keys,known_hosts,id_rsa,id_rsa.pub}

sudo -u $USERNAME touch $SSH_DIR/authorized_keys
sudo -u $USERNAME touch $SSH_DIR/known_hosts

sudo -u $USERNAME ssh-keygen -q -t rsa -N '' -f $SSH_DIR/id_rsa
sudo -u $USERNAME cat $SSH_DIR/id_rsa.pub > $SSH_DIR/authorized_keys
sudo -u $USERNAME ssh-keyscan "$(hostname)".local >> $SSH_DIR/known_hosts

crudini --set $PIO_DIR/config.ini cluster.topology leader_hostname "$(hostname)"
crudini --set $PIO_DIR/config.ini cluster.topology leader_address "$(hostname)".local

sqlite3 $DB_LOC "INSERT OR IGNORE INTO experiments (created_at, experiment, description) VALUES (STRFTIME('%Y-%m-%dT%H:%M:%f000Z', 'NOW'), 'Demo experiment', 'This is a demo experiment. Feel free to click around. When you are ready, click the [New experiment] above.');"
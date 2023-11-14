#!/bin/bash

set -x
set -e

export LC_ALL=C

USERNAME=pioreactor
PIO_DIR=/home/$USERNAME/.pioreactor
SSH_DIR=/home/$USERNAME/.ssh
DB_LOC=$(crudini --get $PIO_DIR/config.ini storage database)
HOSTNAME=$(hostname)

# clean up if this needs to run again.
sudo -u $USERNAME rm -f $SSH_DIR/{authorized_keys,known_hosts,id_rsa,id_rsa.pub}

sudo -u $USERNAME touch $SSH_DIR/authorized_keys
sudo -u $USERNAME touch $SSH_DIR/known_hosts

sudo -u $USERNAME ssh-keygen -q -t rsa -N '' -f $SSH_DIR/id_rsa
sudo -u $USERNAME cat $SSH_DIR/id_rsa.pub > $SSH_DIR/authorized_keys
sudo -u $USERNAME ssh-keyscan "$HOSTNAME".local >> $SSH_DIR/known_hosts

crudini --ini-options=nospace --set  $PIO_DIR/config.ini cluster.topology leader_hostname "$HOSTNAME" \
                              --set  $PIO_DIR/config.ini cluster.topology leader_address "$HOSTNAME".local \
                              --set  $PIO_DIR/config.ini cluster.inventory "$HOSTNAME" 1

sqlite3 $DB_LOC "INSERT OR IGNORE INTO experiments (created_at, experiment, description) VALUES (STRFTIME('%Y-%m-%dT%H:%M:%f000Z', 'NOW'), 'Demo experiment', 'This is a demo experiment. Feel free to click around. When you are ready, click the [New experiment] above.');"


sudo -u $USERNAME touch $PIO_DIR/config_"$HOSTNAME".ini # set with the correct read/write permissions
printf '# Any settings here are specific to %s, and override the settings in config.ini\n\n' "$HOSTNAME" >> $PIO_DIR/config_"$HOSTNAME".ini
cp "$PIO_DIR/config_$HOSTNAME.ini" "$PIO_DIR/unit_config.ini"
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

sudo -u $USERNAME crudini --ini-options=nospace --set $PIO_DIR/config.ini cluster.topology leader_hostname "$HOSTNAME"
sudo -u $USERNAME crudini --ini-options=nospace --set $PIO_DIR/config.ini cluster.topology leader_address "$HOSTNAME".local
sudo -u $USERNAME crudini --ini-options=nospace --set $PIO_DIR/config.ini mqtt broker_address "$HOSTNAME".local

sqlite3 "$DB_LOC" "INSERT OR IGNORE INTO experiments (created_at, experiment, description) VALUES (STRFTIME('%Y-%m-%dT%H:%M:%f000Z', 'NOW'), 'Demo experiment', 'This is a demo experiment. Feel free to click around. When you are ready, create a new experiment in the dropdown to the left.');"
sqlite3 "$DB_LOC" "INSERT OR IGNORE INTO workers (pioreactor_unit, added_at, is_active) VALUES ('$HOSTNAME', STRFTIME('%Y-%m-%dT%H:%M:%f000Z', 'NOW'), 1);"
sqlite3 "$DB_LOC" "INSERT OR IGNORE INTO experiment_worker_assignments (pioreactor_unit, experiment, assigned_at) VALUES ('$HOSTNAME', 'Demo experiment', STRFTIME('%Y-%m-%dT%H:%M:%f000Z', 'NOW'));"

# create our config file.
sudo -u $USERNAME touch $PIO_DIR/config_"$HOSTNAME".ini # set with the correct read/write permissions
printf '# Any settings here are specific to %s, the leader, and override the settings in config.ini\n\n' "$HOSTNAME" >> $PIO_DIR/config_"$HOSTNAME".ini

sudo -u $USERNAME crudini --ini-options=nospace --set $PIO_DIR/config_"$HOSTNAME".ini cluster.topology leader_address 127.0.0.1
sudo -u $USERNAME crudini --ini-options=nospace --set $PIO_DIR/config_"$HOSTNAME".ini mqtt broker_address 127.0.0.1
sudo -u $USERNAME crudini --ini-options=nospace --set $PIO_DIR/config_"$HOSTNAME".ini pioreactor model pioreactor_20ml
sudo -u $USERNAME crudini --ini-options=nospace --set $PIO_DIR/config_"$HOSTNAME".ini pioreactor version 1.1

cp -a "$PIO_DIR/config_$HOSTNAME.ini" "$PIO_DIR/unit_config.ini"
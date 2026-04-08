#!/bin/bash

set -x
set -e

export LC_ALL=C

PIO_VENV=/opt/pioreactor/venv
USERNAME=pioreactor
DOT_PIOREACTOR=/home/$USERNAME/.pioreactor
SSH_DIR=/home/$USERNAME/.ssh
DB_LOC=$("$PIO_VENV/bin/crudini" --get $DOT_PIOREACTOR/config.ini storage database)
HOSTNAME=$(hostname)

ensure_dot_pioreactor_tree_group_is_www_data() {
    if [ -d "$DOT_PIOREACTOR" ]; then
        find "$DOT_PIOREACTOR" -mindepth 0 \( ! -user "$USERNAME" -o ! -group www-data \) -exec chown -h "$USERNAME":www-data {} +
        chmod g+w "$DOT_PIOREACTOR"
        find "$DOT_PIOREACTOR" -mindepth 1 \( -type d -o -type f \) -exec chmod g+w {} +
        find "$DOT_PIOREACTOR" -type d ! -perm -2000 -exec chmod g+s {} +
    fi
}
# clean up if this needs to run again.
sudo -u $USERNAME rm -f $SSH_DIR/{authorized_keys,known_hosts,id_rsa,id_rsa.pub}

sudo -u $USERNAME touch $SSH_DIR/authorized_keys
sudo -u $USERNAME touch $SSH_DIR/known_hosts

sudo -u $USERNAME ssh-keygen -q -t rsa -N '' -f $SSH_DIR/id_rsa
sudo -u $USERNAME cat $SSH_DIR/id_rsa.pub > $SSH_DIR/authorized_keys
sudo -u $USERNAME ssh-keyscan "$HOSTNAME".local >> $SSH_DIR/known_hosts 2>/dev/null || true
sudo -u $USERNAME ssh-keyscan "$HOSTNAME" >> $SSH_DIR/known_hosts 2>/dev/null || true

sudo -u $USERNAME "$PIO_VENV/bin/crudini" --ini-options=nospace --set $DOT_PIOREACTOR/config.ini cluster.topology leader_hostname "$HOSTNAME"
sudo -u $USERNAME "$PIO_VENV/bin/crudini" --ini-options=nospace --set $DOT_PIOREACTOR/config.ini cluster.topology leader_address "$HOSTNAME".local
sudo -u $USERNAME "$PIO_VENV/bin/crudini" --ini-options=nospace --set $DOT_PIOREACTOR/config.ini mqtt broker_address "$HOSTNAME".local

sqlite3 $DB_LOC "INSERT OR IGNORE INTO experiments (created_at, experiment, description) VALUES (STRFTIME('%Y-%m-%dT%H:%M:%fZ', 'NOW'), 'Demo experiment', 'This is a demo experiment. Feel free to click around.  When you are ready, create a new experiment in the dropdown to the left.');"


# create the leader's local unit-specific config file.
sudo -u $USERNAME touch "$DOT_PIOREACTOR/unit_config.ini" # set with the correct read/write permissions
printf '# Any settings here are specific to %s, the leader, and override the settings in config.ini\n\n' "$HOSTNAME" >> "$DOT_PIOREACTOR/unit_config.ini"

sudo -u $USERNAME "$PIO_VENV/bin/crudini" --ini-options=nospace --set "$DOT_PIOREACTOR/unit_config.ini" cluster.topology leader_address 127.0.0.1
sudo -u $USERNAME "$PIO_VENV/bin/crudini" --ini-options=nospace --set "$DOT_PIOREACTOR/unit_config.ini" mqtt broker_address 127.0.0.1

ensure_dot_pioreactor_tree_group_is_www_data

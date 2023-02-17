#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

USERNAME=pioreactor
STORAGE=/home/$USERNAME/.pioreactor/storage

# install sqlite3 on all machines, as I expect I'll use it on workers one day.
sudo apt-get install -y sqlite3



if [ "$LEADER" == "1" ]; then

    DB_LOC=$STORAGE/pioreactor.sqlite


    sudo -u $USERNAME touch $DB_LOC
    sudo -u $USERNAME touch $DB_LOC-shm
    sudo -u $USERNAME touch $DB_LOC-wal
    sudo chmod 666 $DB_LOC
    sudo chmod 666 $DB_LOC-shm
    sudo chmod 666 $DB_LOC-wal
    sudo chmod 777 $STORAGE
    sqlite3 $DB_LOC < /files/sql/sqlite_configuration.sql
    sqlite3 $DB_LOC < /files/sql/create_tables.sql
    sqlite3 $DB_LOC < /files/sql/create_triggers.sql

fi



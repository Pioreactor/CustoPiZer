#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

USERNAME=pioreactor
STORAGE_DIR=/home/$USERNAME/.pioreactor/storage

sudo apt-get install -y sqlite3


if [ "$LEADER" == "1" ]; then

    DB=$STORAGE_DIR/pioreactor.sqlite

    sqlite3 $DB < /files/sql/sqlite_configuration.sql
    sqlite3 $DB < /files/sql/create_tables.sql
    sqlite3 $DB < /files/sql/create_triggers.sql

fi


DB=$STORAGE_DIR/local_persistent_pioreactor_metadata.sqlite
sqlite3 $DB < /files/sql/sqlite_configuration.sql



chmod -R 770 $STORAGE_DIR
chown -R $USERNAME:www-data $STORAGE_DIR
chmod g+s $STORAGE_DIR


#!/bin/bash

set -x
set -e

export LC_ALL=C

DIR=/tmp/pioreactor_cache

mkdir -p $DIR


sqlite3 $DIR/local_intermittent_pioreactor_metadata.sqlite "PRAGMA journal_mode=WAL;"
sqlite3 $DIR/huey.db "PRAGMA journal_mode=WAL;"

chmod -R 770 $DIR/
chown -R pioreactor:www-data $DIR/
chmod g+s $DIR

echo "done!"
#!/bin/bash

set -x
set -e

export LC_ALL=C

mkdir /tmp/pioreactorui_cache 
touch /tmp/pioreactorui_cache/cache.db
touch /tmp/pioreactorui_cache/cache.db-shm
touch /tmp/pioreactorui_cache/cache.db-wal
chmod -R 770 /tmp/pioreactorui_cache/
chown -R pioreactor:www-data /tmp/pioreactorui_cache

(cd /var/www/pioreactorui/; huey_consumer tasks.huey -s 60 -n -b 1.0 -w 2 -f -C)
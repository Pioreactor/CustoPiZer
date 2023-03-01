#!/bin/bash

set -x
set -e

export LC_ALL=C

mkdir -p /tmp/pioreactorui_cache
touch /tmp/pioreactorui_cache/cache.db
touch /tmp/pioreactorui_cache/cache.db-shm
touch /tmp/pioreactorui_cache/cache.db-wal
chmod -R 770 /tmp/pioreactorui_cache/
chown -R pioreactor:www-data /tmp/pioreactorui_cache/
chmod g+s /tmp/pioreactorui_cache
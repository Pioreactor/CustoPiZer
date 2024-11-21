#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

USERNAME=pioreactor


if [ "$LEADER" == "1" ]; then
    crontab -u "$USERNAME" /files/cron/pioreactor.cron
fi

crontab -u root /files/cron/root.cron
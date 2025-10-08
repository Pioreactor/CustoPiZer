#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

# Cron has been replaced by systemd timers in Phase 1.
# Intentionally skipping crontab installation to avoid duplicate scheduling.
echo "Skipping crontab installation: using systemd timers instead." >&2

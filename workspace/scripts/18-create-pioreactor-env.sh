#!/bin/bash

set -euo pipefail

export LC_ALL=C

source /common.sh
install_cleanup_trap

ENV_FILE=/etc/pioreactor.env

echo "Creating $ENV_FILE with DOT_PIOREACTOR default"
cat <<'EOT' | sudo tee "$ENV_FILE" >/dev/null
# Pioreactor shared environment for systemd units
DOT_PIOREACTOR=/home/pioreactor/.pioreactor
# Ephemeral runtime root (tmpfs)
RUN_PIOREACTOR=/run/pioreactor
LG_WD=/run/pioreactor
TMPDIR=/tmp/
# Prefer the app venv for all services
PATH=/opt/pioreactor/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
EOT

sudo chmod 0644 "$ENV_FILE"

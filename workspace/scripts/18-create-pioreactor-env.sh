#!/bin/bash

set -euo pipefail

export LC_ALL=C

source /common.sh
install_cleanup_trap

ENV_FILE=/etc/pioreactor.env
PROFILED_SNIPPET=/etc/profile.d/pioreactor-venv.sh

echo "Creating $ENV_FILE with DOT_PIOREACTOR default"
cat <<'EOT' | sudo tee "$ENV_FILE" >/dev/null
# Pioreactor shared environment for systemd units
DOT_PIOREACTOR=/home/pioreactor/.pioreactor
# Ephemeral runtime root (tmpfs)
RUN_PIOREACTOR=/run/pioreactor
LG_WD=/run/pioreactor
TMPDIR=/tmp/
# Python virtual environment
PIO_VENV=/opt/pioreactor/venv
VIRTUAL_ENV=/opt/pioreactor/venv
# Ensure venv CLI tools resolve first
PATH=/opt/pioreactor/venv/bin:/home/pioreactor/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
EOT

sudo chmod 0644 "$ENV_FILE"

# Interactive shells: prepend venv/bin to PATH
cat <<'EOT' | sudo tee "$PROFILED_SNIPPET" >/dev/null
# Prefer Pioreactor virtualenv in interactive shells
if [ -d "/opt/pioreactor/venv/bin" ]; then
  export VIRTUAL_ENV=/opt/pioreactor/venv
  case ":$PATH:" in
    *:"/opt/pioreactor/venv/bin":*) ;;
    *) export PATH="/opt/pioreactor/venv/bin:$PATH" ;;
  esac
fi
EOT
sudo chmod 0644 "$PROFILED_SNIPPET"

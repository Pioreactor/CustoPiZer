#!/bin/bash

set -euo pipefail

export LC_ALL=C

source /common.sh
install_cleanup_trap

ENV_FILE=/etc/pioreactor.env
ENV_FILE_SOURCE=/files/system/pioreactor.env
PROFILED_SNIPPET=/etc/profile.d/pioreactor-venv.sh

echo "Installing $ENV_FILE from template"
sudo install -o root -g root -m 0644 "$ENV_FILE_SOURCE" "$ENV_FILE"

# Populate interactive shells with Pioreactor environment variables and PATH defaults.
cat <<'EOT' | sudo tee "$PROFILED_SNIPPET" >/dev/null
# Load Pioreactor shared environment for interactive shells.
if [ -f /etc/pioreactor.env ]; then
  while IFS='=' read -r key value; do
    case "$key" in
      ''|'#'*) continue ;;
    esac
    export "$key=$value"
  done < /etc/pioreactor.env
fi

# Prefer Pioreactor virtualenv in interactive shells.
if [ -d "/opt/pioreactor/venv/bin" ]; then
  export VIRTUAL_ENV=/opt/pioreactor/venv
  case ":$PATH:" in
    *:"/opt/pioreactor/venv/bin":*) ;;
    *) export PATH="/opt/pioreactor/venv/bin:$PATH" ;;
  esac
fi
EOT
sudo chmod 0644 "$PROFILED_SNIPPET"

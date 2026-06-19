#!/bin/bash

set -euo pipefail

export LC_ALL=C

source /common.sh
install_cleanup_trap

ENV_FILE=/etc/pioreactor.env
ENV_FILE_SOURCE=/files/system/pioreactor.env
PROFILED_SNIPPET=/etc/profile.d/pioreactor-venv.sh
PIO_WRAPPER=/usr/local/bin/pio
PIOS_WRAPPER=/usr/local/bin/pios

echo "Installing $ENV_FILE from template"
sudo install -o root -g root -m 0644 "$ENV_FILE_SOURCE" "$ENV_FILE"
echo "PIOREACTOR_IMAGE_PROFILE=${PIOREACTOR_IMAGE_PROFILE:-standard}" | sudo tee -a "$ENV_FILE" >/dev/null

install_pioreactor_cli_wrapper() {
  local wrapper_path=$1
  local executable_name=$2

  cat <<EOT | sudo tee "$wrapper_path" >/dev/null
#!/bin/sh
set -a
. /etc/pioreactor.env
set +a
exec /opt/pioreactor/venv/bin/$executable_name "\$@"
EOT
  sudo chmod 0755 "$wrapper_path"
}

install_pioreactor_cli_wrapper "$PIO_WRAPPER" "pio"
install_pioreactor_cli_wrapper "$PIOS_WRAPPER" "pios"

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

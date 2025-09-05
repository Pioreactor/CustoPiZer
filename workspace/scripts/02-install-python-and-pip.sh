#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap


apt-get install -y python3-venv python3-dev build-essential # C extensions

# Install uv for later use (venv + package installs handled in 06)
curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh
uv --version

# Avoid system/root Python package installs; use apt where needed
apt-get install -y crudini

# quick sanity
crudini --help >/dev/null

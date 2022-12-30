#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap


apt-get install -y python3-pip --no-install-recommends # pip installs lots of useless recommended dependencies, so this flag prevents that
pip3 install pip -U  # update to latest pip
pip3 config set global.disable-pip-version-check true
pip3 config set global.root-user-action "ignore"

#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap


apt-get install -y python3-pip
apt-get install -y python3-dev # needed to build CLoader in pyyaml
pip3 config set global.disable-pip-version-check true # don't check for latest pip
pip3 config set global.root-user-action "ignore"

#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap


sudo apt-get install -y locales
sudo locale-gen en_GB.UTF-8
sudo update-locale LANG=en_GB.UTF-8


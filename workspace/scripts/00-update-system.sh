#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

#??
update-locale "LANG=en_US.UTF-8"
locale-gen --purge "en_US.UTF-8"
dpkg-reconfigure --frontend noninteractive locales
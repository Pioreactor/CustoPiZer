#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

apt-get update

cat /etc/fake-hwclock.data
#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

# Ensure Pioreactor login shells have a generated UTF-8 locale available.
if ! command -v update-locale >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y locales
fi

if ! (locale -a 2>/dev/null | grep -qx 'en_US\.utf8'); then
    if grep -q '^# *en_US.UTF-8 UTF-8' /etc/locale.gen; then
        sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    elif ! grep -q '^en_US.UTF-8 UTF-8' /etc/locale.gen; then
        echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
    fi

    locale-gen en_US.UTF-8
fi

update-locale LANG=en_US.UTF-8 LC_CTYPE=en_US.UTF-8 LC_MESSAGES=en_US.UTF-8 LC_ALL=en_US.UTF-8

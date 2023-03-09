#!/bin/bash

set -x
set -e

export LC_ALL=C


if [[ $(systemd-analyze verify default.target) ]]; then
    echo_red "Cycle found in systemd"
    exit 1
fi

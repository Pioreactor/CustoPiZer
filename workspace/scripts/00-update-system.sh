#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

sudo fake-hwclock save # save the stored time to the current time
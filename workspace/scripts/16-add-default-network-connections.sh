#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

cp /files/system/NetworkManager/PioreactorAP.service /etc/NetworkManager/system-connections/
cp /files/system/NetworkManager/PioreactorLocalLink.service /etc/NetworkManager/system-connections/


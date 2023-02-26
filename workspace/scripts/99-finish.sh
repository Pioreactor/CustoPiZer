#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap


sudo apt-get clean


touch /home/pioreactor/.pioreactor/.image_info
echo -e "CUSTOPIZER_GIT_COMMIT=$CUSTOPIZER_GIT_COMMIT"  >> /home/pioreactor/.pioreactor/.image_info

echo_green "Complete!"
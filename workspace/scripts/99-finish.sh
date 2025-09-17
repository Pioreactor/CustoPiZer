#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap


sudo apt-get clean

USERNAME=pioreactor
PIO_DIR=/home/$USERNAME/.pioreactor

ensure_dot_pioreactor_tree_group_is_www_data() {
    if [ -d "$PIO_DIR" ]; then
        find "$PIO_DIR" -mindepth 0 \( ! -user "$USERNAME" -o ! -group www-data \) -exec chown -h "$USERNAME":www-data {} +
        find "$PIO_DIR" -type d ! -perm -2000 -exec chmod g+s {} +
    fi
}

sudo -u $USERNAME touch $PIO_DIR/.image_info
echo -e "CUSTOPIZER_GIT_COMMIT=$CUSTOPIZER_GIT_COMMIT" | sudo -u $USERNAME tee -a $PIO_DIR/.image_info > /dev/null

ensure_dot_pioreactor_tree_group_is_www_data

echo_green "Complete!"

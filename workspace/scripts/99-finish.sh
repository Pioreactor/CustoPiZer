#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap


sudo apt-get clean

USERNAME=pioreactor
DOT_PIOREACTOR=/home/$USERNAME/.pioreactor

ensure_dot_pioreactor_tree_group_is_www_data() {
    if [ -d "$DOT_PIOREACTOR" ]; then
        find "$DOT_PIOREACTOR" -mindepth 0 \( ! -user "$USERNAME" -o ! -group www-data \) -exec chown -h "$USERNAME":www-data {} +
        chmod g+w "$DOT_PIOREACTOR"
        find "$DOT_PIOREACTOR" -mindepth 1 \( -type d -o -type f \) -exec chmod g+w {} +
        find "$DOT_PIOREACTOR" -type d ! -perm -2000 -exec chmod g+s {} +
    fi
}

sudo -u $USERNAME touch $DOT_PIOREACTOR/.image_info
echo -e "CUSTOPIZER_GIT_COMMIT=$CUSTOPIZER_GIT_COMMIT" | sudo -u $USERNAME tee -a $DOT_PIOREACTOR/.image_info > /dev/null

ensure_dot_pioreactor_tree_group_is_www_data

echo_green "Complete!"

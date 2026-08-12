#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

purge_installed_packages() {
    local packages=("$@")
    local installed_packages=()
    local package

    for package in "${packages[@]}"; do
        if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
            installed_packages+=("$package")
        fi
    done

    if [ "${#installed_packages[@]}" -gt 0 ]; then
        sudo apt-get purge -y "${installed_packages[@]}"
    fi
}

purge_installed_packages_matching_patterns() {
    local patterns=("$@")
    local installed_packages=()
    local pattern

    for pattern in "${patterns[@]}"; do
        while IFS= read -r package; do
            [ -n "$package" ] || continue
            installed_packages+=("$package")
        done < <(dpkg-query -W -f='${binary:Package}\n' | grep -E "$pattern" || true)
    done

    if [ "${#installed_packages[@]}" -gt 0 ]; then
        mapfile -t installed_packages < <(printf '%s\n' "${installed_packages[@]}" | sort -u)
        sudo apt-get purge -y "${installed_packages[@]}"
    fi
}

if [ "$HEADLESS" == "1" ]; then
    purge_installed_packages \
        7zip \
        bluez \
        bluez-firmware \
        cifs-utils \
        cloud-guest-utils \
        cloud-init \
        console-setup \
        console-setup-linux \
        kbd \
        keyboard-configuration \
        mkvtoolnix \
        modemmanager \
        ntfs-3g \
        rpi-cloud-init-mods \
        rpi-connect-lite \
        udisks2 \
        usb-modeswitch \
        usb-modeswitch-data \
        v4l-utils \
        xkb-data
fi

purge_installed_packages \
    firmware-atheros \
    firmware-libertas \
    firmware-mediatek \
    libjpeg-dev \
    liblgpio-dev \
    libyaml-dev \
    python3-dev \
    swig \
    zlib1g-dev

purge_installed_packages rpi-eeprom
purge_installed_packages_matching_patterns '^linux-headers-' '^linux-kbuild-.*rpt'
sudo apt-get autoremove --purge -y
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

#!/bin/bash

# Install plugin wheels staged on the boot partition, then remove them from the card.
#
# This mirrors the two existing boot-partition inputs, which are consumed once and
# deleted (config.ini via everyboot.sh, wifi.ini via bootfs_wifi.sh), and reuses the
# USB-drive plugin layout, pioreactor/plugins/*.whl. Users flash a stock image, drop a
# folder onto the bootfs volume that appears on their PC, and boot. No SSH, no network,
# no USB drive.
#
# Layout on the card:
#   /boot/firmware/pioreactor/plugins/<plugin>-<version>-py3-none-any.whl
#   /boot/firmware/pioreactor/plugins/<dependency>-<version>-....whl   (optional)
#
# A wheel that declares a [pioreactor.plugins] entry point is a plugin. Any other wheel
# is a dependency and is only used to let pip resolve offline (--no-index --find-links).
# Each plugin is installed together with its dependencies first, then handed to
# `pio plugins install --source`, which force-reinstalls the plugin itself and merges
# its UI assets, additional_config.ini, SQL and post-install hook exactly as the UI does.
#
# A plugin that fails to install is moved to pioreactor/plugins/failed/ next to a .log
# of the attempt, so a user with no SSH can read why by putting the card back in a PC.
#
# Runs as root from bootfs_plugins.service, ordered after firstboot.service and only
# once config.ini exists: `pio` refuses to start on a worker that has not yet been
# added to a cluster, so bootfs_plugins.path re-triggers the service when the leader
# delivers config.ini.

set -u
export LC_ALL=C

# shellcheck source=/dev/null
source /etc/pioreactor.env 2>/dev/null || true
VENV_BIN="${PIO_VENV:-/opt/pioreactor/venv}/bin"
PIP="$VENV_BIN/pip"
CRUDINI="$VENV_BIN/crudini"
PIO=/usr/local/bin/pio
DOT_PIOREACTOR="${DOT_PIOREACTOR:-/home/pioreactor/.pioreactor}"

PLUGINS_DIR=/boot/firmware/pioreactor/plugins
FAILED_DIR=$PLUGINS_DIR/failed

log() {
    # $1 level (info|notice|warning|error), $2 message
    echo "bootfs_plugins [$1]: $2" >&2
    timeout 30 sudo -u pioreactor -i "$PIO" log -n bootfs_plugins -l "$1" -m "$2" >/dev/null 2>&1 || :
}

is_leader() {
    local leader_hostname
    leader_hostname=$(sudo -u pioreactor -i "$PIO" config get cluster.topology leader_hostname 2>/dev/null || :)
    [ -n "$leader_hostname" ] && [ "$leader_hostname" = "$(hostname)" ]
}

is_plugin_wheel() {
    unzip -p "$1" '*.dist-info/entry_points.txt' 2>/dev/null | grep -q '^\[pioreactor\.plugins\]'
}

is_leader_only_wheel() {
    unzip -l "$1" LEADER_ONLY >/dev/null 2>&1
}

warn_on_channel_reassignment() {
    # $1 plugin name, $2 wheel.
    # `pio plugins install` merges additional_config.ini into unit_config.ini and overrides
    # existing values without comment. Hardware channels are the one place that matters:
    # say so in the log when a plugin takes over a PWM or LED channel that is already assigned.
    local additional section key new current
    additional=$(mktemp)
    if ! unzip -p "$2" '*/additional_config.ini' >"$additional" 2>/dev/null || [ ! -s "$additional" ]; then
        rm -f "$additional"
        return 0
    fi
    for section in PWM leds; do
        while IFS= read -r key; do
            [ -n "$key" ] || continue
            new=$("$CRUDINI" --get "$additional" "$section" "$key" 2>/dev/null || :)
            current=$(sudo -u pioreactor -i "$PIO" config get "$section" "$key" 2>/dev/null || :)
            if [ -n "$current" ] && [ "$current" != "$new" ]; then
                log warning "Plugin $1 reassigns [$section] $key from '$current' to '$new' in unit_config.ini"
            fi
        done < <("$CRUDINI" --get "$additional" "$section" 2>/dev/null || :)
    done
    rm -f "$additional"
}

main() {
    local wheels
    shopt -s nullglob
    wheels=("$PLUGINS_DIR"/*.whl)
    shopt -u nullglob
    [ ${#wheels[@]} -gt 0 ] || exit 0

    if [ ! -f "$DOT_PIOREACTOR/config.ini" ]; then
        # A worker that has not been added to a cluster yet. Leave the wheels where they
        # are; bootfs_plugins.path starts this service again once config.ini arrives.
        echo "bootfs_plugins: no config.ini yet; leaving ${#wheels[@]} wheel(s) on the boot partition" >&2
        exit 0
    fi

    local leader=false
    is_leader && leader=true

    local failures=0 whl file name logfile
    for whl in "${wheels[@]}"; do
        file=$(basename "$whl")
        name=${file%%-*}
        name=${name,,}
        name=${name//_/-}

        if ! is_plugin_wheel "$whl"; then
            continue # a dependency: consumed through --find-links only
        fi

        if [ "$leader" = false ] && is_leader_only_wheel "$whl"; then
            log notice "Skipping LEADER_ONLY plugin $name on a worker; removing $file from the boot partition"
            rm -f "$whl"
            continue
        fi

        warn_on_channel_reassignment "$name" "$whl"

        logfile=$(mktemp)
        # shellcheck disable=SC2024  # the log file is ours (root); only pip runs as pioreactor
        if sudo -u pioreactor "$PIP" install --no-index --find-links "$PLUGINS_DIR" "$whl" >"$logfile" 2>&1 &&
            timeout 900 sudo -u pioreactor -i "$PIO" plugins install "$name" --source "$whl" >>"$logfile" 2>&1; then
            log notice "Installed plugin $name from the boot partition ($file)"
            rm -f "$whl"
        else
            mkdir -p "$FAILED_DIR"
            mv -f "$whl" "$FAILED_DIR/$file"
            cp "$logfile" "$FAILED_DIR/$file.log"
            log error "Failed to install plugin $name from the boot partition; see $FAILED_DIR/$file.log"
            failures=$((failures + 1))
        fi
        rm -f "$logfile"
    done

    if [ "$failures" -eq 0 ]; then
        # Every plugin installed, so any dependency wheels have served their purpose.
        shopt -s nullglob
        rm -f "$PLUGINS_DIR"/*.whl
        shopt -u nullglob
    fi

    # A failed plugin is reported above and must never hold up the rest of boot.
    exit 0
}

main

#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)

PIOREACTOR_REPO=${1:-"${PIOREACTOR_REPO:-../pioreactor}"}
PIOREACTOR_ASSETS="$PIOREACTOR_REPO/packaging/shared-assets"
PIOREACTOR_LINUX_LEADER_FILES="$PIOREACTOR_REPO/packaging/linux-leader/files"
TARGET_FILES="$REPO_ROOT/workspace/scripts/files"

die() {
  echo "error: $*" >&2
  exit 1
}

[ -d "$PIOREACTOR_ASSETS" ] || die "Could not find Pioreactor assets at $PIOREACTOR_ASSETS"
[ -d "$PIOREACTOR_LINUX_LEADER_FILES" ] || die "Could not find Pioreactor Linux leader files at $PIOREACTOR_LINUX_LEADER_FILES"

mkdir -p \
  "$TARGET_FILES/sql" \
  "$TARGET_FILES/pioreactor/exportable_datasets" \
  "$TARGET_FILES/pioreactor/ui" \
  "$TARGET_FILES/system/lighttpd" \
  "$TARGET_FILES/system/logrotate" \
  "$TARGET_FILES/system/tmpfiles.d"

rsync -a --delete "$PIOREACTOR_ASSETS/sql/" "$TARGET_FILES/sql/"
rsync -a --delete "$PIOREACTOR_ASSETS/pioreactor/exportable_datasets/" "$TARGET_FILES/pioreactor/exportable_datasets/"
rsync -a --delete "$PIOREACTOR_ASSETS/pioreactor/ui/" "$TARGET_FILES/pioreactor/ui/"
install -m 0644 "$PIOREACTOR_ASSETS/pioreactor/config.example.ini" "$TARGET_FILES/pioreactor/config.example.ini"

for lighttpd_conf in 10-expire.conf 50-pioreactorui.conf 51-cors.conf lighttpd.conf; do
  install -m 0644 "$PIOREACTOR_LINUX_LEADER_FILES/lighttpd/$lighttpd_conf" "$TARGET_FILES/system/lighttpd/$lighttpd_conf"
done
install -m 0644 "$PIOREACTOR_LINUX_LEADER_FILES/tmpfiles.d/pioreactor.conf" "$TARGET_FILES/system/tmpfiles.d/pioreactor.conf"
install -m 0644 "$PIOREACTOR_LINUX_LEADER_FILES/logrotate/pioreactor" "$TARGET_FILES/system/logrotate/pioreactor"
install -m 0644 "$PIOREACTOR_LINUX_LEADER_FILES/pioreactor.env" "$TARGET_FILES/system/pioreactor.env"

# Systemd targets and service ordering are image-owned here: CustoPiZer keeps
# firstboot, worker, hardware, local access point, and monitor boot semantics.

echo "Synced Pioreactor assets from $PIOREACTOR_ASSETS"

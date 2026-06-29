#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)

PIOREACTOR_REPO=${1:-"${PIOREACTOR_REPO:-../pioreactor}"}
PIOREACTOR_ASSETS="$PIOREACTOR_REPO/packaging/shared-assets"
PIOREACTOR_RUNTIME_FILES="$PIOREACTOR_REPO/packaging/runtime-files"
PIOREACTOR_AGENTS="$PIOREACTOR_REPO/.agents"
TARGET_FILES="$REPO_ROOT/workspace/scripts/files"

die() {
  echo "error: $*" >&2
  exit 1
}

[ -d "$PIOREACTOR_ASSETS" ] || die "Could not find Pioreactor assets at $PIOREACTOR_ASSETS"
[ -d "$PIOREACTOR_RUNTIME_FILES" ] || die "Could not find Pioreactor runtime files at $PIOREACTOR_RUNTIME_FILES"
[ -d "$PIOREACTOR_AGENTS" ] || die "Could not find Pioreactor agents at $PIOREACTOR_AGENTS"

mkdir -p \
  "$TARGET_FILES/bash" \
  "$TARGET_FILES/agents" \
  "$TARGET_FILES/sql" \
  "$TARGET_FILES/pioreactor/exportable_datasets" \
  "$TARGET_FILES/pioreactor/experiment_profiles" \
  "$TARGET_FILES/pioreactor/ui" \
  "$TARGET_FILES/system/lighttpd" \
  "$TARGET_FILES/system/systemd" \
  "$TARGET_FILES/system/logrotate" \
  "$TARGET_FILES/system/tmpfiles.d"

rsync -a --delete "$PIOREACTOR_ASSETS/sql/" "$TARGET_FILES/sql/"
rsync -a --delete "$PIOREACTOR_AGENTS/" "$TARGET_FILES/agents/"
rsync -a --delete "$PIOREACTOR_ASSETS/pioreactor/exportable_datasets/" "$TARGET_FILES/pioreactor/exportable_datasets/"
rsync -a --delete "$PIOREACTOR_ASSETS/pioreactor/experiment_profiles/" "$TARGET_FILES/pioreactor/experiment_profiles/"
rsync -a --delete "$PIOREACTOR_ASSETS/pioreactor/ui/" "$TARGET_FILES/pioreactor/ui/"
install -m 0644 "$PIOREACTOR_ASSETS/pioreactor/config.example.ini" "$TARGET_FILES/pioreactor/config.example.ini"

for lighttpd_conf in 10-pioreactor-https.conf 10-expire.conf 50-pioreactorui.conf 51-cors.conf lighttpd.conf; do
  install -m 0644 "$PIOREACTOR_RUNTIME_FILES/lighttpd/$lighttpd_conf" "$TARGET_FILES/system/lighttpd/$lighttpd_conf"
done
install -m 0644 "$PIOREACTOR_RUNTIME_FILES/tmpfiles.d/pioreactor.conf" "$TARGET_FILES/system/tmpfiles.d/pioreactor.conf"
install -m 0644 "$PIOREACTOR_RUNTIME_FILES/logrotate/pioreactor" "$TARGET_FILES/system/logrotate/pioreactor"
install -m 0644 "$PIOREACTOR_RUNTIME_FILES/pioreactor.env" "$TARGET_FILES/system/pioreactor.env"
for bash_helper in start_pioreactor_huey.sh add_new_pioreactor_worker_from_leader.sh; do
  install -m 0755 "$PIOREACTOR_RUNTIME_FILES/bash/$bash_helper" "$TARGET_FILES/bash/$bash_helper"
done
for systemd_unit in huey.service lighttpd.service pioreactor-web.target; do
  install -m 0644 "$PIOREACTOR_RUNTIME_FILES/systemd/$systemd_unit" "$TARGET_FILES/system/systemd/$systemd_unit"
done

# Systemd targets and service ordering are image-owned here: CustoPiZer keeps
# firstboot, worker, hardware, local access point, and monitor boot semantics.

echo "Synced Pioreactor assets from $PIOREACTOR_ASSETS"

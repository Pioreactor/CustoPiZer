#!/usr/bin/env bash

# Cron runs this file from /root/CustoPiZer on nightly.pioreactor.com. Edit it here and push; don't edit it on the server.

set -euxo pipefail

PIOREACTOR_BRANCH=${PIOREACTOR_BRANCH:-develop}
CUSTOPIZER_BRANCH=${CUSTOPIZER_BRANCH:-pioreactor}

ARMHF_IMAGE_URL="https://downloads.raspberrypi.com/raspios_lite_armhf/images/raspios_lite_armhf-2026-10-06/2026-10-06-raspios-trixie-armhf-lite.img.xz"
ARM64_IMAGE_URL="https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2026-10-06/2026-10-06-raspios-trixie-arm64-lite.img.xz"

DATE=$(date +%F)
NIGHTLY_ROOT=/var/www/nightlies/nightly

update_repo_branch() {
  local repo_dir=$1
  local branch=$2

  # Build checkouts are throwaway: never edit them by hand. The asset sync rewrites tracked files every night.
  git -C "$repo_dir" fetch origin "$branch"
  git -C "$repo_dir" checkout -f -B "$branch" "origin/$branch"
  git -C "$repo_dir" clean -fd
}

download_base_image() {
  local image_url=$1

  wget "$image_url" -q -O workspace/input.img.xz
  unxz -f workspace/input.img.xz
}

sudo mkdir -p \
  "$NIGHTLY_ROOT/leader_worker" \
  "$NIGHTLY_ROOT/worker" \
  "$NIGHTLY_ROOT/leader"

find "$NIGHTLY_ROOT/worker/" -mindepth 1 -mtime +1 -delete
find "$NIGHTLY_ROOT/leader_worker/" -mindepth 1 -mtime +1 -delete
find "$NIGHTLY_ROOT/leader/" -mindepth 1 -mtime +1 -delete

update_repo_branch /root/pioreactor "$PIOREACTOR_BRANCH"
update_repo_branch /root/CustoPiZer "$CUSTOPIZER_BRANCH"

cd /root/CustoPiZer
bash scripts/sync_pioreactor_assets.sh /root/pioreactor
bash scripts/download_python_wheels.sh

download_base_image "$ARMHF_IMAGE_URL"
bash make_leader_worker_image.sh "$PIOREACTOR_BRANCH" "$(pwd)/config.local" 1
sudo mv /root/CustoPiZer/workspace/pioreactor_leader_worker.img.zip "$NIGHTLY_ROOT/leader_worker/pioreactor_leader_worker_$DATE.img.zip"

# bash make_leader_image.sh "$PIOREACTOR_BRANCH" "$(pwd)/config.local"
# sudo mv /root/CustoPiZer/workspace/pioreactor_leader.img.zip "$NIGHTLY_ROOT/leader/pioreactor_leader_$DATE.img.zip"

bash make_worker_image.sh "$PIOREACTOR_BRANCH" "$(pwd)/config.local"
sudo mv /root/CustoPiZer/workspace/pioreactor_worker.img.zip "$NIGHTLY_ROOT/worker/pioreactor_worker_$DATE.img.zip"


download_base_image "$ARM64_IMAGE_URL"
bash make_leader_worker_image.sh "$PIOREACTOR_BRANCH" "$(pwd)/config_64.local" 1
sudo mv /root/CustoPiZer/workspace/pioreactor_leader_worker.img.zip "$NIGHTLY_ROOT/leader_worker/pioreactor_leader_worker_${DATE}_64.img.zip"

# bash make_leader_image.sh "$PIOREACTOR_BRANCH" "$(pwd)/config_64.local"
# sudo mv /root/CustoPiZer/workspace/pioreactor_leader.img.zip "$NIGHTLY_ROOT/leader/pioreactor_leader_${DATE}_64.img.zip"

bash make_worker_image.sh "$PIOREACTOR_BRANCH" "$(pwd)/config_64.local"
sudo mv /root/CustoPiZer/workspace/pioreactor_worker.img.zip "$NIGHTLY_ROOT/worker/pioreactor_worker_${DATE}_64.img.zip"

python3 scripts/build_nightly_pioreactor_imager_list.py \
  --nightly-root "$NIGHTLY_ROOT" \
  --output-path /var/www/nightlies/os_list_pioreactor_nightly.json \
  --base-url https://nightly.pioreactor.com

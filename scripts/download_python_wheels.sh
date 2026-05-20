#!/usr/bin/env bash

set -euo pipefail

WHEEL_DIR=${1:-workspace/scripts/files/wheels}

mkdir -p "$WHEEL_DIR"

download_wheels() {
  local platform_label=$1
  shift

  echo "Downloading Python wheels for $platform_label..."
  python3 -m pip download \
    --dest "$WHEEL_DIR" \
    --index-url https://www.piwheels.org/simple \
    --extra-index-url https://pypi.org/simple \
    --only-binary=:all: \
    --no-deps \
    --implementation cp \
    --python-version 3.13 \
    --abi cp313 \
    "$@" \
    pillow==12.0.0 \
    PyYAML==6.0.2 \
    numpy==2.3.2
}

retry_download_wheels() {
  local platform_label=$1
  shift

  for attempt in 1 2 3 4 5; do
    if download_wheels "$platform_label" "$@"; then
      return 0
    fi
    echo "Wheel download for $platform_label attempt $attempt failed; retrying..."
    sleep $((attempt * 15))
  done

  download_wheels "$platform_label" "$@"
}

retry_download_wheels "32-bit armhf" --platform linux_armv7l

if [ "${DOWNLOAD_64_BIT_WHEELS:-1}" = "1" ]; then
  if retry_download_wheels "64-bit arm64" \
    --platform manylinux_2_28_aarch64 \
    --platform manylinux_2_27_aarch64 \
    --platform manylinux2014_aarch64; then
    exit 0
  fi

  echo "64-bit wheel download failed; retrying with linux_aarch64 platform tag..."
  retry_download_wheels "64-bit arm64" --platform linux_aarch64
fi

#!/bin/bash

set -euo pipefail

WHEEL_DIR=${1:-workspace/scripts/files/wheels}

mkdir -p "$WHEEL_DIR"

download_wheels() {
  python3 -m pip download \
    --dest "$WHEEL_DIR" \
    --index-url https://www.piwheels.org/simple \
    --extra-index-url https://pypi.org/simple \
    --only-binary=:all: \
    --no-deps \
    --implementation cp \
    --python-version 3.13 \
    --abi cp313 \
    --platform linux_armv7l \
    pillow==12.0.0 \
    PyYAML==6.0.2 \
    numpy==2.3.2
}

for attempt in 1 2 3 4 5; do
  if download_wheels; then
    exit 0
  fi
  echo "Wheel download attempt $attempt failed; retrying..."
  sleep $((attempt * 15))
done

download_wheels

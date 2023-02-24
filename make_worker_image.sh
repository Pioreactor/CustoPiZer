#!/bin/bash

: ${1?"Usage: $0 PIO_VERSION"}

GIT_COMMIT="$(git show --format="%h" --no-patch)"
DATE=$(date '+%Y-%m-%d')

OUTPUT=pioreactor_worker.img.zip

rm -f workspace/$OUTPUT

docker run --rm --privileged \
    -e PIO_VERSION=$1 \
    -e CUSTOPIZER_GIT_COMMIT=$GIT_COMMIT \
    -e WORKER=1 \
    -e LEADER=0 \
    -v $(pwd)/workspace:/CustoPiZer/workspace/  -v $(pwd)/config.local:/CustoPiZer/config.local ghcr.io/octoprint/custopizer:latest \
    && (cd workspace/; zip $OUTPUT output.img) \
    && echo $OUTPUT \
    && md5sum workspace/$OUTPUT \
    && rm workspace/output.img

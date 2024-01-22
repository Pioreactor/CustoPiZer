#!/bin/bash

: ${1?"Usage: $0 PIO_VERSION"}

PIO_VERSION=$1
CONFIG=$2

GIT_COMMIT="$(git show --format="%h" --no-patch)"

OUTPUT=pioreactor_worker.img.zip

rm -f workspace/$OUTPUT

docker run --rm --privileged \
    -e PIO_VERSION=$PIO_VERSION \
    -e CUSTOPIZER_GIT_COMMIT=$GIT_COMMIT \
    -e WORKER=1 \
    -e LEADER=0 \
    -e HEADLESS=1 \
    -v $(pwd)/workspace:/CustoPiZer/workspace/  -v $CONFIG:/CustoPiZer/config.local ghcr.io/octoprint/custopizer:latest \
    && (cd workspace/; zip $OUTPUT output.img) \
    && echo $OUTPUT \
    && md5sum workspace/$OUTPUT \
    && rm workspace/output.img

#!/bin/bash

: ${1?"Usage: $0 IMAGE_NAME"}


CONFIG=$2

docker run -it --rm --privileged -v $(pwd)/workspace/$1:/$1  -v $CONFIG:/CustoPiZer/config.local ghcr.io/octoprint/custopizer:latest /CustoPiZer/enter_image /$1
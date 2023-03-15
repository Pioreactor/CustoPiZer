#!/bin/bash

: ${1?"Usage: $0 IMAGE_NAME"}

docker run -it --rm --privileged -v $(pwd)/workspace/$1:/$1 ghcr.io/octoprint/custopizer:latest /CustoPiZer/enter_image /$1
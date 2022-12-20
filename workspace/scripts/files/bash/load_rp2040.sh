#!/bin/bash

set -x
set -e

export LC_ALL=C

openocd -f interface/raspberrypi-swd.cfg -f target/rp2040.cfg -c "init" -c "reset halt" -c "load_image main.elf" -c "resume 0x20000000" -c "exit"
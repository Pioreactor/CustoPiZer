#!/bin/bash

# this runs at startup on every boot.

set -x
set -e

export LC_ALL=C

crudini --merge /home/pioreactor/.pioreactor/config.ini < /boot/config.ini

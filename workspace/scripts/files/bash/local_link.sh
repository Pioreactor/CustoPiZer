#!/bin/bash

set -x
set -e

export LC_ALL=C

# IPv4=$(head -c 15 /boot/firmware/local_link)


# sudo nmcli connection modify PioreactorLocalLink ipv4.addresses "$IPv4"/16
# sudo nmcli connection modify PioreactorLocalLink connection.autoconnect-priority 2


sudo nmcli con up PioreactorLocalLink

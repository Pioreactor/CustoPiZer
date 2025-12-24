#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

sudo apt-get install chrony -y


if [ "$LEADER" == "1" ]; then
    # this IP range is for the local-access-point set up by nmcli
    echo "allow all" | sudo tee -a  /etc/chrony/chrony.conf
    echo "local stratum 10" | sudo tee -a  /etc/chrony/chrony.conf
else
    echo "makestep 3600 -1" | sudo tee -a  /etc/chrony/chrony.conf
    echo "maxchange 7200 1 -1" | sudo tee -a  /etc/chrony/chrony.conf
fi


# trixie doesn't have fake-hwclock, but bullseye did. So leaders on bullseye who try to add
# a worker on trixie will encounter failure. Add an empty fake-hwclock.
sudo tee /usr/local/bin/fake-hwclock >/dev/null <<'EOF'
#!/bin/sh
# dummy fake-hwclock command
echo "Deprecated. This does nothing."
exit 0
EOF
sudo chmod +x /usr/local/bin/fake-hwclock
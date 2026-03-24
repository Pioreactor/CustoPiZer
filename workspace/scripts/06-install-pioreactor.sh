#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

USERNAME=pioreactor
DOT_PIOREACTOR=/home/$USERNAME/.pioreactor
PIO_VENV=/opt/pioreactor/venv

ensure_dot_pioreactor_tree_group_is_www_data() {
    if [ -d "$DOT_PIOREACTOR" ]; then
        find "$DOT_PIOREACTOR" -mindepth 0 \( ! -user "$USERNAME" -o ! -group www-data \) -exec chown -h "$USERNAME":www-data {} +
        chmod g+w "$DOT_PIOREACTOR"
        find "$DOT_PIOREACTOR" -mindepth 1 \( -type d -o -type f \) -exec chmod g+w {} +
        find "$DOT_PIOREACTOR" -type d ! -perm -2000 -exec chmod g+s {} +
    fi
}

if [ "$PIO_VERSION" == "develop" ]; then
    sudo apt-get install -y git
fi
# Ensure setfacl is available for cache directory ACLs applied at boot
sudo apt-get install -y acl


sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR
sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR/storage
sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR/models


sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR/storage/calibrations/{stirring,od45,od90,od135,media_pump,waste_pump,alt_media_pump}
chown -R $USERNAME:www-data $DOT_PIOREACTOR/storage/calibrations/{stirring,od45,od90,od135,media_pump,waste_pump,alt_media_pump}
chmod g+s $DOT_PIOREACTOR/storage/calibrations/{stirring,od45,od90,od135,media_pump,waste_pump,alt_media_pump}

sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR/hardware
sudo -u $USERNAME cp -r /files/pioreactor/hardware/. $DOT_PIOREACTOR/hardware/


if [ "$LEADER" == "1" ]; then

  sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR/experiment_profiles
  chown -R $USERNAME:www-data $DOT_PIOREACTOR/experiment_profiles
  chmod g+s $DOT_PIOREACTOR/experiment_profiles
  echo "Directory for adding experiment profiles: https://docs.pioreactor.com/developer-guide/experiment-profiles" |                   sudo -u $USERNAME tee $DOT_PIOREACTOR/experiment_profiles/README.txt > /dev/null

  cat <<EOT >> $DOT_PIOREACTOR/experiment_profiles/demo_logging_example.yaml
experiment_profile_name: Demo of logging real-time data

metadata:
  author: Cam Davidson-Pilon
  description: A  profile to demonstrate logging real-time data, start stirring in your Pioreactor(s), update RPM, and log the value.

common:
  jobs:
    stirring:
      actions:
        - type: start
          t: 0s
          options:
            target_rpm: 400.0
        - type: log
          t: 2s
          options:
            message: "\${{job_name()}} starting at target \${{::stirring:target_rpm}} RPM"
        - type: log
          t: 10s
          options:
            message: "Increasing to 800 RPM in \${{unit()}}. Try changing the target RPM in the UI."
        - type: update
          t: 10s
          options:
            target_rpm: 800.0
        - type: log
          t: 15s
          options:
            message: "Value of target_rpm in \${{unit()}} is \${{::stirring:target_rpm}} RPM. Stopping."
        - type: stop
          t: 20s
EOT


  cat <<EOT >> $DOT_PIOREACTOR/experiment_profiles/demo_stirring_example.yaml
experiment_profile_name: Demo stirring example

metadata:
  author: Cam Davidson-Pilon
  description: A simple profile to start stirring in your Pioreactor(s), update RPM at 90 seconds, and turn off after 180 seconds.

common:
  jobs:
    stirring:
      actions:
        - type: start
          t: 0s
          options:
            target_rpm: 400.0
        - type: update
          t: 1.5m
          options:
            target_rpm: 800.0
        - type: stop
          t: 3m
EOT

fi

sudo -u $USERNAME touch $DOT_PIOREACTOR/unit_config.ini

# .pioreactor/plugins/ mimics .pioreactor dir
sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR/plugins
echo "Directory for adding Python code, see docs: https://docs.pioreactor.com/developer-guide/intro-plugins" | sudo -u $USERNAME tee $DOT_PIOREACTOR/plugins/README.txt > /dev/null
sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR/plugins/ui/jobs
sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR/plugins/ui/automations/{dosing,led,temperature}
sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR/plugins/ui/charts
sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR/plugins/exportable_datasets

# Expose web exports from /run (ephemeral). No exports under ~/.pioreactor.
# /run/pioreactor/exports is created at boot via systemd-tmpfiles.

# pillow install and adafruit display library
sudo apt install libjpeg-dev zlib1g-dev -y
sudo -u pioreactor "$PIO_VENV/bin/pip" install pillow==12.0.0
sudo -u pioreactor "$PIO_VENV/bin/pip" install adafruit-circuitpython-ssd1306==2.12.22


# lgpio install
sudo apt install swig liblgpio-dev -y
sudo -u pioreactor "$PIO_VENV/bin/pip" install lgpio==0.2.2.0 \
  --index-url https://www.piwheels.org/simple \
  --extra-index-url https://pypi.org/simple

# this is needed from some internal adafruit stuff! =(
sudo -u pioreactor "$PIO_VENV/bin/pip" install rpi-lgpio==0.6

# needed for fast yaml
apt-get install libyaml-dev -y
# https://github.com/yaml/pyyaml/issues/445
sudo -u pioreactor "$PIO_VENV/bin/pip" install pyyaml==6.0.2 \
  --index-url https://www.piwheels.org/simple \
  --extra-index-url https://pypi.org/simple

# needed for the LED at boot
sudo -u pioreactor "$PIO_VENV/bin/pip" install gpiozero \
  --index-url https://www.piwheels.org/simple \
  --extra-index-url https://pypi.org/simple



# install numpy from piwheels into the venv to avoid long builds. But first install C deps.
sudo apt-get install -y libopenblas0-pthread liblapack3

sudo -u pioreactor "$PIO_VENV/bin/pip" install numpy==2.3.2 \
  --index-url https://www.piwheels.org/simple \
  --extra-index-url https://pypi.org/simple

sudo -u pioreactor "$PIO_VENV/bin/pip" install -U setuptools wheel


if [ "$LEADER" == "1" ]; then
    sudo apt-get install -y sshpass
    sudo -u $USERNAME cp /files/pioreactor/config.example.ini $DOT_PIOREACTOR/config.ini

    sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR/exportable_datasets
    sudo -u $USERNAME cp /files/pioreactor/exportable_datasets/*.yaml $DOT_PIOREACTOR/exportable_datasets/

    sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR/ui/
    sudo -u $USERNAME cp -r /files/pioreactor/ui/* $DOT_PIOREACTOR/ui


    if [ "$PIO_VERSION" == "develop" ]; then
        sudo -u pioreactor "$PIO_VENV/bin/pip" install \
          "pioreactor[leader_worker] @ git+https://github.com/pioreactor/pioreactor.git@develop#egg=pioreactor&subdirectory=core" \
          --index-url https://piwheels.org/simple \
          --extra-index-url https://pypi.org/simple
    else
      sudo -u pioreactor "$PIO_VENV/bin/pip" install \
        "pioreactor[leader] @ https://github.com/Pioreactor/pioreactor/releases/download/$PIO_VERSION/pioreactor-$PIO_VERSION-py3-none-any.whl" \
        --index-url https://piwheels.org/simple \
        --extra-index-url https://pypi.org/simple
    fi
fi


if [ "$WORKER" == "1" ]; then

    if [ "$PIO_VERSION" == "develop" ]; then
        sudo -u pioreactor "$PIO_VENV/bin/pip" install "pioreactor[leader_worker] @ git+https://github.com/pioreactor/pioreactor.git@develop#egg=pioreactor&subdirectory=core" --index-url https://piwheels.org/simple --extra-index-url https://pypi.org/simple
    else
        sudo -u pioreactor "$PIO_VENV/bin/pip" install "pioreactor[worker] @ https://github.com/Pioreactor/pioreactor/releases/download/$PIO_VERSION/pioreactor-$PIO_VERSION-py3-none-any.whl" --index-url https://piwheels.org/simple --extra-index-url https://pypi.org/simple
    fi

fi


# useful libs
sudo apt-get install -y jq
sudo apt-get install -y rsyslog
sudo apt-get install libwebpmux3 liblcms2-2 libwebpdemux2 libopenjp2-7 -y # used for Pillow


# Create/refresh symlink for static assets to package location (leaders and workers)
# Lighttpd serves /static/ from /usr/share/pioreactorui/static which points into the installed wheel. py3.13 specific.
STATIC_DIR="/opt/pioreactor/venv/lib/python3.13/site-packages/pioreactor/web/static"

install -d -m 0755 /usr/share/pioreactorui
ln -sfn "$STATIC_DIR" /usr/share/pioreactorui/static

# Precompile bytecode to reduce first-import overhead on device.
sudo -u pioreactor "$PIO_VENV/bin/python" -m compileall -q "$PIO_VENV/lib/python3.13/site-packages"


ensure_dot_pioreactor_tree_group_is_www_data

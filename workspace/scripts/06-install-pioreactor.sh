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
        find "$DOT_PIOREACTOR" -type d ! -perm -2000 -exec chmod g+s {} +
    fi
}

sudo apt-get install -y git
# Ensure setfacl is available for cache directory ACLs applied at boot
sudo apt-get install -y acl


sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR
sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR/storage
sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR/models


sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR/storage/calibrations/{stirring,od,media_pump,waste_pump,alt_media_pump}
chown -R $USERNAME:www-data $DOT_PIOREACTOR/storage/calibrations/{stirring,od,media_pump,waste_pump,alt_media_pump}
chmod g+s $DOT_PIOREACTOR/storage/calibrations/{stirring,od,media_pump,waste_pump,alt_media_pump}

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
          hours_elapsed: 0.0
          options:
            target_rpm: 400.0
        - type: log
          hours_elapsed: 0.001
          options:
            message: "\${{job_name()}} starting at target \${{::stirring:target_rpm}} RPM"
        - type: log
          hours_elapsed: 0.005
          options:
            message: "Increasing to 800 RPM in \${{unit()}}. Try changing the target RPM in the UI."
        - type: update
          hours_elapsed: 0.005
          options:
            target_rpm: 800.0
        - type: log
          hours_elapsed: 0.019
          options:
            message: "Value of target_rpm in \${{unit()}} is \${{::stirring:target_rpm}} RPM. Stopping."
        - type: stop
          hours_elapsed: 0.02
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
          hours_elapsed: 0.0
          options:
            target_rpm: 400.0
        - type: update
          hours_elapsed: 0.025
          options:
            target_rpm: 800.0
        - type: stop
          hours_elapsed: 0.05
EOT

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
sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR/web
chown -R $USERNAME:www-data $DOT_PIOREACTOR/web
find $DOT_PIOREACTOR/web -type d -exec chmod 2775 {} \;
find $DOT_PIOREACTOR/web -type f -exec chmod 0644 {} \;

# lgpio install
sudo apt install swig
sudo "$PIO_VENV/bin/pip" install lgpio \
  --index-url https://www.piwheels.org/simple \
  --extra-index-url https://pypi.org/simple


# needed for fast yaml
apt-get install libyaml-dev -y
# https://github.com/yaml/pyyaml/issues/445
sudo "$PIO_VENV/bin/pip" install pyyaml==6.0.2 \
  --index-url https://www.piwheels.org/simple \
  --extra-index-url https://pypi.org/simple

# install numpy from piwheels into the venv to avoid long builds
sudo "$PIO_VENV/bin/pip" install numpy==2.3.2 \
  --index-url https://www.piwheels.org/simple \
  --extra-index-url https://pypi.org/simple

sudo "$PIO_VENV/bin/pip" install -U setuptools wheel


if [ "$LEADER" == "1" ]; then
    sudo apt-get install sshpass
    sudo -u $USERNAME cp /files/pioreactor/config.example.ini $DOT_PIOREACTOR/config.ini

    sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR/exportable_datasets
    sudo -u $USERNAME cp /files/pioreactor/exportable_datasets/*.yaml $DOT_PIOREACTOR/exportable_datasets/

    sudo -u $USERNAME mkdir -p $DOT_PIOREACTOR/ui/
    sudo -u $USERNAME cp -r /files/pioreactor/ui/* $DOT_PIOREACTOR/ui


    if [ "$PIO_VERSION" == "develop" ]; then
        sudo "$PIO_VENV/bin/pip" install \
          --find-links "$TMP_WHEELS" \
          "pioreactor[leader_worker] @ git+https://github.com/pioreactor/pioreactor.git@develop#egg=pioreactor&subdirectory=core" \
          --index-url https://piwheels.org/simple \
          --extra-index-url https://pypi.org/simple
    else
      sudo "$PIO_VENV/bin/pip" install \
        --find-links "$TMP_WHEELS" \
        "pioreactor[leader] @ https://github.com/Pioreactor/pioreactor/releases/download/$PIO_VERSION/pioreactor-$PIO_VERSION-py3-none-any.whl" \
        --index-url https://piwheels.org/simple \
        --extra-index-url https://pypi.org/simple
    fi
fi


if [ "$WORKER" == "1" ]; then

    if [ "$PIO_VERSION" == "develop" ]; then
        sudo "$PIO_VENV/bin/pip" install "pioreactor[leader_worker] @ git+https://github.com/pioreactor/pioreactor.git@pioreactor2#egg=pioreactor&subdirectory=core" --index-url https://piwheels.org/simple --extra-index-url https://pypi.org/simple
    else
        sudo "$PIO_VENV/bin/pip" install "pioreactor[worker] @ https://github.com/Pioreactor/pioreactor/releases/download/$PIO_VERSION/pioreactor-$PIO_VERSION-py3-none-any.whl" --index-url https://piwheels.org/simple --extra-index-url https://pypi.org/simple
    fi

fi


# useful libs
sudo apt-get install -y jq
sudo apt-get install -y rsyslog
sudo apt-get install libwebpmux3 liblcms2-2 libwebpdemux2 libopenjp2-7 -y # used for Pillow


# Create/refresh symlink for static assets to package location (leaders and workers)
# Lighttpd serves /static/ from /usr/share/pioreactorui/static which points into the installed wheel.
STATIC_DIR=$("$PIO_VENV/bin/python" - <<'PY'
import sys
try:
    import importlib.resources as r
    import pioreactor.web as web
    p = r.files(web)/'static'
    print(p)
except Exception:
    sys.exit(1)
PY
)

install -d -m 0755 /usr/share/pioreactorui
ln -sfn "$STATIC_DIR" /usr/share/pioreactorui/static


ensure_dot_pioreactor_tree_group_is_www_data

#!/bin/bash

set -x
set -e

export LC_ALL=C


source /common.sh
install_cleanup_trap

USERNAME=pioreactor
PIO_DIR=/home/$USERNAME/.pioreactor

sudo apt-get install -y git
# Ensure setfacl is available for cache directory ACLs applied at boot
sudo apt-get install -y acl


sudo -u $USERNAME mkdir -p $PIO_DIR
sudo -u $USERNAME mkdir -p $PIO_DIR/storage
sudo -u $USERNAME mkdir -p $PIO_DIR/models
sudo -u $USERNAME mkdir -p $PIO_DIR/plugins
sudo -u $USERNAME mkdir -p $PIO_DIR/plugins/ui/contrib/jobs
sudo -u $USERNAME mkdir -p $PIO_DIR/plugins/ui/contrib/automations/{dosing,led,temperature}
sudo -u $USERNAME mkdir -p $PIO_DIR/plugins/ui/contrib/charts
echo "Directory for adding Python code, see docs: https://docs.pioreactor.com/developer-guide/intro-plugins" |                       sudo -u $USERNAME tee $PIO_DIR/plugins/README.txt > /dev/null
echo "Directory for adding to the UI using yaml files, see docs: https://docs.pioreactor.com/developer-guide/adding-plugins-to-ui" | sudo -u $USERNAME tee $PIO_DIR/plugins/ui/README.txt > /dev/null

sudo -u $USERNAME mkdir -p $PIO_DIR/ui/


sudo -u $USERNAME mkdir -p $PIO_DIR/storage/calibrations/{stirring,od,media_pump,waste_pump,alt_media_pump}
chown -R $USERNAME:www-data $PIO_DIR/storage/calibrations/{stirring,od,media_pump,waste_pump,alt_media_pump}
chmod g+s $PIO_DIR/storage/calibrations/{stirring,od,media_pump,waste_pump,alt_media_pump}

sudo -u $USERNAME mkdir -p $PIO_DIR/experiment_profiles
chown -R $USERNAME:www-data $PIO_DIR/experiment_profiles
chmod g+s $PIO_DIR/experiment_profiles
echo "Directory for adding experiment profiles: https://docs.pioreactor.com/developer-guide/experiment-profiles" |                   sudo -u $USERNAME tee $PIO_DIR/experiment_profiles/README.txt > /dev/null


cat <<EOT >> $PIO_DIR/experiment_profiles/demo_logging_example.yaml
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


cat <<EOT >> $PIO_DIR/experiment_profiles/demo_stirring_example.yaml
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

sudo -u $USERNAME touch $PIO_DIR/unit_config.ini

# Expose web exports from /run (ephemeral). No exports under ~/.pioreactor.
# /run/pioreactor/exports is created at boot via systemd-tmpfiles.
sudo -u $USERNAME mkdir -p $PIO_DIR/web
chown -R $USERNAME:www-data $PIO_DIR/web
find $PIO_DIR/web -type d -exec chmod 2775 {} \;
find $PIO_DIR/web -type f -exec chmod 0644 {} \;


if [ "$LEADER" == "1" ]; then
    sudo apt-get install sshpass
    sudo -u $USERNAME cp /files/pioreactor/config.example.ini $PIO_DIR/config.ini

    sudo -u $USERNAME mkdir -p $PIO_DIR/exportable_datasets
    sudo -u $USERNAME cp /files/pioreactor/exportable_datasets/*.yaml $PIO_DIR/exportable_datasets/
    sudo -u $USERNAME cp -r /files/pioreactor/ui/contrib $PIO_DIR/ui




    if [ "$PIO_VERSION" == "develop" ]; then
        sudo pip3 install "pioreactor[leader_worker] @ git+https://github.com/pioreactor/pioreactor.git@develop#egg=pioreactor&subdirectory=core" --index-url https://piwheels.org/simple --extra-index-url https://pypi.org/simple
    else
        sudo pip3 install "pioreactor[leader] @ https://github.com/Pioreactor/pioreactor/releases/download/$PIO_VERSION/pioreactor-$PIO_VERSION-py3-none-any.whl" --index-url https://piwheels.org/simple --extra-index-url https://pypi.org/simple
    fi
fi


if [ "$WORKER" == "1" ]; then
    sudo apt-get install -y python3-numpy

    if [ "$PIO_VERSION" == "develop" ]; then
        sudo pip3 install "pioreactor[leader_worker] @ git+https://github.com/pioreactor/pioreactor.git@develop#egg=pioreactor&subdirectory=core" --index-url https://piwheels.org/simple --extra-index-url https://pypi.org/simple
    else
        sudo pip3 install "pioreactor[worker] @ https://github.com/Pioreactor/pioreactor/releases/download/$PIO_VERSION/pioreactor-$PIO_VERSION-py3-none-any.whl" --index-url https://piwheels.org/simple --extra-index-url https://pypi.org/simple
    fi

fi


# useful libs
sudo apt-get install -y jq
sudo apt-get install -y rsyslog
sudo apt-get install libwebpmux3 liblcms2-2 libwebpdemux2 libopenjp2-7 -y # used for Pillow


# Create/refresh symlink for static assets to package location (leaders and workers)
# Lighttpd serves /static/ from /usr/share/pioreactorui/static which points into the installed wheel.
STATIC_DIR=$(python3 - <<'PY'
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


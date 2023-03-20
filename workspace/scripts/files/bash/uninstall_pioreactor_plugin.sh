#!/bin/bash

# arg1 is the name of the plugin to uninstall
set +e
set -x
export LC_ALL=C

plugin_name=$1


leader_hostname=$(crudini --get /home/pioreactor/.pioreactor/config.ini cluster.topology leader_hostname)

if [ "$leader_hostname" == "$(hostname)" ]; then
    # delete yamls from pioreactorui
    install_folder=$(python3 -c "import site; print(site.getsitepackages()[0])")/${plugin_name//-/_}
    (cd "$install_folder"/ui/contrib/ && find ./ -type f) | awk '{print "/var/www/pioreactorui/contrib/"$1}' | xargs rm

    # TODO: remove sections from config.ini
    # this is complicated because sometimes we edit sections, instead of adding full sections. Ex: we edit [PWM] in relay plugin.

    sudo pip3 uninstall  -y "$plugin_name"
    # broadcast to cluster
    pios sync-configs
else
    sudo pip3 uninstall  -y "$plugin_name"
fi

exit 0
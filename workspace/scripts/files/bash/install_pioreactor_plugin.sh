#!/bin/bash

# arg1 is the name of the plugin to install
# arg2 is the url, wheel, etc., possible None.
set -e
set -x
export LC_ALL=C

USERNAME=pioreactor
plugin_name=$1
source=$2
install_folder=$(python3 -c "import site; print(site.getsitepackages()[0])")/${plugin_name//-/_}

if [ -n "$source" ]; then
    sudo pip3 install -U --force-reinstall -I "$source"
else
    sudo pip3 install -U --force-reinstall -I "$plugin_name"
fi



leader_hostname=$(crudini --get /home/pioreactor/.pioreactor/config.ini cluster.topology leader_hostname)

if [ "$leader_hostname" == "$(hostname)" ]; then
    # merge new config.ini
    # add any new sql, restart mqtt_to_db job, too
    if test -f "$install_folder/additional_config.ini"; then
        crudini --merge /home/$USERNAME/.pioreactor/config.ini < "$install_folder/additional_config.ini"
    fi

    # add any new sql, restart mqtt_to_db job, too
    if test -f "$install_folder/additional_sql.sql"; then
        sqlite3 "$(crudini --get /home/pioreactor/.pioreactor/config.ini storage database)" < "$install_folder/additional_sql.sql"
        sudo systemctl restart pioreactor_startup_run@mqtt_to_db_streaming.service
    fi

    # merge UI contribs
    if [ -d "$install_folder/ui/contrib/" ]; then
        rsync -a "$install_folder/ui/contrib/" /var/www/pioreactorui/contrib/
    fi

    # broadcast to cluster
    pios sync-configs
fi


exit 0

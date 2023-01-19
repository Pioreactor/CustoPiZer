#!/bin/bash

# arg1 is the name of the plugin to install
# arg2 is the url, wheel, etc., possible None.
set -e
set -x
export LC_ALL=C

USERNAME=pioreactor
plugin_name=$1
other=$2
install_folder=/usr/local/lib/python3.9/dist-packages/${plugin_name//-/_}

if [ -n "$other" ]
then
    sudo pip3 install -U --force-reinstall -I "$other"
else
    sudo pip3 install -U --force-reinstall -I "$plugin_name"
fi



leader_hostname=$(crudini --get /home/pioreactor/.pioreactor/config.ini cluster.topology leader_hostname)

if [ "$leader_hostname" == "$(hostname)" ]; then
    # merge new config.ini
    crudini --merge /home/$USERNAME/.pioreactor/config.ini < "$install_folder/additional_config.ini"

    # add any new sql, restart mqtt_to_db job, too
    if test -f "$install_folder/additional_sql.sql"; then
        sqlite3 "$(crudini --get /home/pioreactor/.pioreactor/config.ini storage database)" < "$install_folder/additional_sql.sql"
        sudo systemctl restart pioreactor_startup_run_always@mqtt_to_db_streaming.service
    fi

    # merge UI contribs
    rsync -a "$install_folder/ui/contrib/" /var/www/pioreactorui/contrib/

    # broadcast to cluster
    pios sync-configs
fi


exit 0

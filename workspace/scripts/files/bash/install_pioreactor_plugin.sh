#!/bin/bash

# arg1 is the name of the plugin to install
# arg2 is the url, wheel, etc., possible None.
set -e
set -x
export LC_ALL=C

plugin_name=$1
source=$2

clean_plugin_name=${plugin_name,,} # lower cased

clean_plugin_name_with_dashes=${clean_plugin_name//_/-}
clean_plugin_name_with_underscores=${clean_plugin_name//-/_}
install_folder=$(python3 -c "import site; print(site.getsitepackages()[0])")/${clean_plugin_name_with_underscores}
leader_hostname=$(crudini --get /home/pioreactor/.pioreactor/config.ini cluster.topology leader_hostname)

if [ -n "$source" ]; then
    sudo pip3 install -U --force-reinstall -I "$source"
else
    sudo pip3 install -U --force-reinstall -I "$clean_plugin_name_with_dashes"
fi




if [ "$leader_hostname" == "$(hostname)" ]; then
    # merge new config.ini
    # add any new sql, restart mqtt_to_db job, too
    if test -f "$install_folder/additional_config.ini"; then
        crudini --merge /home/pioreactor/.pioreactor/config.ini < "$install_folder/additional_config.ini"
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
    pios sync-configs --shared
fi

# run a post install scripts.
if test -f "$install_folder/post_install.sh"; then
    bash "$install_folder/post_install.sh"
fi


exit 0

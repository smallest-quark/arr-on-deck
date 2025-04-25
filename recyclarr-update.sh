#!/bin/bash

. ./init-conf-and-folders.sh

CONFIG_FILE="$CONTAINER_DIR/copy_to_conf/recyclarr/secrets.yml"

# Check if the secrets.yml file already exists
if [ ! -f "$CONFIG_FILE" ]; then
    read -p "Enter your Sonarr API key: " sonarr_api_key
    read -p "Enter your Radarr API key: " radarr_api_key

    # Create the configuration file
    cat <<EOL > "$CONFIG_FILE"
sonarr_base_url: http://host.containers.internal:8989
sonarr_api_key: $sonarr_api_key
radarr_base_url: http://host.containers.internal:7878
radarr_api_key: $radarr_api_key
EOL

    # Copy the contents of the copy_to_conf directory to the CONF_DIR
    cp -r "$CONTAINER_DIR/copy_to_conf/"* "$CONF_DIR"

    echo "Configuration file created and copied to $CONF_DIR."
else
    echo "The configuration file '$CONFIG_FILE' already exists. No changes made."
fi


if [ -t 0 ] ; then
    # is running in interactive shell
    read -p "Do you want to run recyclarr (yes / enter=preview): " answer
else
    answer="preview"
fi

# syncing settings from guide to sonarr and radarr
RECYCLARR_OPTS="--rm --name recyclarr \
    -e TZ=Europe/Copenhagen \
    --security-opt=no-new-privileges \
    --pull=newer \
    $SET_USER_PARAM \
    -v "$RECYCLARR_CONF_DIR:/config" \
    ghcr.io/recyclarr/recyclarr sync"

if [[ "$answer" != "yes" ]]; then
    RECYCLARR_OPTS="$RECYCLARR_OPTS --preview --debug"
fi


echo "Recyclarr (was Version 7 when this was created):"
echo " - for breaking changes see: https://recyclarr.dev/wiki/upgrade-guide/"
echo " - for templates see: https://recyclarr.dev/wiki/guide-configs/"
echo "$RECYCLARR_OPTS"

podman run $RECYCLARR_OPTS

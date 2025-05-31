#!/bin/bash

. ./init-conf-and-folders.sh

RECYCLARR_SECRETS_FILE="$CONTAINER_DIR/copy_to_conf/recyclarr/secrets.yml"
RECYCLARR_CONFIG_FILE="$CONTAINER_DIR/copy_to_conf/recyclarr/recyclarr.yml"


# Check if the secrets.yml file already exists
if [ ! -f "$RECYCLARR_SECRETS_FILE" ]; then
    read -p "Enter your Sonarr API key: " sonarr_api_key
    read -p "Enter your Radarr API key: " radarr_api_key

    # Create the configuration file
    cat <<EOL > "$RECYCLARR_SECRETS_FILE"
sonarr_base_url: http://host.containers.internal:8989
sonarr_api_key: $sonarr_api_key
radarr_base_url: http://host.containers.internal:7878
radarr_api_key: $radarr_api_key
EOL

    # Copy the contents of the copy_to_conf directory to the CONF_DIR
    cp -r "$CONTAINER_DIR/copy_to_conf/"* "$CONF_DIR"

    echo "Configuration file created and copied to $CONF_DIR."
else
    echo "The configuration file '$RECYCLARR_SECRETS_FILE' already exists. No changes made."
fi


read -p "Would you like to download 4K files? (y/n) " answer

# Normalize answer to lowercase
answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

if [[ "$answer" != "y" && "$answer" != "yes" ]]; then
    echo ""
    echo "Open $RECYCLARR_CONFIG_FILE and remove the following parts (appears twice):"
    cat <<'EOF'
        qualities:
          - name: Bluray-2160p
          - name: WEB 2160p
            qualities:
              - WEBDL-2160p
              - WEBRip-2160p
EOF

    echo "then replace all 'Bluray-2160p' with 'Bluray-1080p'"
    echo ""
fi

# Cleanup (if any temporary files persist)
[[ -f "$TMP_FILE" ]] && rm -f "$TMP_FILE"


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

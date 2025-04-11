#!/bin/bash

. ./script_customize/before-start.sh

THIS_UID=$(id -u)
THIS_GID=$(id -g)
SET_USER_PARAM="--user $THIS_UID:$THIS_GID --userns keep-id"

log() {
    # anything that is echoed will usually be part of a functions return value
    # to avoid that, only write messages to stderr
    # interestingly "$VAR" will only contain the last part, while $VAR would contain all
    echo "$1" >&2
}


ARR_PATHS=()


add_arr() {
    local item="$1"
    mkdir -p $item

    ARR_PATHS+=("$item")   # Add the item to the ARR array
    echo "$item"     # Output the item (this is how we "return" it)
}


get_conf_or_ask_for() {
    local conf_file_path="script_conf/$1"
    local conf_prompt="$2"
    local default_value="$3"

    if [[ -n "$default_value" ]]; then
       local def_text=" (Press enter for the default, which is $default_value)"
    fi

    if [[ -s "$conf_file_path" ]]; then
        cat "$conf_file_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    else
        if [ -t 1 ] ; then
            log "Aborting: Running outside of interactive shell, and thus no way to ask the user"
            exit 1
        fi

        read -p "${conf_prompt}${def_text}: " user_input
        # Trim leading and trailing whitespace/newlines
        user_input=$(echo "$user_input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Use default_value if user_input is empty
        if [[ -z "$user_input" ]]; then
            if [[ -n "$default_value" ]]; then
                user_input="$default_value"
            else
                log "Aborting: No text was entered."
                exit 1
            fi
        fi

        echo "$user_input" > "$conf_file_path"
        echo "$user_input"
    fi
}


CONTAINER_DIR="$HOME/container"
cd $CONTAINER_DIR

USE_VUETORRENT_UI="$(get_conf_or_ask_for "use-vuetorrent-ui.txt" "Enter 'true' if you want to use Vuetorrent UI for a better mobile experience" "false")"
USE_VUETORRENT_UI=${USE_VUETORRENT_UI,,} # ensure it is lowercase

if [ "$USE_VUETORRENT_UI" == "true" ]; then
    OPTIONAL_VUETORRENT_UI="-e DOCKER_MODS=ghcr.io/vuetorrent/vuetorrent-lsio-mod:latest"
    echo "If you haven't done so: Go into the WebUI settings of qBittorrent and enable the checkbox to use alternative webui, then set the path to /vuetorrent"
fi


CONF_DIR="$CONTAINER_DIR/conf"
WIREGUARD_CONF_DIR=$(add_arr "$CONF_DIR/wireguard")

LSIO_DIR="$CONF_DIR/lsio"
QBITTORRENT_CONF_DIR=$(add_arr "$LSIO_DIR/qbittorrent")
PROWLARR_CONF_DIR=$(add_arr "$LSIO_DIR/prowlarr")
SONARR_CONF_DIR=$(add_arr "$LSIO_DIR/sonarr")
RADARR_CONF_DIR=$(add_arr "$LSIO_DIR/radarr")
BAZARR_CONF_DIR=$(add_arr "$LSIO_DIR/bazarr")

RECYCLARR_CONF_DIR=$(add_arr "$CONF_DIR/recyclarr")

PLEX_CONF_DIR=$(add_arr "$CONF_DIR/plex")
PLEX_TRANSCODE_DIR=$(add_arr "$CONF_DIR/plex_tmp")

# Folder structure
# {DATA_DIR}
# ├── torrent = shared folder for torrent downloads
# │  ├── movie = downloads tagged by Radarr
# │  └── show = downloads tagged by Sonarr
# └── media = shared folder for Sonarr and Radarr files
#    ├── movie = Radarr
#    └── show = Sonarr

DATA_DIR="$(get_conf_or_ask_for "data-path.txt" "Enter the full path to where torrents, movies and shows will be stored" "$CONTAINER_DIR/data")"

if [ ! -d "$DATA_DIR" ]; then
  echo "Error: Directory $DATA_DIR does not exist. Maybe the hard drive is not mounted."
  exit 1
fi

DATA_DIR=$(add_arr "$DATA_DIR")
TORRENT_DIR=$(add_arr "$DATA_DIR/torrent")
DL_SHOWS_DIR=$(add_arr "$TORRENT_DIR/show")
DL_MOVIES_DIR=$(add_arr "$TORRENT_DIR/movie")

MEDIA_DIR="$DATA_DIR/media"
SHOWS_DIR=$(add_arr "$MEDIA_DIR/show")
MOVIES_DIR=$(add_arr "$MEDIA_DIR/movie")

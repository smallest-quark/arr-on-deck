#!/bin/bash

. ./script_customize/before-start.sh

. ./commons.sh

THIS_UID=$(id -u)
THIS_GID=$(id -g)
SET_USER_PARAM="--user $THIS_UID:$THIS_GID --userns keep-id"


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

DATA_DIR=$(add_path "$DATA_DIR")
TORRENT_DIR=$(add_path "$DATA_DIR/torrent")
DL_SHOWS_DIR=$(add_path "$TORRENT_DIR/show")
DL_MOVIES_DIR=$(add_path "$TORRENT_DIR/movie")

MEDIA_DIR="$DATA_DIR/media"
SHOWS_DIR=$(add_path "$MEDIA_DIR/show")
MOVIES_DIR=$(add_path "$MEDIA_DIR/movie")

USE_VUETORRENT_UI="$(get_conf_or_ask_for "use-vuetorrent-ui.txt" "Enter 'true' if you want to use Vuetorrent UI for a better mobile experience" "false")"
USE_VUETORRENT_UI=${USE_VUETORRENT_UI,,} # ensure it is lowercase

if [ "$USE_VUETORRENT_UI" == "true" ]; then
    OPTIONAL_VUETORRENT_UI="-e DOCKER_MODS=ghcr.io/vuetorrent/vuetorrent-lsio-mod:latest"
    echo "If you haven't done so: Go into the WebUI settings of qBittorrent and enable the checkbox to use alternative webui, then set the path to /vuetorrent"
fi

#!/bin/bash

log() {
    # anything that is echoed will usually be part of a functions return value
    # to avoid that, only write messages to stderr
    # interestingly "$VAR" will only contain the last part, while $VAR would contain all
    echo "$1" >&2
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




add_path() {
    local item="$1"
    mkdir -p "$item"
    echo "$item" # return it
}

# get the path to this script's directory
CONTAINER_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd $CONTAINER_DIR

CONF_DIR="$CONTAINER_DIR/conf"
WIREGUARD_CONF_DIR=$(add_path "$CONF_DIR/wireguard")

LSIO_DIR="$CONF_DIR/lsio"
QBITTORRENT_CONF_DIR=$(add_path "$LSIO_DIR/qbittorrent")
PROWLARR_CONF_DIR=$(add_path "$LSIO_DIR/prowlarr")
SONARR_CONF_DIR=$(add_path "$LSIO_DIR/sonarr")
RADARR_CONF_DIR=$(add_path "$LSIO_DIR/radarr")
BAZARR_CONF_DIR=$(add_path "$LSIO_DIR/bazarr")

RECYCLARR_CONF_DIR=$(add_path "$CONF_DIR/recyclarr")

PLEX_CONF_DIR=$(add_path "$CONF_DIR/plex")
PLEX_TRANSCODE_DIR=$(add_path "$CONF_DIR/plex_tmp")

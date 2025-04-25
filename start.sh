#!/bin/bash

. ./init-conf-and-folders.sh


PLEX_INI_FILE="$HOME/.var/app/tv.plex.PlexHTPC/data/plex/plex.ini"

# Check if the file exists
if [[ -f "$PLEX_INI_FILE" ]]; then
    # Use sed to replace the values
    sed -i.bak -e 's/^windowHeight=.*/windowHeight=2160/' \
               -e 's/^windowWidth=.*/windowWidth=3840/' \
               -e 's/^windowX=.*/windowX=0/' \
               -e 's/^windowY=.*/windowY=0/' "$PLEX_INI_FILE"

    echo ""
    echo "To address a Plex HTPC bug using the wrong resolution:"
    echo "$PLEX_INI_FILE was updated with the correct resolution"
    echo "A backup of the original file has been saved as $PLEX_INI_FILE.bak."
    echo ""
else
    echo "File not found: $PLEX_INI_FILE"
fi



PLEX_CLAIM="$(get_conf_or_ask_for "plex-claim.txt" "Open https://www.plex.tv/claim/ to get the plex claim token, then enter it here")"
LOCAL_SUBNETS="$(get_conf_or_ask_for "local-subnets.txt" "Open Konsole, run 'ip addr' and look for something like 192.168.1.0/24, then enter it here")"

. ./stop.sh



# Ports needed by the containers that need to be exposed
declare -A port_mapping

# Define the mappings with lowercased keys
# If you change ports here you may have to update other scripts. (e.g. recyclarr-update.sh)
port_mapping["prowlarr"]="-p 9696:9696"
port_mapping["sonarr"]="-p 8989:8989"
port_mapping["radarr"]="-p 7878:7878"
port_mapping["bazarr"]="-p 6767:6767"

all_arr_ports=""
for ports in "${port_mapping[@]}"; do
    all_arr_ports+="$ports "
done

TORRENTING_PORT="$(get_conf_or_ask_for "torrenting-port.txt" "Enter the forwarded port of your VPN if available. If this is setup, it will speed up torrenting and help others. Must not be $all_arr_ports or 8180" "6881")"

port_mapping["qbittorrent"]="-p 8180:8180 -p $TORRENTING_PORT:$TORRENTING_PORT -p $TORRENTING_PORT:$TORRENTING_PORT/udp"


DISABLE_IPV6="--sysctl net.ipv4.conf.all.src_valid_mark=1 \
  --sysctl net.ipv6.conf.all.disable_ipv6=1 \
  --sysctl net.ipv6.conf.default.disable_ipv6=1 \
  --sysctl net.ipv6.conf.lo.disable_ipv6=1 \
  --network slirp4netns:enable_ipv6=false"


# --share net        tells the pod that containers inside should share network namespace
podman pod create --name vpnDownloadPod --share net \
  $DISABLE_IPV6 \
  ${port_mapping["qbittorrent"]}


# --detach           Run the container in the background and print the new container ID
# --replace          If another container with the same name already exists, replace and remove it. The default is false.
# --pull=newer       Pull if the image on the registry is newer than the one in the local containers storage
MAIN_CONTAINER_OPTS="--detach \
  --replace \
  --restart unless-stopped \
  -e PUID=$THIS_UID \
  -e PGID=$THIS_GID \
  -e TZ=Europe/Copenhagen \
  --security-opt=no-new-privileges \
  --pull=newer"


# If you get IPv6 related errors in the log and connection cannot be
# established, edit the AllowedIPs line in your peer/client wg0.conf to
# include only 0.0.0.0/0 and not ::/0; and restart the container.
podman run --name vpn \
  --pod vpnDownloadPod \
  $MAIN_CONTAINER_OPTS \
  --cap-add NET_ADMIN \
  --cap-add SYS_MODULE \
  -v "$WIREGUARD_CONF_DIR/wg0.conf:/etc/wireguard/wg0.conf" \
  -e LOCAL_SUBNETS="$LOCAL_SUBNETS" \
  docker.io/jordanpotter/wireguard


# works for lsio images but it runs as root inside the container
#MAIN_CONTAINER_OPTS="--restart unless-stopped -e PUID=0 -e PGID=0 -e TZ=Europe/Copenhagen --pull=newer"

VPN_DOWNLOAD_CONTAINER_OPTS="--pod vpnDownloadPod \
  $MAIN_CONTAINER_OPTS \
  --network container:vpn \
  --requires vpn"

if [ "$USE_VUETORRENT_UI" == "true" ]; then
    OPTIONAL_VUETORRENT_UI="-e DOCKER_MODS=ghcr.io/vuetorrent/vuetorrent-lsio-mod:latest"
fi

# torrent
podman run --name qbittorrent \
  $VPN_DOWNLOAD_CONTAINER_OPTS \
  -e WEBUI_PORT=8180 \
  -e TORRENTING_PORT="$TORRENTING_PORT" \
  $OPTIONAL_VUETORRENT_UI \
  -v "$QBITTORRENT_CONF_DIR:/config:Z" \
  -v "$TORRENT_DIR:/data/torrent" \
  docker.io/linuxserver/qbittorrent:latest


# End of VPN-procted pod
###############################################################################


podman pod create --name arrPod --share net \
  $DISABLE_IPV6 \
  $all_arr_ports

ARR_CONTAINER_OPTS="--pod arrPod \
  $MAIN_CONTAINER_OPTS"

# indexer
podman run --name prowlarr \
  $ARR_CONTAINER_OPTS \
  -v "$PROWLARR_CONF_DIR:/config:Z" \
  docker.io/linuxserver/prowlarr:latest


# shows
podman run --name sonarr \
  $ARR_CONTAINER_OPTS \
  --requires prowlarr \
  -v "$SONARR_CONF_DIR:/config:Z" \
  -v "$DATA_DIR:/data:z" \
  docker.io/linuxserver/sonarr:latest


# movies
podman run --name radarr \
  $ARR_CONTAINER_OPTS \
  --requires prowlarr \
  -v "$RADARR_CONF_DIR:/config:Z" \
  -v "$DATA_DIR:/data:z" \
  docker.io/linuxserver/radarr:latest


# subtitles
podman run --name bazarr \
  $ARR_CONTAINER_OPTS \
  --requires sonarr,radarr \
  -v "$BAZARR_CONF_DIR:/config:Z" \
  -v "$MOVIES_DIR:/data/media/movie:z" \
  -v "$SHOWS_DIR:/data/media/show:z" \
  docker.io/linuxserver/bazarr:latest

# End of *arr pod
###############################################################################


# media server
podman run --name=plex \
  $MAIN_CONTAINER_OPTS \
  --network=host \
  -e PLEX_CLAIM="$PLEX_CLAIM" \
  -e PLEX_UID="$THIS_UID" \
  -e PLEX_GID="$THIS_GID" \
  -v "$PLEX_CONF_DIR:/config" \
  -v "$PLEX_TRANSCODE_DIR:/transcode" \
  -v "$MEDIA_DIR:/data" \
  --restart always \
  docker.io/plexinc/pms-docker

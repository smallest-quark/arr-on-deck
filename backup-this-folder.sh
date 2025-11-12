#!/bin/bash

. ./commons.sh

CONTAINER_DIR="${CONTAINER_DIR%/}/"
BACKUP_PATH="$(get_conf_or_ask_for "backup-path.txt" "Enter the full path to where backups will be stored")"
BACKUP_PATH="${BACKUP_PATH%/}/"

echo "We want to backup $(realpath "$CONTAINER_DIR") to $(realpath "$BACKUP_PATH")"
echo "It is highly recommended to shutdown all containers before doing this, as otherwise databases and configs may be saved in an inconsistent state!"


PMS_PATH="$PLEX_CONF_DIR/Library/Application Support/Plex Media Server"

# make exclude paths relative
PLEX_TRANSCODE_DIR=$(realpath --relative-to="$CONTAINER_DIR" "$PLEX_TRANSCODE_DIR")
PMS_PATH=$(realpath --relative-to="$CONTAINER_DIR" "$PMS_PATH")

DRY_RUN=""
if [ -t 0 ] ; then
    read -p "Do you want to perform a dry-run first? (y/N): " responses
    if [[ "$responses" =~ ^[Yy]$ ]]; then
        DRY_RUN="--dry-run"
        echo "Running rsync in dry-run mode..."
    fi
fi

# Rsync options:
#   -a: archive mode (preserves permissions, symlinks, etc.)
#   -v: verbose output
#   -z: compress file data during the transfer
#   --delete: delete extraneous files from destination dirs
#   --exclude: exclude patterns/files/dirs from the backup

rsync $DRY_RUN -avz --delete \
  --exclude="$PLEX_TRANSCODE_DIR" \
  --exclude="$PMS_PATH/Metadata" \
  --exclude="$PMS_PATH/Media" \
  --exclude="$PMS_PATH/Cache" \
  --exclude="$PMS_PATH/Cache" \
  --exclude="$PMS_PATH/Logs" \
  --exclude="$PMS_PATH/Crash Reports" \
  --exclude='**/cache/' \
  --exclude='**/Caches/' \
  --exclude='**/MediaCover/' \
  --exclude='**/logs/' \
  --exclude='**/log/' \
  --exclude='**/.cache/' \
  --exclude='OLD' \
  --exclude='nohup.out' \
  --exclude='*.log' \
  --exclude="conf/recyclarr" \
  "$CONTAINER_DIR" "$BACKUP_PATH" 2>&1 | tee backup-this-folder.log


if [ -t 0 ] ; then
    paplay /usr/share/sounds/freedesktop/stereo/complete.oga
    echo ""
    echo "See backup-this-folder.log in case the log is cut off."
fi

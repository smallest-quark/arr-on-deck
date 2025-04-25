#!/bin/bash

# Define source and destination directories
SOURCE="/run/media/deck/media/data/media/"
DESTINATION="/run/media/deck/media_backup/data/media/"

echo "We want to backup $(realpath "$SOURCE") to $(realpath "$DESTINATION")"

DRY_RUN=""
if [ -t 0 ] ; then
    read -p "Do you want to perform a dry-run first? (y/N): " responses
    if [[ "$responses" =~ ^[Yy]$ ]]; then
        DRY_RUN="--dry-run"
        echo "Running rsync in dry-run mode..."
    fi
fi

# Use rsync to synchronize the directories
rsync $DRY_RUN --recursive -v --no-perms --delete "$SOURCE" "$DESTINATION" 2>&1 | tee backup-media-folder.log

if [ -t 0 ] ; then
   paplay /usr/share/sounds/freedesktop/stereo/complete.oga
   echo ""
   echo "See backup-media-folder.log in case the log is cut off."
fi

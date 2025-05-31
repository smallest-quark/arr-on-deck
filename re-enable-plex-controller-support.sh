#!/bin/bash

cd "$HOME/.var/app/tv.plex.PlexHTPC/data/plex/inputmaps/"
ls *.json

if [ -t 0 ] ; then
    # is running in interactive shell
    read -p "Write 'yes' if you are okay with re-enabling plex controller support (which we do by deleting the above custom configs): " answer
else
    answer="yes"
fi

if [[ "$answer" == "yes" ]]; then
    rm *.json
fi

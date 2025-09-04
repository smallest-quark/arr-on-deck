#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# TODO: Add CHECK ask user otherwise cause problem (sudden stopping)

SERVICE_FILE="$HOME/.config/systemd/user/arr-on-deck-manager.service"

systemctl --user stop arr-on-deck-manager || echo "Service arr-on-deck-manager was not running."

systemctl --user disable arr-on-deck-manager || echo "Service arr-on-deck-manager was not enabled."

# Remove the service file if it exists.
if [ -f "$SERVICE_FILE" ]; then
    rm "$SERVICE_FILE"
    echo "Service file removed from: $SERVICE_FILE"
else
    echo "Service file does not exist: $SERVICE_FILE"
fi

# Reload the systemd user daemon so it notices the removed service.
systemctl --user daemon-reload

echo "Service arr-on-deck-manager uninstalled."


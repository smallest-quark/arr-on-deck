#!/bin/bash

. ./commons.sh

# Exit immediately if a command exits with a non-zero status.
set -e

SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/arr-on-deck-manager.service"

# Create the systemd user configuration directory if it doesn't exist.
mkdir -p "$SERVICE_DIR"

# Create (or overwrite) the service file with the correct contents.
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Arr-On-Deck-Manager

[Service]
Type=simple
ExecStart=/usr/bin/python3 "$CONTAINER_DIR/serve.py"
Restart=on-failure
RestartSec=1

[Install]
WantedBy=default.target
EOF

echo "Service file created at: $SERVICE_FILE"

# Reload the systemd user daemon so it notices the new service.
systemctl --user daemon-reload

systemctl --user enable arr-on-deck-manager
systemctl --user start arr-on-deck-manager

echo "Service arr-on-deck-manager installed, enabled, and started."


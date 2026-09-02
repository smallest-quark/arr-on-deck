#!/usr/bin/env bash

. ./commons.sh

# Exit immediately if a command exits with a non-zero status.
set -e

SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/arr-on-deck-manager.service"

# Create the systemd user configuration directory if it doesn't exist.
mkdir -p "$SERVICE_DIR"

# Create (or overwrite) the service file with the correct contents.
# If Type= is omitted or explicitly set to simple, systemd considers the service started immediately after the main process forks off. It marks the unit as active (running) in fractions of a second. Under Type=exec, systemd considers the unit started as soon as the binary execution call succeeds.
# TimeoutStartSec is for giving the service more time to start
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


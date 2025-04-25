#!/bin/bash

if [ -z "$DATA_DIR" ]; then
    . ./init-conf-and-folders.sh
fi

ensure_permissions() {
    # Ensure the whole directory and all its subdirectories have group read, write, executable
    # (necessary for entering directories), and setuid permissions.

    # Change permissions and group ownership for directories
    sudo find "$1" -type d -exec chmod g+rwxs {} + -exec chown :g100999 {} +

    # Ensure all files in all subdirectories have group read and write permissions and change group ownership
    sudo find "$1" -type f -exec chmod g+rw {} + -exec chown :g100999 {} +
}


ensure_permissions "$LSIO_DIR"
ensure_permissions "$PLEX_CONF_DIR"
ensure_permissions "$DATA_DIR"

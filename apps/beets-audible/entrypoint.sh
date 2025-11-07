#!/bin/bash
set -e

# Ensure virtualenv is in PATH
export PATH="/opt/venv/bin:$PATH"

# Ensure /config exists and is writable
mkdir -p /config
chmod u+rwx /config

# # Initialize Beets config if not exists
# if [ ! -f "/config/config.yaml" ]; then
#     echo "[INFO] Initializing default Beets config..."
#     beet config -p > /config/config.yaml || true
# fi

# Ensure database is writable
touch /config/library.db || true
chmod u+rw /config/library.db

# Start Beets (adjust your command)
echo "[INFO] Starting Beets..."
if [ "$1" = "web" ]; then
    echo "[INFO] Starting Beets web interface..."
    exec beet web
elif [ $# -eq 0 ]; then
    echo "[INFO] No command provided, keeping container alive..."
    tail -f /dev/null
else
    echo "[INFO] Running Beets command: beet $@"
    exec beet "$@"
fi

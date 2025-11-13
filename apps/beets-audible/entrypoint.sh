#!/bin/bash
set -e

export PATH="/opt/venv/bin:$PATH"

# Ensure writable /config exists (PVC)
mkdir -p /config
chmod u+rwx /config

# Copy ConfigMap config.yaml into writable /config if it doesn't exist
if [ ! -f /config/config.yaml ]; then
    echo "[INFO] Copying default config.yaml into /config..."
    cp /tmp/config/config.yaml /config/config.yaml || true
fi

# Ensure database is writable
touch /config/library.db || true
chmod u+rw /config/library.db

# Start Beets
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

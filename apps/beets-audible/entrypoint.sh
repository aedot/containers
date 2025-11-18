#!/bin/bash
set -e
export PATH="/opt/venv/bin:$PATH"

# Safety check - refuse to run as root
if [ "$(id -u)" = "0" ]; then
    echo "[ERROR] This container must not run as root for security reasons."
    echo "[ERROR] Please run with --user or configure your orchestrator to use a non-root user."
    exit 1
fi

echo "[INFO] Running as user $(whoami) (UID: $(id -u), GID: $(id -g))"

# Ensure writable /config exists (PVC)
mkdir -p /config || {
    echo "[ERROR] Cannot create /config directory. Check volume permissions."
    echo "[INFO] If using Kubernetes, ensure the PVC has correct permissions or use an initContainer."
    exit 1
}

# Copy ConfigMap config.yaml into writable /config if it doesn't exist
if [ ! -f /config/config.yaml ]; then
    echo "[INFO] Copying default config.yaml into /config..."
    cp /tmp/config/config.yaml /config/config.yaml 2>/dev/null || {
        echo "[WARN] Could not copy default config.yaml (may not exist or no permissions)"
    }
fi

# Ensure database is writable
touch /config/library.db 2>/dev/null || {
    echo "[WARN] Could not create/update library.db"
}

# Start Beets
echo "[INFO] Starting Beets..."
if [ "$1" = "web" ]; then
    echo "[INFO] Starting Beets web interface..."
    exec beet web
elif [ $# -eq 0 ]; then
    echo "[INFO] No command provided, keeping container alive..."
    exec tail -f /dev/null
else
    echo "[INFO] Running Beets command: beet $@"
    exec beet "$@"
fi

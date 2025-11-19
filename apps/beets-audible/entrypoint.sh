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
if [ ! -d /config ]; then
    mkdir -p /config || {
        echo "[ERROR] Cannot create /config directory. Check volume permissions."
        echo "[INFO] If using Kubernetes, ensure the PVC has correct permissions or use an initContainer."
        exit 1
    }
fi

# Verify /config is writable
if [ ! -w /config ]; then
    echo "[ERROR] /config directory exists but is not writable by UID $(id -u)"
    echo "[INFO] Current /config permissions: $(ls -ld /config)"
    echo "[INFO] Please ensure the volume is owned by UID=$(id -u) and GID=$(id -g)"
    echo "[INFO] Or use an initContainer in Kubernetes to fix permissions"
    exit 1
fi

# Copy ConfigMap config.yaml into writable /config if it doesn't exist
if [ ! -f /config/config.yaml ]; then
    echo "[INFO] No config.yaml found in /config"
    if [ -f /tmp/config/config.yaml ]; then
        echo "[INFO] Copying default config.yaml from /tmp/config/ into /config..."
        cp /tmp/config/config.yaml /config/config.yaml || {
            echo "[WARN] Could not copy default config.yaml (permission denied)"
        }
    else
        echo "[INFO] Creating minimal default config.yaml..."
        cat > /config/config.yaml <<EOF
directory: /audiobooks
library: /config/library.db
EOF
    fi
fi

# Ensure database is writable
touch /config/library.db 2>/dev/null || {
    echo "[WARN] Could not create/update library.db (may not have write permissions)"
}

# Verify beets is accessible
if ! command -v beet &> /dev/null; then
    echo "[ERROR] beet command not found in PATH"
    echo "[INFO] Current PATH: $PATH"
    exit 1
fi

# Start Beets
echo "[INFO] Starting Beets..."
if [ $# -eq 0 ]; then
    echo "[INFO] No command provided, keeping container alive..."
    exec tail -f /dev/null
elif [ "$1" = "web" ]; then
    echo "[INFO] Starting Beets web interface..."
    exec beet web
elif [ "$1" = "bash" ] || [ "$1" = "sh" ] || [ "$1" = "/bin/bash" ] || [ "$1" = "/bin/sh" ]; then
    echo "[INFO] Starting interactive shell..."
    exec "$@"
else
    # Check if the first argument is a beet command or looks like a system command
    case "$1" in
        beet|/opt/venv/bin/beet)
            # Already prefixed with beet, execute as-is
            echo "[INFO] Executing: $@"
            exec "$@"
            ;;
        import|ls|list|modify|move|remove|stats|update|version|config|help|*)
            # Assume it's a beet subcommand
            echo "[INFO] Running Beets command: beet $@"
            exec beet "$@"
            ;;
    esac
fi

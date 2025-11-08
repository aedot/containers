#!/bin/bash
# Exit on errors, but show commands for debugging
set -ex

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*"
}

# --------------------------
# User creation
# --------------------------
user_name="autom4b"
user_id="1001"
group_id="100"

if ! id -u "${PUID}" &>/dev/null; then
    if [[ "${PUID}" =~ ^[0-9]+$ ]]; then
        user_id="${PUID}"
    else
        user_name="${PUID}"
    fi

    if [[ "${PGID}" =~ ^[0-9]+$ ]]; then
        group_id="${PGID}"
    fi

    addgroup --gid "${group_id}" "${user_name}"
    adduser --uid "${user_id}" --gid "${group_id}" --disabled-password --gecos "" "${user_name}"
    log "Created user ${user_name} with UID ${user_id} and GID ${group_id}"
fi

# Command prefix for permissions
cmd_prefix=""
if [[ -n "${PUID}" ]]; then
    cmd_prefix="gosu ${user_name}"
fi

# --------------------------
# Folder setup
# --------------------------
INPUT_FOLDER="${INPUT_FOLDER:-/temp/merge}"
OUTPUT_FOLDER="${OUTPUT_FOLDER:-/temp/untagged}"
ORIGINAL_FOLDER="${ORIGINAL_FOLDER:-/temp/recentlyadded}"
FIXIT_FOLDER="${FIXIT_FOLDER:-/temp/fix}"
BACKUP_FOLDER="${BACKUP_FOLDER:-/temp/backup}"
BIN_FOLDER="${BIN_FOLDER:-/temp/delete}"

mkdir -p "$INPUT_FOLDER" "$OUTPUT_FOLDER" "$ORIGINAL_FOLDER" "$FIXIT_FOLDER" "$BACKUP_FOLDER" "$BIN_FOLDER"
chown -R "${user_id}:${group_id}" /temp

# --------------------------
# CPU and sleep settings
# --------------------------
CPUcores="${CPU_CORES:-$(nproc)}"
sleeptime="${SLEEPTIME:-1m}"

log "Using $CPUcores CPU cores"
log "Sleep interval set to $sleeptime"

# --------------------------
# Main loop
# --------------------------
cd "$INPUT_FOLDER" || exit 1
shopt -s nullglob

while true; do
    log "Checking $ORIGINAL_FOLDER for files..."

    # Backup
    if [ "$MAKE_BACKUP" != "N" ]; then
        files=( "$ORIGINAL_FOLDER"/* )
        if [ ${#files[@]} -gt 0 ]; then
            log "Backing up $ORIGINAL_FOLDER -> $BACKUP_FOLDER"
            cp -Ru "${files[@]}" "$BACKUP_FOLDER"
        fi
    fi

    # Flatten and move files (existing logic)
    # ... (keep your full processing loop here)

    log "Sleeping $sleeptime..."
    sleep "$sleeptime"
done

shopt -u nullglob

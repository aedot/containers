#!/bin/bash
set -e

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
    echo "Created user ${user_name} with UID ${user_id} and GID ${group_id}"
fi

cmd_prefix=""
if [[ -n "${PUID}" ]]; then
    cmd_prefix="su-exec ${user_name}"
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

echo "Using $CPUcores CPU cores"
echo "Sleep interval set to $sleeptime"

# --------------------------
# Main loop
# --------------------------
cd "$INPUT_FOLDER" || exit 1
shopt -s nullglob

while true; do
    # Backup
    if [ "$MAKE_BACKUP" != "N" ]; then
        files=( "$ORIGINAL_FOLDER"/* )
        if [ ${#files[@]} -gt 0 ]; then
            echo "Backing up $ORIGINAL_FOLDER -> $BACKUP_FOLDER"
            cp -Ru "${files[@]}" "$BACKUP_FOLDER"
        fi
    fi

    # Flatten single-file folders
    for file in "$ORIGINAL_FOLDER"/*.{mp3,m4b}; do
        [ -f "$file" ] || continue
        mkdir -p "${file%.*}"
        mv "$file" "${file%.*}"
    done

    # Flatten nested folders 3+ levels deep
    for f in $(find "$ORIGINAL_FOLDER" -mindepth 3 -type f \( -name '*.mp3' -o -name '*.m4b' -o -name '*.m4a' \)); do
        rel="${f#$ORIGINAL_FOLDER/}"
        IFS='/' read -ra parts <<< "$rel"
        [ ${#parts[@]} -lt 4 ] && continue
        new_name="${parts[-1]}"
        parent="${parts[3]}"
        if [ ${#parts[@]} -gt 4 ]; then
            for ((i=4; i<${#parts[@]}-1; i++)); do
                new_name="${parts[i]} - $new_name"
            done
        fi
        new_path="$ORIGINAL_FOLDER/$parent/$new_name"
        mkdir -p "$(dirname "$new_path")"
        mv -v "$f" "$new_path"
    done

    # Move multi-file folders to input
    for d in "$ORIGINAL_FOLDER"/*/; do
        files=( "$d"* )
        if [ ${#files[@]} -gt 1 ]; then
            mv "$d" "$INPUT_FOLDER"
        fi
    done

    # Move single files
    for ext in mp3 m4b m4a mp4 ogg; do
        for f in "$ORIGINAL_FOLDER"/*."$ext"; do
            [ -f "$f" ] || continue
            dest="$INPUT_FOLDER"
            [ "$ext" != "mp3" ] && dest="$OUTPUT_FOLDER"
            mv "$f" "$dest"
        done
    done

    # Clear BIN_FOLDER
    rm -rf "$BIN_FOLDER"/*

    # Process folders
    for book in "$INPUT_FOLDER"*/; do
        [ -d "$book" ] || continue
        bookname=$(basename "$book")
        mpthree=$(find "$book" -maxdepth 2 -type f \( -name '*.mp3' -o -name '*.m4b' \) | head -n 1)
        outdir="$OUTPUT_FOLDER/$bookname"
        mkdir -p "$outdir"
        logfile="$outdir/$bookname.log"
        m4bfile="$outdir/$bookname.m4b"

        chapters=$(ls "$book"*chapters.txt 2>/dev/null | wc -l)
        if [ "$chapters" -ne 0 ]; then
            echo "Adjusting chapters for $bookname"
            mp4chaps -i "$book"*chapters.txt
            mv "$book" "$outdir"
        else
            echo "Converting $bookname -> $m4bfile"
            bit=$(ffprobe -hide_banner -loglevel 0 -of flat -i "$mpthree" -select_streams a -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1)
            m4b-tool merge "$book" -n -q --audio-bitrate="$bit" --skip-cover --use-filenames-as-chapters --no-chapter-reindexing --audio-codec=libfdk_aac --jobs="$CPUcores" --output-file="$m4bfile" --logfile="$logfile"
            mv "$book" "$BIN_FOLDER"
        fi
    done

    echo "Sleeping $sleeptime..."
    sleep "$sleeptime"
done
shopt -u nullglob

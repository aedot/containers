#!/bin/bash
set -euxo pipefail

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*"
}

# Default folders
INPUT_FOLDER="${INPUT_FOLDER:-/temp/merge}"
OUTPUT_FOLDER="${OUTPUT_FOLDER:-/temp/untagged}"
ORIGINAL_FOLDER="${ORIGINAL_FOLDER:-/temp/recentlyadded}"
FIXIT_FOLDER="${FIXIT_FOLDER:-/temp/fix}"
BACKUP_FOLDER="${BACKUP_FOLDER:-/temp/backup}"
BIN_FOLDER="${BIN_FOLDER:-/temp/delete}"

CPU_CORES="${CPU_CORES:-$(nproc)}"
SLEEPTIME="${SLEEPTIME:-5m}"
MAKE_BACKUP="${MAKE_BACKUP:-Y}"

M4B_EXT=".m4b"
LOG_EXT=".log"

# Ensure folders exist
mkdir -p "$INPUT_FOLDER" "$OUTPUT_FOLDER" "$ORIGINAL_FOLDER" "$FIXIT_FOLDER" "$BACKUP_FOLDER" "$BIN_FOLDER"

log "Using $CPU_CORES CPU cores"
log "Sleep interval set to $SLEEPTIME"

shopt -s nullglob

while true; do
    # Backup
    if [ "$MAKE_BACKUP" != "N" ]; then
        files=( "$ORIGINAL_FOLDER"/* )
        if [ ${#files[@]} -gt 0 ]; then
            log "Backing up $ORIGINAL_FOLDER -> $BACKUP_FOLDER"
            cp -Ru "${files[@]}" "$BACKUP_FOLDER"
        else
            log "No files to backup in $ORIGINAL_FOLDER"
        fi
    else
        log "Skipping backup"
    fi

    # Flatten single-file folders
    for file in "$ORIGINAL_FOLDER"/*.{mp3,m4b}; do
        [ -f "$file" ] || continue
        mkdir -p "${file%.*}"
        mv "$file" "${file%.*}"
    done

    # Flatten nested folders 3+ levels
    find "$ORIGINAL_FOLDER" -mindepth 3 -type f \( -name '*.mp3' -o -name '*.m4b' -o -name '*.m4a' \) -print0 |
    while IFS= read -r -d '' file; do
        relative_path="${file#$ORIGINAL_FOLDER/}"
        IFS='/' read -ra parts <<< "$relative_path"
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
        mv -v "$file" "$new_path"
    done

    # Move multi-file folders to input
    for d in "$ORIGINAL_FOLDER"/*/; do
        files=( "$d"* )
        [ ${#files[@]} -gt 1 ] && mv "$d" "$INPUT_FOLDER"
    done

    # Move single files
    for ext in mp3 m4b m4a mp4 ogg; do
        files=( "$ORIGINAL_FOLDER"/*."$ext" )
        for f in "${files[@]}"; do
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
        [ -z "$mpthree" ] && { log "No audio files in $book, skipping"; continue; }

        outdir="$OUTPUT_FOLDER/$bookname"
        mkdir -p "$outdir"
        logfile="$outdir/$bookname$LOG_EXT"
        m4bfile="$outdir/$bookname$M4B_EXT"

        chapters=$(ls "$book"*chapters.txt 2>/dev/null | wc -l)
        if [ "$chapters" -ne 0 ]; then
            log "Adjusting chapters for $bookname"
            mp4chaps -i "$book"*chapters.txt
            mv "$book" "$outdir"
        else
            log "Converting $bookname -> $m4bfile"
            bit=$(ffprobe -hide_banner -loglevel 0 -of flat -i "$mpthree" -select_streams a -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1)
            m4b-tool merge "$book" -n -q --audio-bitrate="$bit" --skip-cover --use-filenames-as-chapters --no-chapter-reindexing --audio-codec=libfdk_aac --jobs="$CPU_CORES" --output-file="$m4bfile" --logfile="$logfile"
            mv "$book" "$BIN_FOLDER"
        fi
    done

    log "Sleeping $SLEEPTIME..."
    sleep "$SLEEPTIME"
done

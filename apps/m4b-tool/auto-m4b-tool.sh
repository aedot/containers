#!/bin/bash
# Auto M4B Tool - Containerized Version
set -e

# -------------------------
# Configuration
# -------------------------
inputfolder="${INPUT_FOLDER:-/temp/merge}"
outputfolder="${OUTPUT_FOLDER:-/temp/untagged}"
originalfolder="${ORIGINAL_FOLDER:-/temp/recentlyadded}"
fixitfolder="${FIXIT_FOLDER:-/temp/fix}"
backupfolder="${BACKUP_FOLDER:-/temp/backup}"
binfolder="${BIN_FOLDER:-/temp/delete}"
m4bend=".m4b"
logend=".log"
sleeptime="${SLEEPTIME:-3m}"
CPU_CORES="${CPU_CORES:-$(nproc)}"
MAKE_BACKUP="${MAKE_BACKUP:-Y}"

# Normalize paths (remove trailing slashes for consistency)
inputfolder="${inputfolder%/}/"
outputfolder="${outputfolder%/}/"
originalfolder="${originalfolder%/}/"
fixitfolder="${fixitfolder%/}/"
backupfolder="${backupfolder%/}/"
binfolder="${binfolder%/}/"

# -------------------------
# Startup Info
# -------------------------
echo "==================================="
echo "M4B-Tool Auto Processor"
echo "==================================="
echo "Input:       $inputfolder"
echo "Output:      $outputfolder"
echo "Original:    $originalfolder"
echo "Backup:      $backupfolder"
echo "Fix-it:      $fixitfolder"
echo "Bin:         $binfolder"
echo "Sleep:       $sleeptime"
echo "CPU cores:   $CPU_CORES"
echo "Make backup: $MAKE_BACKUP"
echo "User:        $(id)"
echo "==================================="

# -------------------------
# Ensure folder structure
# -------------------------
echo "Creating folder structure..."
mkdir -p "$inputfolder" "$outputfolder" "$originalfolder" "$fixitfolder" "$backupfolder" "$binfolder" || {
    echo "ERROR: Failed to create directories. Check volume permissions."
    exit 1
}

# -------------------------
# Main loop
# -------------------------
while true; do
    echo ""
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting processing cycle..."

    # -------------------------
    # Backup original folder
    # -------------------------
    if [ "$MAKE_BACKUP" == "N" ]; then
        echo "Skipping backup (MAKE_BACKUP=N)"
    else
        echo "Backing up $originalfolder -> $backupfolder"
        if compgen -G "${originalfolder}*" > /dev/null; then
            cp -Ru "$originalfolder"* "$backupfolder" 2>/dev/null || echo "Backup completed with warnings"
        else
            echo "Backup skipped: nothing to backup"
        fi
    fi

    # -------------------------
    # Organize single files into folders
    # -------------------------
    echo "Organizing single files into folders..."
    shopt -s nullglob
    for file in "$originalfolder"*.{mp3,m4b,m4a}; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")
            folder="${originalfolder}${filename%.*}"
            echo "Creating folder: $folder"
            mkdir -p "$folder"
            mv -v "$file" "$folder/"
        fi
    done
    shopt -u nullglob

    # -------------------------
    # Flatten deeply nested folders (>=3 levels)
    # -------------------------
    echo "Flattening nested folders..."
    find "$originalfolder" -mindepth 3 -type f \( -iname '*.mp3' -o -iname '*.m4b' -o -iname '*.m4a' \) -print0 2>/dev/null |
    while IFS= read -r -d '' file; do
        rel="${file#$originalfolder}"
        IFS='/' read -ra parts <<< "$rel"
        if [ ${#parts[@]} -ge 3 ]; then
            filename="${parts[-1]}"
            grandparent="${parts[0]}"
            new_filename=""
            for ((i=1;i<${#parts[@]}-1;i++)); do
                new_filename+="${parts[i]} - "
            done
            new_filename+="$filename"
            new_path="${originalfolder}${grandparent}/${new_filename}"
            mkdir -p "$(dirname "$new_path")"
            echo "Flattening: $file -> $new_path"
            mv "$file" "$new_path" 2>/dev/null || echo "Warning: Could not move $file"
        fi
    done

    # -------------------------
    # Move multi-file audiobook folders to inputfolder
    # -------------------------
    echo "Moving multi-file audiobook folders to input..."
    find "$originalfolder" -maxdepth 2 -mindepth 2 -type f \( -iname '*.mp3' -o -iname '*.m4b' -o -iname '*.m4a' \) -print0 2>/dev/null |
    xargs -0 -r -n 1 dirname | sort | uniq -c | grep -E -v '^ *1 ' | sed 's/^ *[0-9]* //' |
    while read -r folder; do
        echo "Moving folder: $folder -> $inputfolder"
        mv "$folder" "$inputfolder" 2>/dev/null || echo "Warning: Could not move $folder"
    done

    # -------------------------
    # Move single files to input/output
    # -------------------------
    echo "Moving single MP3 folders to merge folder..."
    find "$originalfolder" -maxdepth 2 -type f -iname '*.mp3' -printf "%h\0" 2>/dev/null |
    sort -zu | xargs -0 -r -I {} mv -v {} "$inputfolder" 2>/dev/null || true

    echo "Moving single M4B/M4A/MP4/OGG folders to output..."
    find "$originalfolder" -maxdepth 2 -type f \( -iname '*.m4b' -o -iname '*.m4a' -o -iname '*.mp4' -o -iname '*.ogg' \) -printf "%h\0" 2>/dev/null |
    sort -zu | xargs -0 -r -I {} mv -v {} "$outputfolder" 2>/dev/null || true

    # -------------------------
    # Clear bin folder
    # -------------------------
    echo "Clearing bin folder..."
    rm -rf "${binfolder}"* 2>/dev/null || true

    # -------------------------
    # Process folders in inputfolder
    # -------------------------
    cd "$inputfolder" || exit

    if compgen -G "*/" > /dev/null; then
        for book in */; do
            book="${book%/}"
            [[ -d "$book" ]] || continue

            echo ""
            echo "Processing: $book"
            mkdir -p "${outputfolder}${book}"

            # Find first audio file
            mpthree=$(find "$book" -maxdepth 2 -type f \( -iname '*.mp3' -o -iname '*.m4b' -o -iname '*.m4a' \) 2>/dev/null | head -n1)

            if [[ -z "$mpthree" ]]; then
                echo "Warning: No audio files found in $book, skipping..."
                continue
            fi

            m4bfile="${outputfolder}${book}/${book}${m4bend}"
            logfile="${outputfolder}${book}/${book}${logend}"

            # Determine bitrate if MP3
            if [[ "$mpthree" == *.mp3 ]]; then
                echo "Detecting bitrate for MP3..."
                bit=$(ffprobe -hide_banner -loglevel error -of flat -i "$mpthree" -select_streams a -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 2>/dev/null || echo "64000")
                bit=${bit%%.*}
                [[ -z "$bit" || "$bit" -eq 0 ]] && bit=64000
                echo "Detected bitrate: $bit"

                echo "Merging $book -> $m4bfile"
                m4b-tool merge "$book" -n -q \
                    --audio-bitrate="$bit" \
                    --skip-cover \
                    --use-filenames-as-chapters \
                    --no-chapter-reindexing \
                    --audio-codec=libfdk_aac \
                    --jobs="$CPU_CORES" \
                    --output-file="$m4bfile" \
                    --logfile="$logfile" || {
                        echo "ERROR: m4b-tool merge failed for $book"
                        continue
                    }
            else
                # Already an M4B/M4A, just copy
                echo "File already in M4B/M4A format, copying..."
                cp -v "$mpthree" "$m4bfile" || {
                    echo "ERROR: Failed to copy $mpthree"
                    continue
                }
            fi

            # -------------------------
            # Generate chapters.txt
            # -------------------------
            if [[ -f "$m4bfile" ]]; then
                echo "Generating chapters -> ${outputfolder}${book}/chapters.txt"
                m4b-tool chapters "$m4bfile" > "${outputfolder}${book}/chapters.txt" 2>/dev/null || echo "Warning: Chapters generation failed"
            fi

            # -------------------------
            # Move processed folder to bin
            # -------------------------
            echo "Moving processed folder to bin..."
            mv "${inputfolder}${book}" "$binfolder" 2>/dev/null || echo "Warning: Could not move to bin"

            echo "✓ Completed: $book"
        done
    else
        echo "No folders to process."
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cycle complete. Sleeping $sleeptime..."
    sleep "$sleeptime"
done

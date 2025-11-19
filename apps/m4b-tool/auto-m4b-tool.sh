#!/bin/bash
# Auto M4B Tool - Containerized Version
set -e

# -------------------------
# Configuration
# -------------------------
inputfolder="${INPUT_FOLDER:-"/temp/merge/"}"
outputfolder="${OUTPUT_FOLDER:-"/temp/untagged/"}"
originalfolder="${ORIGINAL_FOLDER:-"/temp/recentlyadded/"}"
fixitfolder="${FIXIT_FOLDER:-"/temp/fix"}"
backupfolder="${BACKUP_FOLDER:-"/temp/backup/"}"
binfolder="${BIN_FOLDER:-"/temp/delete/"}"
m4bend=".m4b"
logend=".log"
sleeptime="${SLEEPTIME:-3m}"
CPU_CORES="${CPU_CORES:-$(nproc)}"
MAKE_BACKUP="${MAKE_BACKUP:-Y}"

# Ensure folder structure
mkdir -p "$inputfolder" "$outputfolder" "$originalfolder" "$fixitfolder" "$backupfolder" "$binfolder"

echo "Input: $inputfolder"
echo "Output: $outputfolder"
echo "Original: $originalfolder"
echo "Backup: $backupfolder"
echo "Sleep interval: $sleeptime"
echo "CPU cores: $CPU_CORES"

# -------------------------
# Main loop
# -------------------------
while true; do

    # -------------------------
    # Backup original folder
    # -------------------------
    if [ "$MAKE_BACKUP" == "N" ]; then
        echo "Skipping backup"
    else
        echo "Backing up $originalfolder -> $backupfolder"
        cp -Ru "$originalfolder"* "$backupfolder" 2>/dev/null || echo "Backup skipped: nothing to backup"
    fi

    # -------------------------
    # Organize single files into folders
    # -------------------------
    echo "Organizing single files into folders..."
    shopt -s nullglob
    for file in "$originalfolder"*.{mp3,m4b}; do
        if [[ -f "$file" ]]; then
            mkdir -p "${file%.*}"
            mv "$file" "${file%.*}/"
        fi
    done
    shopt -u nullglob

    # -------------------------
    # Flatten deeply nested folders (>=3 levels)
    # -------------------------
    echo "Flattening nested folders..."
    find "$originalfolder" -mindepth 3 -type f \( -iname '*.mp3' -o -iname '*.m4b' -o -iname '*.m4a' \) -print0 |
    while IFS= read -r -d '' file; do
        rel="${file#$originalfolder/}"
        IFS='/' read -ra parts <<< "$rel"
        if [ ${#parts[@]} -ge 4 ]; then
            filename="${parts[-1]}"
            grandparent="${parts[3]}"
            new_filename=""
            for ((i=4;i<${#parts[@]}-1;i++)); do new_filename+="${parts[i]} - "; done
            new_filename+="$filename"
            new_path="$originalfolder/$grandparent/$new_filename"
            mkdir -p "$(dirname "$new_path")"
            mv -v "$file" "$new_path"
        fi
    done

    # -------------------------
    # Move multi-file audiobook folders to inputfolder
    # -------------------------
    echo "Moving multi-file audiobook folders..."
    find "$originalfolder" -maxdepth 2 -mindepth 2 -type f \( -iname '*.mp3' -o -iname '*.m4b' -o -iname '*.m4a' \) -print0 |
    xargs -0 -r -n 1 dirname | sort | uniq -c | grep -E -v '^ *1 ' | sed 's/^ *[0-9]* //' |
    while read -r folder; do
        mv -v "$folder" "$inputfolder"
    done

    # -------------------------
    # Move single files to input/output
    # -------------------------
    echo "Moving single MP3s to merge folder..."
    find "$originalfolder" -maxdepth 2 -type f -iname '*.mp3' -printf "%h\0" | xargs -0 -r mv -t "$inputfolder"

    echo "Moving single M4B/M4A/MP4/OGG files to output folder..."
    find "$originalfolder" -maxdepth 2 -type f \( -iname '*.m4b' -o -iname '*.m4a' -o -iname '*.mp4' -o -iname '*.ogg' \) -printf "%h\0" | xargs -0 -r mv -t "$outputfolder"

    # -------------------------
    # Clear bin folder
    # -------------------------
    rm -rf "$binfolder"* 2>/dev/null

    # -------------------------
    # Process folders in inputfolder
    # -------------------------
    cd "$inputfolder" || exit
    if ls -d */ 2>/dev/null; then
        for book in */; do
            book="${book%/}"
            [[ -d "$book" ]] || continue
            mkdir -p "$outputfolder$book"

            mpthree=$(find "$book" -maxdepth 2 -type f \( -iname '*.mp3' -o -iname '*.m4b' \) | head -n1)
            m4bfile="$outputfolder$book/$book$m4bend"
            logfile="$outputfolder$book/$book$logend"

            # Determine bitrate if MP3
            if [[ "$mpthree" == *.mp3 ]]; then
                bit=$(ffprobe -hide_banner -loglevel error -of flat -i "$mpthree" -select_streams a -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1)
                bit=${bit%%.*}
                [[ -z "$bit" ]] && bit=64000
                echo "Merging $book -> $m4bfile"
                m4b-tool merge "$book" -n -q --audio-bitrate="$bit" --skip-cover --use-filenames-as-chapters --no-chapter-reindexing --audio-codec=libfdk_aac --jobs="$CPU_CORES" --output-file="$m4bfile" --logfile="$logfile"
            else
                # Already an M4B, just copy
                cp -v "$mpthree" "$m4bfile"
            fi

            # -------------------------
            # Generate chapters.txt
            # -------------------------
            echo "Generating chapters -> $outputfolder$book/chapters.txt"
            m4b-tool chapters "$m4bfile" > "$outputfolder$book/chapters.txt" 2>/dev/null || echo "Chapters generation failed"

            # -------------------------
            # Move processed folder to bin
            # -------------------------
            mv "$inputfolder$book" "$binfolder" 2>/dev/null
        done
    else
        echo "No folders to process. Sleeping $sleeptime..."
    fi

    sleep "$sleeptime"
done

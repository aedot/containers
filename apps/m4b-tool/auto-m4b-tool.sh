#!/bin/bash
# Auto M4B Tool - Containerized Version
set -euo pipefail

# -------------------------
# Utility Functions
# -------------------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $*" >&2
}

# Validate directory path is safe and within expected bounds
validate_directory() {
    local dir="$1"
    local name="$2"
    
    if [[ -z "$dir" || "$dir" != /* ]]; then
        log_error "$name directory must be an absolute path: $dir"
        return 1
    fi
    
    if [[ "$dir" =~ \.\. ]]; then
        log_error "$name directory cannot contain parent directory references: $dir"
        return 1
    fi
    
    return 0
}

# Safe file operations with proper quoting
safe_move() {
    local src="$1"
    local dest="$2"
    
    if [[ ! -e "$src" ]]; then
        log_warn "Source file does not exist: $src"
        return 1
    fi
    
    mkdir -p "$(dirname "$dest")"
    mv -f "$src" "$dest" || {
        log_error "Failed to move $src to $dest"
        return 1
    }
}

safe_remove() {
    local path="$1"
    local name="$2"
    
    if [[ -z "$path" ]]; then
        log_error "$name path is empty"
        return 1
    fi
    
    validate_directory "$path" "$name" || return 1
    
    if [[ -d "$path" ]]; then
        rm -rf "$path"/* 2>/dev/null || {
            log_warn "Could not clean $name directory: $path"
        }
    fi
}

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
MAX_DIR_DEPTH=3  # Configurable directory depth for flattening

# Normalize paths (remove trailing slashes for consistency)
inputfolder="${inputfolder%/}/"
outputfolder="${outputfolder%/}/"
originalfolder="${originalfolder%/}/"
fixitfolder="${fixitfolder%/}/"
backupfolder="${backupfolder%/}/"
binfolder="${binfolder%/}/"

# -------------------------
# Configuration Validation
# -------------------------
for dir_var in inputfolder outputfolder originalfolder fixitfolder backupfolder binfolder; do
    validate_directory "${!dir_var}" "$dir_var" || exit 1
done

# -------------------------
# Startup Info
# -------------------------
log "M4B-Tool Auto Processor"
log "Input:       $inputfolder"
log "Output:      $outputfolder"
log "Original:    $originalfolder"
log "Backup:      $backupfolder"
log "Fix-it:      $fixitfolder"
log "Bin:         $binfolder"
log "Sleep:       $sleeptime"
log "CPU cores:   $CPU_CORES"
log "Make backup: $MAKE_BACKUP"
log "User:        $(id)"

# -------------------------
# Ensure folder structure
# -------------------------
log "Creating folder structure..."
mkdir -p "$inputfolder" "$outputfolder" "$originalfolder" "$fixitfolder" "$backupfolder" "$binfolder" || {
    log_error "Failed to create directories. Check volume permissions."
    exit 1
}

# -------------------------
# Main loop
# -------------------------
while true; do
    log "Starting processing cycle..."

    # -------------------------
    # Backup original folder
    # -------------------------
    if [ "$MAKE_BACKUP" == "N" ]; then
        log "Skipping backup (MAKE_BACKUP=N)"
    else
        log "Backing up $originalfolder -> $backupfolder"
        if compgen -G "${originalfolder}*" > /dev/null; then
            cp -Ru "$originalfolder"* "$backupfolder" 2>/dev/null || log_warn "Backup completed with warnings"
        else
            log "Backup skipped: nothing to backup"
        fi
    fi

    # -------------------------
    # Organize single files into folders (atomic operations)
    # -------------------------
    log "Organizing single files into folders..."
    shopt -s nullglob
    for file in "$originalfolder"*.{mp3,m4b,m4a}; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")
            folder="${originalfolder}${filename%.*}"
            log "Creating folder: $folder"
            mkdir -p "$folder"
            safe_move "$file" "$folder/" || log_warn "Failed to move file: $file"
        fi
    done
    shopt -u nullglob

    # -------------------------
    # Flatten deeply nested folders (atomic operations with proper filename handling)
    # -------------------------
    log "Flattening nested folders..."
    find "$originalfolder" -mindepth $MAX_DIR_DEPTH -type f \( -iname '*.mp3' -o -iname '*.m4b' -o -iname '*.m4a' \) -print0 2>/dev/null |
    while IFS= read -r -d '' file; do
        rel="${file#$originalfolder}"
        readarray -td / parts < <(printf '%s' "$rel")
        parts=("$(basename "$originalfolder")" "${parts[@]}")
        
        if [ ${#parts[@]} -ge $((MAX_DIR_DEPTH + 1)) ]; then
            filename=$(basename "$file")
            grandparent="${parts[1]}"
            
            # Build new filename safely
            new_filename=""
            for ((i=2;i<${#parts[@]}-1;i++)); do
                if [[ -n "${parts[i]}" ]]; then
                    new_filename+="${parts[i]} - "
                fi
            done
            new_filename+="$filename"
            
            # Sanitize filename
            new_filename=$(printf '%s' "$new_filename" | tr '/' '-')
            new_path="${originalfolder}${grandparent}/${new_filename}"
            
            log "Flattening: $file -> $new_path"
            safe_move "$file" "$new_path" || log_warn "Failed to flatten file: $file"
        fi
    done

    # -------------------------
    # Move multi-file audiobook folders to inputfolder (atomic)
    # -------------------------
    log "Moving multi-file audiobook folders to input..."
    find "$originalfolder" -maxdepth 2 -mindepth 2 -type f \( -iname '*.mp3' -o -iname '*.m4b' -o -iname '*.m4a' \) -print0 2>/dev/null |
    xargs -0 -r -n 1 dirname | sort | uniq -c | grep -E -v '^ *1 ' | sed 's/^ *[0-9]* //' |
    while read -r folder; do
        if [[ -d "$folder" ]]; then
            new_folder="${inputfolder}$(basename "$folder")"
            log "Moving folder: $folder -> $new_folder"
            safe_move "$folder" "$new_folder" || log_warn "Failed to move folder: $folder"
        fi
    done

    # -------------------------
    # Move single files to input/output (atomic)
    # -------------------------
    log "Moving single MP3 folders to merge folder..."
    find "$originalfolder" -maxdepth 2 -type f -iname '*.mp3' -printf "%h\0" 2>/dev/null |
    sort -zu | while IFS= read -r -d '' folder; do
        if [[ -d "$folder" ]]; then
            new_folder="${inputfolder}$(basename "$folder")"
            log "Moving folder: $folder -> $new_folder"
            safe_move "$folder" "$new_folder" || log_warn "Failed to move MP3 folder: $folder"
        fi
    done

    log "Moving single M4B/M4A/MP4/OGG folders to output..."
    find "$originalfolder" -maxdepth 2 -type f \( -iname '*.m4b' -o -iname '*.m4a' -o -iname '*.mp4' -o -iname '*.ogg' \) -printf "%h\0" 2>/dev/null |
    sort -zu | while IFS= read -r -d '' folder; do
        if [[ -d "$folder" ]]; then
            new_folder="${outputfolder}$(basename "$folder")"
            log "Moving folder: $folder -> $new_folder"
            safe_move "$folder" "$new_folder" || log_warn "Failed to move M4B/M4A folder: $folder"
        fi
    done

    # -------------------------
    # Clear bin folder (safe operation)
    # -------------------------
    log "Clearing bin folder..."
    safe_remove "$binfolder" "bin"

    # -------------------------
    # Process folders in inputfolder (atomic operations)
    # -------------------------
    cd "$inputfolder" || {
        log_error "Failed to change to input directory: $inputfolder"
        exit 1
    }

    if compgen -G "*/" > /dev/null; then
        # Create list of folders to process first to avoid race conditions
        folders_to_process=()
        for book_folder in */; do
            book_folder="${book_folder%/}"
            if [[ -d "$book_folder" ]]; then
                folders_to_process+=("$book_folder")
            fi
        done

        for book in "${folders_to_process[@]}"; do
            if [[ ! -d "$book" ]]; then
                log_warn "Folder disappeared during processing: $book"
                continue
            fi

            log "Processing: $book"
            output_dir="${outputfolder}${book}"
            mkdir -p "$output_dir"

            # Find first audio file
            mpthree=$(find "$book" -maxdepth 2 -type f \( -iname '*.mp3' -o -iname '*.m4b' -o -iname '*.m4a' \) 2>/dev/null | head -n1)

            if [[ -z "$mpthree" ]]; then
                log_warn "No audio files found in $book, moving to bin..."
                safe_move "$book" "$binfolder" || log_warn "Failed to move empty folder: $book"
                continue
            fi

            m4bfile="${output_dir}/${book}${m4bend}"
            logfile="${output_dir}/${book}${logend}"
            processing_success=false

            # Determine bitrate if MP3
            if [[ "$mpthree" == *.mp3 ]]; then
                log "Detecting bitrate for MP3..."
                bit=$(ffprobe -hide_banner -loglevel error -of flat -i "$mpthree" -select_streams a -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 2>/dev/null || echo "64000")
                bit=${bit%%.*}
                [[ -z "$bit" || "$bit" -eq 0 ]] && bit=64000
                log "Detected bitrate: $bit"

                log "Merging $book -> $m4bfile"
                if m4b-tool merge "$book" -n -q \
                    --audio-bitrate="$bit" \
                    --skip-cover \
                    --use-filenames-as-chapters \
                    --no-chapter-reindexing \
                    --audio-codec=libfdk_aac \
                    --jobs="$CPU_CORES" \
                    --output-file="$m4bfile" \
                    --logfile="$logfile"; then
                    processing_success=true
                    log "Merge completed successfully"
                else
                    log_error "m4b-tool merge failed for $book"
                    continue
                fi
            else
                # Already an M4B/M4A, just copy
                log "File already in M4B/M4A format, copying..."
                if cp "$mpthree" "$m4bfile"; then
                    processing_success=true
                    log "Copy completed successfully"
                else
                    log_error "Failed to copy $mpthree"
                    continue
                fi
            fi

            # -------------------------
            # Generate chapters.txt (with error handling)
            # -------------------------
            if [[ -f "$m4bfile" && "$processing_success" == true ]]; then
                log "Generating chapters -> ${output_dir}/chapters.txt"
                if ! m4b-tool chapters "$m4bfile" > "${output_dir}/chapters.txt" 2>/dev/null; then
                    log_warn "Chapters generation failed for $book"
                    # Continue processing - chapters failure is not critical
                fi
            fi

            # -------------------------
            # Move processed folder to bin (only if successful)
            # -------------------------
            if [[ "$processing_success" == true && -f "$m4bfile" ]]; then
                log "Moving processed folder to bin..."
                if safe_move "$book" "$binfolder"; then
                    log "✓ Completed: $book"
                else
                    log_error "Failed to move processed folder to bin: $book"
                fi
            else
                log_error "Processing failed for $book, leaving folder in place"
            fi
        done
    else
        log "No folders to process."
    fi

    log "Cycle complete. Sleeping $sleeptime..."
    sleep "$sleeptime"
done

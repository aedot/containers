#!/usr/bin/with-contenv bash
# shellcheck shell=bash

# Beets-Audible Init Script for s6-overlay
# This runs during container initialization before services start

echo "=================================="
echo "Beets-Audible Container Init"
echo "=================================="

# This script runs as root, but we can check what user will run the services
echo "Init running as: $(whoami)"
echo "Services will run as: PUID=${PUID:-911}, PGID=${PGID:-911}"

# Verify beets installation
if command -v beet &> /dev/null; then
    BEETS_VERSION=$(beet version 2>&1 | head -n1 || echo "unknown")
    echo "Beets: ${BEETS_VERSION}"
else
    echo "ERROR: Beets not found"
    exit 1
fi

# Verify plugins
echo ""
echo "Installed plugins:"
if pip list 2>/dev/null | grep -q "beets-audible"; then
    AUDIBLE_VERSION=$(pip show beets-audible 2>/dev/null | grep "^Version:" | awk '{print $2}')
    echo "beets-audible ${AUDIBLE_VERSION}"
else
    echo "beets-audible NOT FOUND"
fi

if pip list 2>/dev/null | grep -q "beets-filetote"; then
    FILETOTE_VERSION=$(pip show beets-filetote 2>/dev/null | grep "^Version:" | awk '{print $2}')
    echo "beets-filetote ${FILETOTE_VERSION}"
else
    echo "beets-filetote not installed (optional)"
fi

# Check configuration directory
echo ""
if [ -d "/config" ]; then
    echo "Config directory mounted"

    # Create default config if it doesn't exist
    if [ ! -f "/config/config.yaml" ]; then
        echo "Creating default config.yaml..."
        cat > /config/config.yaml << 'EOF'
# Beets configuration for audiobooks
# Edit with: docker exec -it <container> beet config -e

plugins: audible edit fromfilename scrub web

directory: /audiobooks

paths:
  "albumtype:audiobook series_name::.+ series_position::.+": $albumartist/%ifdef{series_name}/%ifdef{series_position} - $album%aunique{}/$track - $title
  "albumtype:audiobook series_name::.+": $albumartist/%ifdef{series_name}/$album%aunique{}/$track - $title
  "albumtype:audiobook": $albumartist/$album%aunique{}/$track - $title
  default: $albumartist/$album%aunique{}/$track - $title

musicbrainz:
  enabled: no

audible:
  match_chapters: true
  data_source_mismatch_penalty: 0.0
  fetch_art: true
  include_narrator_in_artists: true
  keep_series_reference_in_title: true
  keep_series_reference_in_subtitle: true
  write_description_file: true
  write_reader_file: true
  region: us

web:
  host: 0.0.0.0
  port: 8337

scrub:
  auto: yes
EOF
        echo "Created default config.yaml"
    else
        echo "config.yaml found"
    fi

    # Check library database
    if [ -f "/config/library.db" ]; then
        DB_SIZE=$(du -h "/config/library.db" 2>/dev/null | cut -f1 || echo "0")
        echo "Library database (${DB_SIZE})"
    else
        echo "No library yet - will create on first import"
    fi

    # Set ownership to beets user (will be mapped to PUID:PGID)
    echo "Setting ownership..."
    chown -R beets:beets /config 2>/dev/null || true

else
    echo "ERROR: /config not mounted"
    exit 1
fi

# Check volume mounts
echo ""
echo "Volume status:"
[ -d "/audiobooks" ] && echo "/audiobooks mounted" || echo "/audiobooks not mounted"
[ -d "/input" ] && echo "/input mounted" || echo "/input not mounted (optional)"

# Create directories if they don't exist and are mounted
if [ -d "/audiobooks" ]; then
    chown -R beets:beets /audiobooks 2>/dev/null || true
fi

if [ -d "/input" ]; then
    chown -R beets:beets /input 2>/dev/null || true
fi

# Ready message
echo ""
echo "=================================="
echo "    Initialization Complete!"
echo "=================================="
echo ""
echo "Quick Start:"
echo "  Web UI:   http://localhost:8337"
echo "  Import:   docker exec -it <container> beet import /input"
echo "  Config:   docker exec -it <container> beet config -e"
echo "  Shell:    docker exec -it <container> bash"
echo ""

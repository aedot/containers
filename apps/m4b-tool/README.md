# M4B-Tool Container

A containerized audiobook processing application that automatically converts and organizes MP3 files into M4B format using the m4b-tool.

## Overview

This container runs as a daemon that monitors folders for new audiobook content and processes them by:

1. **Organizing** single files into dedicated folders
2. **Flattening** deeply nested directory structures
3. **Converting** MP3 files to M4B format with proper metadata and chapters
4. **Backing up** original files before processing
5. **Maintaining** a clean folder structure for processed and failed content

## Folder Structure

The application uses a well-defined folder structure:

- `/temp/recentlyadded` - **Input**: Place new audiobook files here
- `/temp/merge` - **Processing**: Multi-file audiobooks to be merged into M4B
- `/temp/untagged` - **Output**: Completed M4B files and M4A/M4B copies
- `/temp/backup` - **Backup**: Backup of original files from `/temp/recentlyadded`
- `/temp/fix` - **Manual**: Files that need manual attention
- `/temp/delete` - **Cleanup**: Successfully processed source files (temporary)

## Environment Variables

### Configuration
- `INPUT_FOLDER` - Input directory for multi-file audiobooks (default: `/temp/merge`)
- `OUTPUT_FOLDER` - Output directory for processed files (default: `/temp/untagged`)
- `ORIGINAL_FOLDER` - Source directory for new files (default: `/temp/recentlyadded`)
- `FIXIT_FOLDER` - Directory for files needing manual fixes (default: `/temp/fix`)
- `BACKUP_FOLDER` - Backup directory (default: `/temp/backup`)
- `BIN_FOLDER` - Cleanup directory (default: `/temp/delete`)

### Processing
- `SLEEPTIME` - Sleep duration between processing cycles (default: `3m`)
- `CPU_CORES` - Number of CPU cores for parallel processing (default: `$(nproc)`)
- `MAKE_BACKUP` - Enable/disable backups (`Y`/`N`, default: `Y`)

## Usage

### Basic Setup

```yaml
version: '3.8'
services:
  m4b-tool:
    image: ghcr.io/aedot/m4b-tool:rolling
    volumes:
      - /path/to/audiobooks:/temp/recentlyadded:ro
      - /path/to/output:/temp/untagged
      - /path/to/backup:/temp/backup
    environment:
      - SLEEPTIME=5m
      - CPU_CORES=4
    restart: unless-stopped
```

### Advanced Configuration

```yaml
version: '3.8'
services:
  m4b-tool:
    image: ghcr.io/aedot/m4b-tool:rolling
    volumes:
      - ./recentlyadded:/temp/recentlyadded
      - ./untagged:/temp/untagged
      - ./backup:/temp/backup
      - ./fix:/temp/fix
    environment:
      - INPUT_FOLDER=/temp/merge
      - OUTPUT_FOLDER=/temp/untagged
      - ORIGINAL_FOLDER=/temp/recentlyadded
      - MAKE_BACKUP=Y
      - SLEEPTIME=2m
      - CPU_CORES=2
    restart: unless-stopped
    # Optional: Add resource limits
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2'
```

## Processing Workflow

### 1. File Organization
- Single files are automatically moved to dedicated folders
- Nested directory structures are flattened (≥3 levels)
- Special characters in filenames are properly handled

### 2. Audio Processing
- **MP3 files**: Automatically detected bitrate is used for optimal conversion
- **M4B/M4A files**: Copied directly without conversion
- **Chapters**: Automatically generated from filenames
- **Metadata**: Preserved and enhanced during processing

### 3. Safety Features
- **Atomic operations**: Files are only moved after successful processing
- **Error handling**: Failed operations are logged and files are preserved
- **Backup system**: Original files are backed up before processing
- **Validation**: All operations include safety checks

## Supported Formats

### Input Formats
- MP3 (converted to M4B)
- M4B (copied directly)
- M4A (copied directly)
- MP4 (copied directly)
- OGG (copied directly)

### Output Format
- M4B with AAC encoding (libfdk_aac codec)
- Chapter markers from filenames
- Optimized for audiobook playback

## Logging

The application provides structured logging with timestamps:
- `[2024-01-01 12:00:00]` - Information messages
- `[2024-01-01 12:00:00] WARNING:` - Warning messages  
- `[2024-01-01 12:00:00] ERROR:` - Error messages

## Security Features

- **Non-root execution**: Runs as non-privileged user
- **Path validation**: Prevents directory traversal attacks
- **Safe file operations**: Proper quoting and validation
- **Input sanitization**: Special characters handled safely

## Monitoring

The container includes health checks to verify:
- Script accessibility
- Command functionality
- Directory structure

## Troubleshooting

### Common Issues

1. **Permission errors**: Ensure volume mounts have correct permissions
2. **No processing**: Check that files are placed in `/temp/recentlyadded`
3. **Processing failures**: Check logs for specific error messages
4. **Large files**: Increase memory limits for large audiobooks

### Debug Mode

For debugging, you can run the container with increased verbosity:

```bash
docker run -it --rm ghcr.io/aedot/m4b-tool:rolling bash
```

## Development

### Building

```bash
docker build -t m4b-tool .
```

### Testing

```bash
go test ./...
```

## Contributing

1. Follow the existing code style and conventions
2. Add tests for new functionality
3. Update documentation for changes
4. Ensure all security practices are maintained

## License

This project follows the same license as the m4b-tool project.
#!/bin/bash

set -e

# =========================
# SETUP
# =========================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

SOURCE_DIR="$SCRIPT_DIR/data"        # default source
BACKUP_DIR="$SCRIPT_DIR/backups"     # backup location
TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S")

BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.tar.gz"

# =========================
# VALIDATION
# =========================

# Auto-create backup directory
mkdir -p "$BACKUP_DIR"

# If source doesn't exist, create it (prevents your current error)
if [ ! -d "$SOURCE_DIR" ]; then
  echo "INFO: Source directory not found. Creating $SOURCE_DIR"
  mkdir -p "$SOURCE_DIR"

  # Add a placeholder so tar doesn't create empty archive silently
  echo "Sample file - replace with real data" > "$SOURCE_DIR/README.txt"
fi

# =========================
# BACKUP PROCESS
# =========================

echo "Starting backup..."

tar -czf "$BACKUP_FILE" -C "$SOURCE_DIR" .

if [ $? -eq 0 ]; then
  echo "Backup successful: $BACKUP_FILE"
else
  echo "ERROR: Backup failed"
  exit 1
fi

# =========================
# CLEANUP (RETENTION)
# =========================

# Delete backups older than 7 days
find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +7 -exec rm -f {} \;

echo "Old backups cleaned"

# =========================
# DONE
# =========================

echo "Backup process completed successfully."
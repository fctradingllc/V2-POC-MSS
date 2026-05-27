#!/bin/bash
# Backup Odoo database + filestore. Keeps last 7 daily backups.

DB_NAME="V2-POC-MSS"
DB_USER="odoo"
DB_HOST="localhost"
DB_PORT="5432"
PGPASSWORD="odoo"
BACKUP_DIR="/workspaces/V2-POC-MSS/backups"
FILESTORE_DIR="$HOME/.local/share/Odoo/filestore/$DB_NAME"
DATE=$(date +%Y-%m-%d_%H-%M)
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${DATE}.dump"
KEEP_DAYS=7

export PGPASSWORD

mkdir -p "$BACKUP_DIR"

# Database dump
pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -Fc "$DB_NAME" -f "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "[$(date)] Backup OK: $BACKUP_FILE"
else
    echo "[$(date)] Backup FAILED" >&2
    exit 1
fi

# Filestore snapshot (attachments, images)
if [ -d "$FILESTORE_DIR" ]; then
    FILESTORE_BACKUP="$BACKUP_DIR/${DB_NAME}_${DATE}_filestore.tar.gz"
    tar -czf "$FILESTORE_BACKUP" -C "$(dirname "$FILESTORE_DIR")" "$DB_NAME"
    echo "[$(date)] Filestore backup OK: $FILESTORE_BACKUP"
fi

# Rotation: keep last KEEP_DAYS days
find "$BACKUP_DIR" -name "${DB_NAME}_*.dump" -mtime +$KEEP_DAYS -delete
find "$BACKUP_DIR" -name "${DB_NAME}_*_filestore.tar.gz" -mtime +$KEEP_DAYS -delete

echo "[$(date)] Backups disponibles:"
ls -lh "$BACKUP_DIR"

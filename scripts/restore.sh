#!/bin/bash
# Restore Odoo database from a .dump file.
# Usage: ./restore.sh <backup_file.dump>

DB_NAME="V2-POC-MSS"
DB_USER="odoo"
DB_HOST="localhost"
DB_PORT="5432"
PGPASSWORD="odoo"
BACKUP_DIR="/workspaces/V2-POC-MSS/backups"

export PGPASSWORD

BACKUP_FILE="${1}"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file.dump>"
    echo ""
    echo "Backups disponibles:"
    ls -lht "$BACKUP_DIR"/*.dump 2>/dev/null || echo "Aucun backup trouvé."
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Fichier introuvable: $BACKUP_FILE"
    exit 1
fi

echo "Restauration de $BACKUP_FILE vers la base $DB_NAME..."
echo "ATTENTION: cela va écraser la base existante. Ctrl+C pour annuler (5s)..."
sleep 5

# Drop and recreate
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS \"$DB_NAME\";"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"

# Restore
pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" "$BACKUP_FILE"

echo "[$(date)] Restauration terminée."

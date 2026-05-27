#!/bin/bash
# Lancé automatiquement à chaque démarrage du Codespace.
# 1. Backup de la base existante (si elle existe)
# 2. Démarrage d'Odoo

DB_NAME="V2-POC-MSS"
ODOO_DIR="/workspaces/V2-POC-MSS/odoo19"
LOG="/workspaces/V2-POC-MSS/backups/startup.log"

mkdir -p /workspaces/V2-POC-MSS/backups

echo "[$(date)] === Démarrage du Codespace ===" >> "$LOG"

# Backup seulement si la base existe
DB_EXISTS=$(PGPASSWORD=odoo psql -h localhost -U odoo -d postgres -tAc \
  "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';" 2>/dev/null)

if [ "$DB_EXISTS" = "1" ]; then
    echo "[$(date)] Base trouvée, backup en cours..." >> "$LOG"
    bash /workspaces/V2-POC-MSS/scripts/backup.sh >> "$LOG" 2>&1
else
    echo "[$(date)] Aucune base $DB_NAME trouvée, backup ignoré." >> "$LOG"
fi

# Démarrage Odoo
echo "[$(date)] Démarrage d'Odoo..." >> "$LOG"
cd "$ODOO_DIR" && source venv/bin/activate && \
  nohup python odoo-bin -c odoo.conf >> /workspaces/V2-POC-MSS/backups/odoo.log 2>&1 &

echo "[$(date)] Odoo lancé (PID $!)" >> "$LOG"

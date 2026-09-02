#!/usr/bin/env bash
set -e

echo "=== Avvio container infra-tools ==="

RCLONE_CONF="/config/rclone/rclone.conf"
if [ -f "$RCLONE_CONF" ]; then
  echo "[INFO] Trovato rclone.conf. Sync Google Drive abilitato per /gdrive-sync."
else
  echo "[INFO] Nessun file /config/rclone/rclone.conf trovato."
  echo "       Il servizio funzionerà in modalità 'solo backup locale'."
fi

# Configurazione crontab per Alpine
cat << 'EOF' > /etc/crontabs/root
# Backup giornaliero alle ore 03:00
0 3 * * * /app/backup.sh >> /var/log/backup.log 2>&1

# Sincronizzazione /gdrive-sync su Drive ogni 15 minuti (se rclone.conf presente)
*/15 * * * * [ -f /config/rclone/rclone.conf ] && rclone --config /config/rclone/rclone.conf sync /gdrive-sync "${RCLONE_REMOTE:-gdrive}:${RCLONE_REMOTE_FOLDER:-}" >> /var/log/rclone.log 2>&1
EOF

echo "[INFO] Pianificatore cron configurato (backup giornaliero alle 03:00)."
echo "[INFO] Esecuzione primo backup all'avvio in background tra 30 secondi..."

(
  sleep 30
  /app/backup.sh || true
) &

# Esecuzione cron in foreground
exec crond -f -l 2

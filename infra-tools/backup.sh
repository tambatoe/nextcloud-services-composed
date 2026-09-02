#!/usr/bin/env bash
set -eo pipefail

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/backups"
WORK_DIR="/tmp/backup_${TIMESTAMP}"
ARCHIVE_NAME="backup-${TIMESTAMP}.tar.gz"
FINAL_ARCHIVE="${BACKUP_DIR}/${ARCHIVE_NAME}"

echo "=================================================="
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Inizio procedura di backup..."
echo "=================================================="

mkdir -p "${BACKUP_DIR}" "${WORK_DIR}/db" "${WORK_DIR}/sources"

# 1. Backup del Database MariaDB
if [ -n "${MYSQL_ROOT_PASSWORD}" ]; then
  echo "[1/4] Esecuzione dump MariaDB (host: ${MYSQL_HOST:-db})..."
  if mysqldump -h "${MYSQL_HOST:-db}" -u root -p"${MYSQL_ROOT_PASSWORD}" --all-databases --single-transaction --quick > "${WORK_DIR}/db/mariadb_all_databases.sql" 2>/dev/null; then
    echo "       Dump completato con successo."
  else
    echo "       [ATTENZIONE] Dump MariaDB fallito o database non ancora pronto. Il backup proseguirà con le altre sorgenti."
  fi
else
  echo "[1/4] MYSQL_ROOT_PASSWORD non definita, dump MariaDB saltato."
fi

# 2. Copia delle sorgenti di configurazione
echo "[2/4] Copia delle configurazioni e sorgenti..."
if [ -d "/backup_sources" ]; then
  cp -a /backup_sources/* "${WORK_DIR}/sources/" 2>/dev/null || true
fi

# 3. Creazione archivio tar.gz
echo "[3/4] Creazione archivio compresso..."
tar -czf "${FINAL_ARCHIVE}" -C "${WORK_DIR}" .
rm -rf "${WORK_DIR}"

# Cifratura GPG opzionale
if [ -n "${BACKUP_GPG_PASSPHRASE}" ]; then
  echo "       Cifratura archivio con GPG..."
  gpg --symmetric --batch --yes --passphrase "${BACKUP_GPG_PASSPHRASE}" --output "${FINAL_ARCHIVE}.gpg" "${FINAL_ARCHIVE}"
  rm -f "${FINAL_ARCHIVE}"
  FINAL_ARCHIVE="${FINAL_ARCHIVE}.gpg"
fi

echo "       Archivio creato: ${FINAL_ARCHIVE} ($(du -h "${FINAL_ARCHIVE}" | cut -f1))"

# Retention locale
RETENTION=${BACKUP_RETENTION_DAYS:-14}
echo "       Pulizia backup locali più vecchi di ${RETENTION} giorni..."
find "${BACKUP_DIR}" -maxdepth 1 -name "backup-*" -mtime +"${RETENTION}" -delete 2>/dev/null || true

# 4. Upload Google Drive con rclone (opzionale)
echo "[4/4] Verifica sincronizzazione cloud..."
RCLONE_CONF="/config/rclone/rclone.conf"
if [ "${BACKUP_UPLOAD_TO_DRIVE}" = "true" ]; then
  if [ -f "${RCLONE_CONF}" ]; then
    REMOTE=${RCLONE_REMOTE:-gdrive}
    DEST_PATH=${RCLONE_BACKUP_PATH:-infra-backups}
    echo "       Caricamento backup su ${REMOTE}:${DEST_PATH}..."
    rclone --config "${RCLONE_CONF}" copy "${FINAL_ARCHIVE}" "${REMOTE}:${DEST_PATH}" || echo "       [ERRORE] Upload rclone fallito."
  else
    echo "       [INFO] File rclone.conf non trovato in /config/rclone/rclone.conf. Upload su Google Drive saltato."
  fi
else
  echo "       Upload su Drive disabilitato (BACKUP_UPLOAD_TO_DRIVE!=true)."
fi

echo "=================================================="
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup completato con successo!"
echo "=================================================="

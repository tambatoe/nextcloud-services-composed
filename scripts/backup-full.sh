#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${INFRA_DIR}"

BACKUP_NAME="infra_full_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
BACKUP_PATH="$(pwd)/backups/${BACKUP_NAME}"

echo "=================================================="
echo "      Backup Completo Infrastruttura (Cold)       "
echo "=================================================="
echo "I container verranno momentaneamente fermati per garantire"
echo "la consistenza assoluta dei dati (inclusi database e file)."
echo ""

echo "[1/3] Spegnimento dei servizi..."
docker compose down

echo "[2/3] Creazione archivio in corso... Potrebbe richiedere tempo."
mkdir -p backups

# Comprime l'intera cartella escludendo la roba inutile/pesante generata
tar -czf "${BACKUP_PATH}" \
    --exclude="./backups/*" \
    --exclude="./.git" \
    --exclude="./olds" \
    .

echo "[3/3] Riaccensione servizi..."
docker compose up -d

echo "=================================================="
echo "[SUCCESS] Backup completato!"
echo "Archivio salvato in: ${BACKUP_PATH}"
echo "Dimensione: $(du -h "${BACKUP_PATH}" | cut -f1)"
echo "=================================================="

#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${INFRA_DIR}"

echo "=================================================="
echo "      Ripristino Completo Infrastruttura (Cold)   "
echo "=================================================="

if [ -z "$1" ]; then
  echo "Uso corretto: $0 <percorso_archivio_tar_gz>"
  echo "Esempio:      $0 ./backups/infra_full_backup_20240101_120000.tar.gz"
  exit 1
fi

ARCHIVE_PATH="$1"

if [ ! -f "${ARCHIVE_PATH}" ]; then
  echo "[ERRORE] Il file ${ARCHIVE_PATH} non esiste o non è accessibile."
  exit 1
fi

echo "⚠️  ATTENZIONE: Questa operazione sovrascriverà l'infrastruttura corrente!"
echo "Tutti i dati attuali verranno sostituiti da quelli presenti nell'archivio."
read -p "Sei sicuro di voler procedere? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Operazione annullata."
  exit 0
fi

echo "[1/3] Spegnimento dei container correnti..."
docker compose down || true

echo "[2/3] Estrazione dell'archivio..."
# Estrae sovrascrivendo i file esistenti
tar -xzf "${ARCHIVE_PATH}" -C "${INFRA_DIR}"

echo "[3/3] Riaccensione servizi..."
docker compose up -d

echo "=================================================="
echo "[SUCCESS] Ripristino completato con successo!"
echo "I servizi stanno ripartendo. Controlla i log con:"
echo "docker compose logs -f"
echo "=================================================="

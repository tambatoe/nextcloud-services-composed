#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "${SCRIPT_DIR}")"

echo "=================================================="
echo "      Inizializzazione Setup Infrastruttura      "
echo "=================================================="

cd "${INFRA_DIR}"

# 1. Verifica e creazione del file .env
if [ ! -f ".env" ]; then
  echo "[1/4] Creazione file .env da .env.example..."
  cp .env.example .env
  echo "      [NOTA] File .env creato. Modifica le password prima del deployment!"
else
  echo "[1/4] File .env già presente."
fi

# Carica le variabili da .env
# shellcheck disable=SC1091
source .env

# 2. Creazione delle cartelle di runtime necessarie
echo "[2/4] Preparazione cartelle di storage locali..."
mkdir -p "${PATH_NEXTCLOUD_DATA:-./nextcloud_data}" \
         "${PATH_VAULTWARDEN_DATA:-./vaultwarden_data}" \
         "${PATH_GDRIVE_SYNC:-./gdrive_sync}" \
         "${PATH_BACKUPS:-./backups}" \
         "${PATH_DNSMASQ_CONF:-./dnsmasq_conf}" \
         ./db_data \
         ./nextcloud_html \
         ./rclone

# 3. Verifica PKI OpenVPN
echo "[3/4] Verifica certificati OpenVPN..."
if [ ! -f "${PATH_OPENVPN_KEYS:-./openvpn_keys}/server/ca.crt" ]; then
  echo "      Certificati OpenVPN mancanti. Avvio generazione PKI automatica..."
  chmod +x "${SCRIPT_DIR}/init-vpn.sh"
  "${SCRIPT_DIR}/init-vpn.sh"
else
  echo "      Certificati OpenVPN già presenti."
fi

# 4. Controllo preliminare porta 53 (conflitto tipico con systemd-resolved)
echo "[4/4] Controllo conflitti di rete (porta 53 per dnsmasq)..."
if ss -ulpn 2>/dev/null | grep -q ":53 "; then
  echo "      [ATTENZIONE] La porta 53 risulta già in ascolto sull'host."
  echo "      Se usi Ubuntu/Debian con systemd-resolved, disabilita lo stub listener:"
  echo "      echo 'DNSStubListener=no' | sudo tee -a /etc/systemd/resolved.conf"
  echo "      sudo systemctl restart systemd-resolved"
else
  echo "      Porta 53 libera."
fi

echo "=================================================="
echo "[SUCCESS] Preparazione completata!"
echo ""
echo "Prossimi passi:"
echo "1. Controlla e personalizza i valori in .env (password e domini)"
echo "2. Avvia i servizi con:"
echo "   docker compose up -d"
echo "=================================================="

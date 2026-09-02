#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "${SCRIPT_DIR}")"
OPENVPN_DIR="${INFRA_DIR}/openvpn_keys"

if [ -z "$1" ]; then
  echo "Errore: devi specificare il nome del nuovo client."
  echo "Uso corretto: $0 <nome_client>"
  echo "Esempio:      $0 smartphone_mario"
  exit 1
fi

CLIENT_NAME="$1"

# Carica variabili da .env se presente
if [ -f "${INFRA_DIR}/.env" ]; then
  # shellcheck disable=SC1091
  source "${INFRA_DIR}/.env"
fi

OPENVPN_PORT="${OPENVPN_PORT:-1194}"
SERVER_PUBLIC_IP="${SERVER_PUBLIC_IP:-127.0.0.1}"

if [ ! -d "${OPENVPN_DIR}/easy-rsa-pki" ]; then
  echo "[ERRORE] Infrastruttura PKI non trovata in ${OPENVPN_DIR}/easy-rsa-pki."
  echo "         Assicurati di aver prima eseguito scripts/setup.sh o scripts/init-vpn.sh."
  exit 1
fi

echo "=================================================="
echo "    Creazione nuovo profilo VPN: ${CLIENT_NAME}"
echo "=================================================="

# 1. Generazione certificati con Easy-RSA tramite container effimero
docker run --rm -v "${OPENVPN_DIR}:/etc/openvpn" alpine:3.19 sh -c "
  set -e
  apk add --no-cache easy-rsa >/dev/null 2>&1
  
  # Crea una folder di lavoro temporanea
  rm -rf /tmp/easyrsa-build
  make-cadir /tmp/easyrsa-build >/dev/null 2>&1
  cd /tmp/easyrsa-build
  
  # Carica la PKI esistente
  rm -rf pki
  cp -a /etc/openvpn/easy-rsa-pki pki
  
  if [ -f pki/issued/${CLIENT_NAME}.crt ]; then
    echo '[ERRORE] Il client ${CLIENT_NAME} esiste già.'
    exit 1
  fi
  
  echo '--> Generazione certificati per ${CLIENT_NAME} (potrebbe richiedere qualche secondo)...'
  EASYRSA_BATCH=1 ./easyrsa gen-req ${CLIENT_NAME} nopass >/dev/null 2>&1
  EASYRSA_BATCH=1 ./easyrsa sign-req client ${CLIENT_NAME} >/dev/null 2>&1
  
  # Esporta i certificati generati nella cartella client accessibile all'host
  cp pki/issued/${CLIENT_NAME}.crt /etc/openvpn/client/${CLIENT_NAME}.crt
  cp pki/private/${CLIENT_NAME}.key /etc/openvpn/client/${CLIENT_NAME}.key
  chmod 600 /etc/openvpn/client/${CLIENT_NAME}.key
  
  # Salva le modifiche alla PKI (aggiorna index.txt, serial, ecc.)
  rm -rf /etc/openvpn/easy-rsa-pki
  cp -a pki /etc/openvpn/easy-rsa-pki
"

# 2. Creazione file unificato .ovpn pronto all'uso
echo "--> Compilazione file profilo .ovpn..."

cat << EOF > "${OPENVPN_DIR}/client/${CLIENT_NAME}.ovpn"
client
dev tun
proto udp
remote ${SERVER_PUBLIC_IP} ${OPENVPN_PORT}
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
data-ciphers AES-256-GCM:AES-128-GCM
cipher AES-256-GCM
verb 3

<ca>
$(cat "${OPENVPN_DIR}/server/ca.crt" 2>/dev/null || true)
</ca>
<cert>
$(cat "${OPENVPN_DIR}/client/${CLIENT_NAME}.crt" 2>/dev/null || true)
</cert>
<key>
$(cat "${OPENVPN_DIR}/client/${CLIENT_NAME}.key" 2>/dev/null || true)
</key>
<tls-crypt>
$(cat "${OPENVPN_DIR}/server/ta.key" 2>/dev/null || true)
</tls-crypt>
EOF

chmod 600 "${OPENVPN_DIR}/client/${CLIENT_NAME}.ovpn" 2>/dev/null || true

echo "=================================================="
echo "[SUCCESS] Profilo generato con successo!"
echo "Trovi il file pronto da importare in:"
echo "${OPENVPN_DIR}/client/${CLIENT_NAME}.ovpn"
echo "=================================================="

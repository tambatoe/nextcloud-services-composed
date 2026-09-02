#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "${SCRIPT_DIR}")"
OPENVPN_DIR="${INFRA_DIR}/openvpn_keys"

# Carica variabili da .env se presente
if [ -f "${INFRA_DIR}/.env" ]; then
  # shellcheck disable=SC1091
  source "${INFRA_DIR}/.env"
fi

VPN_DOMAIN="${VPN_DOMAIN:-vpn.local}"
VPN_SERVER_IP="${VPN_SERVER_IP:-10.8.0.1}"
VPN_SUBNET="${VPN_SUBNET:-10.8.0.0}"
VPN_NETMASK="${VPN_NETMASK:-255.255.255.0}"
OPENVPN_PORT="${OPENVPN_PORT:-1194}"
SERVER_PUBLIC_IP="${SERVER_PUBLIC_IP:-127.0.0.1}"

echo "=================================================="
echo "    Inizializzazione PKI OpenVPN (Standalone)    "
echo "=================================================="

mkdir -p "${OPENVPN_DIR}/server" "${OPENVPN_DIR}/client"

if [ -f "${OPENVPN_DIR}/server/ca.crt" ] && [ -f "${OPENVPN_DIR}/server/server.key" ]; then
  echo "[INFO] Certificati server OpenVPN già presenti in ${OPENVPN_DIR}/server/."
  echo "       Se desideri rigenerarli da zero, cancella il contenuto di ${OPENVPN_DIR}/server/ e riesegui."
else
  echo "[1/3] Generazione CA, certificato server, DH params e ta.key tramite container temporaneo..."

  docker run --rm -v "${OPENVPN_DIR}:/etc/openvpn" alpine:3.19 sh -c "
    set -e
    apk add --no-cache easy-rsa openvpn >/dev/null 2>&1
    
    rm -rf /tmp/easyrsa-build
    make-cadir /tmp/easyrsa-build >/dev/null 2>&1
    cd /tmp/easyrsa-build

    echo '--> Inizializzazione PKI...'
    ./easyrsa init-pki >/dev/null 2>&1

    echo '--> Creazione CA...'
    EASYRSA_BATCH=1 EASYRSA_REQ_CN='OpenVPN-CA' ./easyrsa build-ca nopass >/dev/null 2>&1

    echo '--> Creazione certificato server...'
    EASYRSA_BATCH=1 ./easyrsa gen-req server nopass >/dev/null 2>&1
    EASYRSA_BATCH=1 ./easyrsa sign-req server server >/dev/null 2>&1

    echo '--> Generazione parametri Diffie-Hellman...'
    ./easyrsa gen-dh >/dev/null 2>&1

    echo '--> Generazione CRL...'
    ./easyrsa gen-crl >/dev/null 2>&1

    echo '--> Generazione chiave tls-crypt (ta.key)...'
    openvpn --genkey secret /etc/openvpn/server/ta.key

    mkdir -p /etc/openvpn/server
    cp pki/ca.crt /etc/openvpn/server/ca.crt
    cp pki/issued/server.crt /etc/openvpn/server/server.crt
    cp pki/private/server.key /etc/openvpn/server/server.key
    cp pki/dh.pem /etc/openvpn/server/dh.pem
    cp pki/crl.pem /etc/openvpn/server/crl.pem
    chmod 600 /etc/openvpn/server/server.key /etc/openvpn/server/ta.key

    echo '--> Creazione primo client di test (client1)...'
    EASYRSA_BATCH=1 ./easyrsa gen-req client1 nopass >/dev/null 2>&1
    EASYRSA_BATCH=1 ./easyrsa sign-req client client1 >/dev/null 2>&1
    mkdir -p /etc/openvpn/client
    cp pki/issued/client1.crt /etc/openvpn/client/client1.crt
    cp pki/private/client1.key /etc/openvpn/client/client1.key
    chmod 600 /etc/openvpn/client/client1.key

    # Salva pki per consentire emissione di altri client futuri
    rm -rf /etc/openvpn/easy-rsa-pki
    cp -a /tmp/easyrsa-build/pki /etc/openvpn/easy-rsa-pki
  "
fi

echo "[2/3] Generazione file di configurazione server (${OPENVPN_DIR}/openvpn.conf)..."
cat << EOF > "${OPENVPN_DIR}/openvpn.conf"
port ${OPENVPN_PORT}
proto udp
dev tun

# Certificati e chiavi crittografiche
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key
dh /etc/openvpn/server/dh.pem
tls-crypt /etc/openvpn/server/ta.key
crl-verify /etc/openvpn/server/crl.pem

# Rete VPN
server ${VPN_SUBNET} ${VPN_NETMASK}
ifconfig-pool-persist /tmp/ipp.txt

# DNS e routing domini per i client
push "dhcp-option DNS ${VPN_SERVER_IP}"
push "dhcp-option DOMAIN-ROUTE ${VPN_DOMAIN}"

keepalive 10 120
persist-key
persist-tun

# Sicurezza
user nobody
group nobody

verb 3
status /tmp/openvpn-status.log 1

client-to-client
data-ciphers AES-256-GCM:AES-128-GCM
cipher AES-256-GCM
EOF

echo "[3/3] Generazione profilo unificato client (${OPENVPN_DIR}/client/client1.ovpn)..."
cat << EOF > "${OPENVPN_DIR}/client/client1.ovpn"
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
$(cat "${OPENVPN_DIR}/client/client1.crt" 2>/dev/null || true)
</cert>
<key>
$(cat "${OPENVPN_DIR}/client/client1.key" 2>/dev/null || true)
</key>
<tls-crypt>
$(cat "${OPENVPN_DIR}/server/ta.key" 2>/dev/null || true)
</tls-crypt>
EOF

chmod 600 "${OPENVPN_DIR}/client/client1.ovpn" 2>/dev/null || true

echo "=================================================="
echo "[SUCCESS] PKI OpenVPN configurata con successo!"
echo "Profilo client disponibile in: ${OPENVPN_DIR}/client/client1.ovpn"
echo "=================================================="

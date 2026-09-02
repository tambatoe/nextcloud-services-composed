#!/usr/bin/env bash
# =============================================================================
# NOTA: Questo script è uno strumento di utilità per la migrazione da un sistema
# con servizi nativi systemd (apache/mysql/openvpn/dnsmasq) a Docker Compose.
# NON è necessario né consigliato per un'installazione standalone da zero.
# =============================================================================

echo "=== 1. Verifica Immagini Docker ==="
if ! docker compose pull; then
  echo "ERRORE: Pull fallito. Interruzione senza toccare il sistema."
  exit 1
fi

echo ""
echo "=== 2. Arresto dei Servizi Nativi ==="

SERVICES=(
  openvpn
  openvpn-server
  openvpn-client
  dnsmasq
  apache2
  httpd
  nginx
  mariadb
  mysql
)

for svc in "${SERVICES[@]}"; do
  echo "Arresto $svc..."
  systemctl stop "$svc" 2>/dev/null
  systemctl stop "$svc@*" 2>/dev/null
  systemctl disable "$svc" 2>/dev/null
  systemctl disable "$svc@*" 2>/dev/null
done

echo ""
echo "=== 3. Verifica Processi Residui e Chiusura Forzata ==="
sleep 2

PROCESSES=(dnsmasq openvpn apache2 httpd nginx mariadbd mysqld)

for proc in "${PROCESSES[@]}"; do
  if pgrep -x "$proc" > /dev/null; then
    echo "Il processo $proc è ancora attivo. Invio SIGKILL..."
    pkill -9 -x "$proc" 2>/dev/null
  fi
done

echo ""
echo "=== 4. Attesa Liberazione Porte ==="
sleep 3

echo ""
echo "=== 5. Avvio Docker Compose ==="
docker compose up -d

echo ""
echo "=== 6. Stato dei Container ==="
docker compose ps

echo ""
echo "=== Switch completato! ==="

# Infra Stack — Nextcloud + Vaultwarden + VPN (Standalone Docker Compose)

Stack self-hosted e standalone basato su Docker Compose per ospitare i propri servizi personali in modo sicuro, isolato e riproducibile da zero.

## Servizi Inclusi

| Servizio | Immagine | Ruolo |
|---|---|---|
| **MariaDB** | `mariadb:10.11` | Database per Nextcloud |
| **Nextcloud** | `nextcloud:34.0.3-apache` | Cloud storage personale con cartella sync Drive |
| **Vaultwarden** | `vaultwarden/server:latest` | Server Bitwarden-compatibile per gestione password |
| **Caddy** | `caddy:latest` | Reverse proxy TLS automatico per domini interni |
| **dnsmasq** | `alpine:3.19` (dnsmasq) | DNS locale VPN per risoluzione automatica domini |
| **OpenVPN** | `alpine:3.19` (openvpn) | Accesso remoto sicuro alla rete interna con NAT |
| **infra-tools** | Dockerfile locale | Backup automatici locali + sync opzionale Google Drive |

---

## Architettura e Sicurezza

- **Isolamento**: Nextcloud, Vaultwarden e MariaDB sono confinati sulla rete privata interna Docker e raggiungibili localmente solo su `127.0.0.1`.
- **Ingresso protetto**: Caddy gestisce i certificati TLS interni per i domini configurati (`*.vpn.local`).
- **Accesso tramite VPN**: La risoluzione dei nomi dei servizi e l'accesso avviene attraverso la connessione OpenVPN e il DNS dnsmasq integrato.
- **Configurazione centralizzata**: Tutti i domini, indirizzi IP, percorsi e password sono gestiti in un unico file `.env`.

---

## Prerequisiti

- Sistema operativo Linux (necessario per `network_mode: host` e il modulo kernel `/dev/net/tun`)
- Docker Engine con Docker Compose v2 (`docker compose`)

---

## Installazione Rapida da Zero

### 1. Inizializzazione automatica dell'ambiente
Esegui lo script di setup che prepara le cartelle, genera il `.env` e crea la PKI di OpenVPN con il primo profilo client:

```bash
chmod +x scripts/*.sh
./scripts/setup.sh
```

### 2. Configura le credenziali
Apri il file `.env` generato e personalizza le password e i domini:
```bash
nano .env
```
Parametri principali:
- `VPN_DOMAIN`: Dominio della rete privata (default: `vpn.local`)
- `NEXTCLOUD_DOMAIN`: FQDN per Nextcloud (default: `nextcloud.vpn.local`)
- `VAULTWARDEN_DOMAIN`: FQDN per Vaultwarden (default: `vault.vpn.local`)
- `MYSQL_ROOT_PASSWORD` / `MYSQL_PASSWORD`: Password per il database
- `NEXTCLOUD_ADMIN_PASSWORD`: Password per l'amministratore Nextcloud
- `VAULTWARDEN_ADMIN_TOKEN`: Token per l'accesso a `/admin` su Vaultwarden

### 3. Avvio dei container
```bash
docker compose up -d
```

Verifica lo stato di tutti i servizi:
```bash
docker compose ps
```

---

## Primo Accesso ai Servizi

### 1. Connessione OpenVPN
Lo script di setup genera un file profilo client pronto all'uso in:
```
openvpn_keys/client/client1.ovpn
```
Importa questo file nel tuo client OpenVPN (es. OpenVPN Connect su PC o smartphone) e connettiti al server.
Una volta connesso, i domini `nextcloud.vpn.local` e `vault.vpn.local` risolveranno automaticamente sull'IP del server VPN.

### 2. Vaultwarden
Accedi a `https://vault.vpn.local`:
1. Crea il tuo account principale.
2. Una volta creato l'account, apri `.env` e imposta:
   ```env
   SIGNUPS_ALLOWED=false
   ```
3. Riavvia Vaultwarden per bloccare ulteriori registrazioni pubbliche:
   ```bash
   docker compose up -d vaultwarden
   ```

### 3. Nextcloud
Accedi a `https://nextcloud.vpn.local` ed effettua il login con le credenziali impostate in `.env` (`NEXTCLOUD_ADMIN_USER` / `NEXTCLOUD_ADMIN_PASSWORD`).

---

## Backup e Google Drive (infra-tools)

Il container `infra-tools` esegue automaticamente un backup compresso giornaliero (alle 03:00) in `./backups/` contenente:
- Dump completo del database MariaDB
- Configurazioni di Nextcloud, Caddy e dnsmasq
- Database e dati di Vaultwarden
- Certificati e chiavi OpenVPN
- File `.env`

I backup locali vengono conservati per il numero di giorni indicato da `BACKUP_RETENTION_DAYS` (default: 14).

### Sincronizzazione con Google Drive (opzionale)
Se desideri salvare i backup anche su Google Drive o avere una cartella sincronizzata con Nextcloud (`/gdrive-sync`):
1. Posiziona la tua configurazione rclone in `./rclone/rclone.conf` con un remote chiamato `gdrive`.
2. In `.env` imposta `BACKUP_UPLOAD_TO_DRIVE=true`.
3. Riavvia infra-tools con `docker compose up -d infra-tools`.

Se `rclone.conf` non è presente, `infra-tools` continuerà regolarmente a creare i backup locali senza alcun errore.

---

## Struttura della Repository

```
.
├── docker-compose.yaml      # Definizione di tutti i servizi dello stack
├── Caddyfile                # Reverse proxy TLS parametrizzato
├── .env.example             # Template delle variabili di configurazione
├── .env                     # File locale con password e configurazioni (non committato)
├── scripts/
│   ├── setup.sh             # Inizializzazione automatica dell'infrastruttura
│   ├── init-vpn.sh          # Generatore PKI e profili client OpenVPN
│   └── legacy-switch-from-baremetal.sh
├── infra-tools/             # Container per backup programmato e sync Drive
│   ├── Dockerfile
│   ├── entrypoint.sh
│   └── backup.sh
├── dnsmasq_conf/            # DNS locale con supporto a configurazioni custom
├── openvpn_keys/            # Certificati, configurazione e profili client OpenVPN
├── rclone/                  # Cartella per rclone.conf (opzionale)
└── backups/                 # Cartella archivi di backup locali
```

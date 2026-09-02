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

## Configurazione Firewall e Rete (VPS / VM)

Essendo un'architettura progettata per la massima sicurezza, **i servizi interni (Nextcloud, Vaultwarden) non devono mai essere esposti direttamente su Internet**. L'unico punto di ingresso è la VPN. 

Devi assicurarti che il firewall del tuo sistema operativo (es. `ufw` o `iptables`) e, **cosa fondamentale**, il firewall esterno fornito dal tuo provider Cloud (nella loro dashboard web) abbiano le seguenti regole:

| Porta | Protocollo | Azione | Motivo |
|---|---|---|---|
| **1194** | **UDP** | 🟢 **APRIRE** | Porta di accesso per OpenVPN (il valore è personalizzabile in `.env`) |
| **22** | TCP | 🟢 **APRIRE** | SSH (Necessaria per non tagliarti fuori dall'amministrazione del server!) |
| **80 / 443** | TCP | 🔴 **BLOCCARE** | Caddy e interfacce web (accessibili solo dall'interno della VPN) |
| **8080 / 8081** | TCP | 🔴 **BLOCCARE** | Porte locali di bind per Nextcloud e Vaultwarden |
| **53** | UDP / TCP | 🔴 **BLOCCARE** | dnsmasq (bloccarla all'esterno evita di subire attacchi di DNS Amplification) |

> ⚠️ **MOLTO IMPORTANTE:** Configurare queste regole tramite riga di comando sul server (es. con `ufw`) a volte non è sufficiente. **Devi accedere all'interfaccia web della tua VPS / Virtual Machine fornita dal provider** (es. pannello di controllo AWS, Hetzner, Aruba, OVH, Oracle Cloud, ecc.) e verificare che il loro "Security Group" o "Cloud Firewall" permetta esplicitamente il traffico in ingresso sulla porta **UDP 1194**. Se questa porta è bloccata a monte, il client VPN non riuscirà mai a connettersi.

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

## Backup e Ripristino Completo (Cold)

Oltre al backup automatico in background descritto sopra, sono disponibili due script per eseguire un salvataggio o un ripristino integrale dell'infrastruttura (inclusi i file personali salvati su Nextcloud). Poiché questi file possono essere molto pesanti, il backup completo viene effettuato "a freddo", fermando temporaneamente i servizi per garantire l'assoluta integrità dei dati e del database.

### Eseguire un backup offline
Per creare un archivio `tar.gz` completo dell'intera directory di progetto (ideale prima di un aggiornamento o per migrare server):
```bash
./scripts/backup-full.sh
```
I container verranno messi in pausa, verrà generato l'archivio nella cartella `backups/` e poi i servizi ripartiranno da soli.

### Ripristinare un backup offline
Se stai spostando l'infrastruttura su una nuova VPS o vuoi recuperare un disastro, clona la repository (se necessario), procurati l'archivio `tar.gz` ed esegui lo script di ripristino passandogli il percorso del file. **Attenzione: questo comando andrà a sovrascrivere l'infrastruttura corrente!**
```bash
./scripts/restore-full.sh ./backups/nome_archivio.tar.gz
```
Lo script si occuperà di spegnere i container, estrarre i file rimpiazzando lo stato attuale, e riavviare l'ambiente.

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
│   ├── backup-full.sh       # Script per il backup completo offline
│   ├── restore-full.sh      # Script per il ripristino da backup offline
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

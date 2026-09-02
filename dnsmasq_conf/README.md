# Dnsmasq Configuration

I record DNS principali per i servizi dell'infrastruttura vengono generati automaticamente
dalle variabili definite nel file `.env`:

- `VPN_DOMAIN` (default: `vpn.local`)
- `VPN_SERVER_IP` (default: `10.8.0.1`)
- `NEXTCLOUD_DOMAIN` (default: `nextcloud.vpn.local`)
- `VAULTWARDEN_DOMAIN` (default: `vault.vpn.local`)

Tutti i domini sopra indicati risolvono automaticamente all'indirizzo IP del server VPN (`VPN_SERVER_IP`).

## Aggiunta di record DNS personalizzati

Puoi inserire in questa cartella qualsiasi file con estensione `.conf`.
Verrà caricato automaticamente all'avvio del container dnsmasq.

Esempio `extra-hosts.conf`:
```
address=/myservice.vpn.local/10.8.0.1
```

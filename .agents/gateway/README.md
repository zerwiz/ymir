# BIFROST — Reverse Proxy & Gateway

HTTP routing, external traffic ingress, WebSocket tunneling, and authentication guard.

## Planned Files
- `nginx.conf` — routes UI, WebSocket streams, webhook listeners

## Routes
- `/` → Hlidskjalf portal
- `/files/` → Skrymir file browser
- `/webhooks/github` → Mjollnir issue listener
- `/oauth2/` → Heimdall GitHub OAuth
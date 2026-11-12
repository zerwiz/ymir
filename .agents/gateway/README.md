# BIFROST — Reverse Proxy & Gateway

HTTP routing, external traffic ingress, WebSocket tunneling, and authentication guard.

## Planned Files
- `nginx.conf` — routes UI, WebSocket streams, webhook listeners

## Routes
- `/` → Hlidskjalf portal
- `/files/` → Skrymir file browser
- `/webhooks/github` → Mjollnir issue listener
- `/oauth2/` → Heimdall GitHub OAuth

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.

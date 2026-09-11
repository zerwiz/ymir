# zerwizserver — Live Server Inventory

**Server:** `zerwizserver` — Tailscale IP `100.88.238.83`
**OS:** Ubuntu 24.04.4 LTS (Noble Numbat)
**SSH:** `ssh zerwizserver@100.88.238.83` (user: `zerwizserver`, key: `~/.ssh/id_ed25519`)
**Last scanned:** 2025-09-09

---

## Cloudflare Tunnels — Hostname → Port Mapping

### wayofteams tunnel (`9485e944`)
| Hostname | Port | Service |
|---|---|---|
| `teams.zerwiz.org` | 4321 | WayOfTeams main app (Node/Elixir) |
| `teamsapp.zerwiz.org` | 4000 | WayOfTeams teamsapp (beam.smp) |
| `investwayofteams.zerwiz.org` | 5179 | Investor data room (Node) |
| `ws1.zerwiz.org` – `ws10.zerwiz.org` | 3101–3110 | WebSocket workers |

### prdteams tunnel (`3d7c8887`)
| Hostname | Port | Service |
|---|---|---|
| `prdteams.zerwiz.org` | 3910 | Bun-based prod teams app |

### wayofcollab tunnel (`8818d377`)
| Hostname | Port | Service |
|---|---|---|
| `collab.zerwiz.org` | 4003 | WayOfCollab (beam.smp) |

### anchor tunnel (`4a1c9ad2`)
| Hostname | Port | Service |
|---|---|---|
| `anchor.zerwiz.org` | 42777 | Anchor app (beam.smp) |

### cloudsync tunnel (`5b1ab09b`)
| Hostname | Port | Service |
|---|---|---|
| `cloudsync.zerwiz.org` | 4214 | CloudSync hub (Docker, healthy) |

### whynot tunnel (`9bd8bec7`)
| Hostname | Port | Service |
|---|---|---|
| `zerwiz.org` / `www.zerwiz.org` | 4322 | WhyNot Homepage (Node) |
| `supabase.zerwiz.org` | 8000 | Supabase stack (Crafty controller) |

### Other tunnels
| Tunnel | Hostname | Port | Service |
|---|---|---|---|
| `aigeeksandfreaks` | `aigeeksandfreaks.zerwiz.org` | 3800 | Next.js blog/marketing (bun) |
| `dojo` | `dojo.zerwiz.org` | 8038 | Dojo (beam.smp) |
| `dojo-dev` | — | — | Dojo dev (no routes) |
| `dojo-dual-chat` | — | — | Dojo dual chat (no routes) |
| `dojo-fallback` | — | — | Dojo fallback (no routes) |
| `dojo-prod` | — | — | Dojo prod (no routes) |
| `linuxcommand` | `linuxcommand.zerwiz.org` | 4601 | Factory visualizer (bun) |
| `masterplanhomepage` | `masterplan.zerwiz.org` | 3900 | Masterplan homepage (bun) |
| `obsidian-livesync` | `obsidian-sync.zerwiz.org` | 5984 | Obsidian LiveSync (bun) |
| `obsidian` | `obsidian.zerwiz.org` | 15323 | Obsidian (bun) |
| `opticat` | `opticat.zerwiz.org` | 8083 | OptiCat web server (Python) |
| `todo` | `todo.zerwiz.org` | — | Todo (no active routes) |
| `casaos` | `casaos.zerwiz.org` | 80 | CasaOS gateway |
| `zerwiz-win` | `zerwiz-win.zerwiz.org` | — | Windows mirror tunnel (no routes) |
| `forgejo` | `forgejo.zerwiz.org` | 3030 | Forgejo git server (Docker) |

---

## Running Services

### Elixir/Beam Applications
| Process | App | Port | Uptime |
|---|---|---|---|
| `beam.smp` (pid 467486) | WayOfTeams (phx.server) | 4321, 4000 | ~3 days |
| `beam.smp` (pid 470171) | WayOfTeams (secondary) | — | ~3 days |
| `beam.smp` (pid 126487) | Anchor | 42777 | ~9 days |
| `beam.smp` (pid 468885) | WayOfTeams (node proxy) | 4321 | — |
| `beam.smp` (pid 467486) | WayOfCollab | 4003 | — |

### Node.js Applications
| Process | App | Port |
|---|---|---|
| `server.mjs` (pid 1799) | WhyNot Homepage | 4322 |
| `Postiz API` (pm2) | Postiz social scheduler | 4007 (Docker) |
| `Postiz Worker` (pm2) | Postiz worker | — |
| `Mautic web` (pm2) | Mautic email marketing | 8001 (Docker) |
| `Activepieces` (Docker) | Workflow automation | 8080 (Docker) |
| `Temporal` (Docker) | Durable workflows | 7233 (Docker) |
| `aigeeksandfreaks` (pm2) | Next.js marketing blog | 3800 |
| `prdteams` (bun) | Prod teams app | 3910 |
| `linuxcommand` (bun) | Factory visualizer | 4601 |
| `masterplanhomepage` (bun) | Masterplan homepage | 3900 |
| `obsidian-livesync` (bun) | Obsidian sync | 5984 |
| `opticat` (Python) | OptiCat web server | 8083 |

### Docker Containers
| Container | Image | Port Mapping | Status |
|---|---|---|---|
| `forgejo` | codeberg.org/forgejo/forgejo:16.0.2 | 3030 | Up 2 days |
| `docker-cloudsync-1` | cloudsync:latest | 127.0.0.1:4214 | Up 6 days (healthy) |
| `homepage` | gethomepage/homepage:latest | 127.0.0.1:3000 | Up 9 days (healthy) |
| `postiz` | gitroomhq/postiz-app:latest | 127.0.0.1:4007 | Up 9 days (healthy) |
| `postiz-postgres` | postgres:17-alpine | 5432 | Up 9 days (healthy) |
| `postiz-redis` | redis:7.2 | 6379 | Up 9 days (healthy) |
| `mautic-web` | mautic/mautic:7.0.1-apache | 127.0.0.1:8001 | Up 9 days |
| `mautic-db` | mariadb:10.11 | 3306 | Up 9 days (healthy) |
| `mautic-cron` | mautic/mautic:7.0.1-apache | 80 | Up 9 days |
| `mautic-worker` | mautic/mautic:7.0.1-apache | 80 | Up 9 days |
| `activepieces` | ghcr.io/activepieces/activepieces:latest | 8080 | Up 9 days |
| `activepieces-postgres` | postgres:16-alpine | 5432 | Up 9 days (healthy) |
| `activepieces-redis` | redis:7-alpine | 6379 | Up 9 days |
| `temporal` | temporalio/auto-setup:1.28.1 | 7233 | Up 9 days (healthy) |
| `temporal-postgresql` | postgres:16 | 5432 | Up 9 days (healthy) |
| `temporal-elasticsearch` | elasticsearch:7.17.27 | 9200, 9300 | Up 9 days (healthy) |
| `temporal-ui` | temporalio/ui:2.34.0 | 127.0.0.1:8082 | Up 9 days (healthy) |
| `temporal-admin-tools` | temporalio/admin-tools | — | Up 9 days |
| `grafana` | grafana/grafana:13.0.1 | 0.0.0.0:3003 | Up 9 days |
| `crafty-container` | crafty-controller/crafty-4:4.10.4 | 8111, 8112, 19132, 25500-25600 | Up 9 days |
| `immich-redis` | redis:6.2.20-alpine | 6379 | Up 9 days |
| `docker-postgres-1` | postgres:16-alpine | 5432 | Up 9 days (healthy) |

### Other Services
| Service | Port | Notes |
|---|---|---|
| PostgreSQL (host) | 5432 | Multiple instances (WayOfTeams, CloudSync, etc.) |
| Redis (host) | 6379 | Multiple instances (dnsmasq/pid-based) |
| Elasticsearch | 9200, 9300 | Docker (temporal) |
| Samba | 139, 445 | File sharing |
| SSH | 22 | Tailscale + standard |
| LM Studio (local) | 1234 | On server? (likely local machine) |
| Ollama | 11434 | On server? (likely local machine) |
| CUPS | 631 | Printing |
| systemd-resolved | 53 | DNS |

---

## Projects on Server (`/home/zerwizserver/`)

| Project | Description |
|---|---|
| `wayofteams` | Main SaaS app (Phoenix, 44 dirs) |
| `prdteams` | Prod teams app (7 dirs) |
| `cloudsync` | CloudSync hub service |
| `aigeeksandfreaks` | Marketing blog/platform |
| `anchor` | Anchor app |
| `wayofcollab` | WayOfCollab (17 dirs) |
| `investwayofteams` | Investor data room |
| `masterplanhomepage` | Masterplan homepage |
| `whynothomepage` | WhyNot Productions homepage |
| `opticat` | OptiCat HVAC app (41 dirs) |
| `sensualdojocouple` | Sensual Dojo (19 dirs) |
| `obsidian-livesync` | Obsidian sync service |
| `forgejo` / `forgejo-backups` | Git server + backups |
| `searxng` | Search engine |
| `backups` | Backup storage |
| `flutter` | Flutter SDK |

---

## Key Facts

- **Production host** for the entire WayOf ecosystem
- **26 Cloudflare tunnels** configured (many with no active DNS routes)
- **3 Elixir/Beam apps** running: WayOfTeams, Anchor, WayOfCollab
- **Docker** runs 20+ containers (Postiz, Mautic, Activepieces, Temporal, Grafana, Forgejo, CloudSync, etc.)
- **CasaOS** installed for app management
- **Crafty controller** running (Minecraft server? ports 19132, 25500-25600)
- **Forgejo** self-hosted Git (codeberg.org/forgejo/forgejo:16.0.2)
- **Supabase** stack behind `supabase.zerwiz.org` (port 8000 via Crafty)
- **SearXNG** private search engine
- **Obsidian LiveSync** for document sync
- **Temporal** for durable workflow orchestration
- **Grafana** for dashboards (port 3003)
- **Postiz** for social media scheduling
- **Mautic** for email marketing
- **Activepieces** for workflow automation

# Server Knowledge Base — zerwizserver (100.88.238.83)

**Last Updated:** 2026-09-09  
**Server:** zerwizserver (Tailscale IP: 100.88.238.83, user: `zerwizserver`)  
**SSH Key:** `~/.ssh/id_ed25519`  
**OS:** Ubuntu-based (systemd, devbox, Docker)

---

## 1. Cloudflare Tunnels

All tunnels run via `cloudflared` as systemd services or background processes. Configs in `/home/zerwizserver/.cloudflared/`.

| Tunnel Config | Hostname(s) | Local Service | Port | Tunnel ID | Status |
|---------------|-------------|---------------|------|-----------|--------|
| `config.yml` (default) | `aigeeksnfreaks.zerwiz.org` | aigeeksandfreaks | 3800 | e3a203ac... | Active |
| `config-anchor.yml` | `anchor.zerwiz.org` | Anchor MCP | 42777 | 4a1c9ad2... | Active |
| `config-casaos.yml` | `casaos.zerwiz.org` | CasaOS | 80 | 97afb921... | Active |
| `config-cloudsync.yml` | `cloudsync.zerwiz.org` | CloudSync Hub | 4214 | 5b1ab09b... | Active |
| `config-forgejo.yml` | `forgejo.zerwiz.org` | Forgejo | 3030 | 9525857c... | Active |
| `config-masterplan.yml` | `masterplan.zerwiz.org` | Masterplan | 3900 | 31df7acd... | Active |
| `config-obsidian-livesync.yml` | `obsidian-sync.zerwiz.org` | Obsidian LiveSync (CouchDB) | 5984 | 636a31d9... | Active |
| `config-obsidian.yml` | `obsidian.zerwiz.org` | Obsidian | 15323 | c5d8408e... | Active |
| `config-opticat.yml` | `opticat.zerwiz.org` | Opticat | 8083 | 4ba48d45... | Active |
| `config-prdteams.yml` | `prdteams.zerwiz.org` | PRD Teams | 3910 | 3d7c8887... | Active |
| `config-wayofcollab.yml` | `collab.zerwiz.org` | WayOfCollab | 4003 | 8818d377... | Active |
| `config-wayofteams.yml` | `teams.zerwiz.org` | WayOfTeams Phoenix | 4321 | 9485e944... | Active |
| | `teamsapp.zerwiz.org` | WayOfTeams Astro | 4000 | | |
| | `investwayofteams.zerwiz.org` | Invest WayOfTeams | 5179 | | |
| | `ws1-10.zerwiz.org` | Workspaces 1-10 | 3101-3110 | | |
| `config-whynot.yml` | `zerwiz.org`, `www.zerwiz.org` | WhyNot Homepage | 4322 | 9bd8bec7... | Active |
| | `supabase.zerwiz.org` | Supabase | 8000 | | |

### Tunnel Management
```bash
# Start a specific tunnel
cloudflared tunnel --no-autoupdate --config /home/zerwizserver/.cloudflared/config-<name>.yml run

# Check tunnel status
pgrep -f "cloudflared.*config-<name>.yml"

# View logs
tail -f /home/zerwizserver/tunnel-<name>.log

# Systemd services (auto-start on boot)
systemctl status cloudflared-aigeeksandfreaks.service
systemctl status cloudsync-tunnel.service
```

---

## 2. Running Services & Processes

### Core Infrastructure

| Service | Process / Container | Port(s) | PID / Container | Start Command |
|---------|---------------------|---------|-----------------|---------------|
| **Ollama** | `/usr/local/bin/ollama serve` | 11434 | PID 3176 | `systemctl start ollama` |
| **LM Studio** | (user-managed) | 1234 | N/A | Manual / Desktop app |
| **PostgreSQL (system)** | `postgres` (multiple clusters) | 5432, 5444, 5433... | PIDs 4569, 4591, 4620, 5704... | `systemctl start postgresql@16-main` |
| **Redis** | `redis-server *:6379` | 6379 | PIDs 4589, 4636, 4839 | `systemctl start redis-server` |
| **MariaDB** | `mariadbd` | 3306 | PID 4754 | `systemctl start mariadb` |
| **Docker** | `dockerd` | N/A | N/A | `systemctl start docker` |
| **CasaOS** | Multiple systemd services | 80 | N/A | `systemctl start casaos` |
| **NGINX** | `nginx: worker process` | 80/443 | PIDs 8258-8265 | `systemctl start nginx` |
| **Apache** | `apache2 -DFOREGROUND` | 80 | PIDs 8607-8611 | `systemctl start apache2` |
| **Grafana** | `grafana server` | 3003 | Container `grafana` | `docker start grafana` |
| **Elasticsearch** | `org.elasticsearch.bootstrap.Elasticsearch` | 9200/9300 | PID 8169 (container) | `docker start temporal-elasticsearch` |
| **Temporal** | `temporal-server` + UI + admin | 7233, 8082 | Container `temporal`, `temporal-ui` | `docker compose up -d` |

### Devbox Projects (Elixir/Phoenix)

| Project | Path | Port | DB | Start Script | Status |
|---------|------|------|----|--------------|--------|
| **Anchor** | `/home/zerwizserver/anchor` | 42777 | anchor_prod (PG 5432) | `scripts/startzerwiz.sh` | Config ready |
| **CloudSync** | `/home/zerwizserver/cloudsync` | 4214 | cloudsync (Docker PG) | `scripts/startprod.sh` | Running (container) |
| **WayOfCollab** | `/home/zerwizserver/wayofcollab` | 4003 | wayofcollab_prod (PG 5444) | `scripts/startprod.sh` | Config ready |
| **WayOfTeams** | `/home/zerwizserver/wayofteams` | 4000/4321 | wayofteams_prod (PG 5432) | `scripts/cloudflare/startprod.sh` | Config ready |

### Web Applications (Node/Next.js)

| App | Path | Port | Framework | Start Command | Tunnel |
|-----|------|------|-----------|---------------|--------|
| **Invest WayOfTeams** | `/home/zerwizserver/investwayofteams` | 5179 | Vite | `npm run preview` | `investwayofteams.zerwiz.org` |
| **WayOfTeams (Astro)** | `/home/zerwizserver/wayofteams/astro` | 4321 | Astro | `npm run preview` | `teams.zerwiz.org` |
| **Chat Server** | `/home/zerwizserver/wayofteams/chat-server` | 9877 | Node (ESM) | `node chat-server.mjs` | Internal |
| **AI Geeks & Freaks** | `/home/zerwizserver/aigeeksandfreaks` | 3800 | Next.js (Bun) | `bun .next/standalone/server.js` | `aigeeksnfreaks.zerwiz.org` |
| **PRD Teams** | `/home/zerwizserver/prdteams` | 3910 | Next.js | `npm run start` | `prdteams.zerwiz.org` |
| **Opticat** | `/home/zerwizserver/opticat` | 8083 | Next.js/Electron | `npm run start` | `opticat.zerwiz.org` |
| **WhyNot Homepage** | `/home/zerwizserver/whynothomepage` | 4322 | Next.js | `npm run start` | `zerwiz.org` |
| **Masterplan Homepage** | `/home/zerwizserver/masterplanhomepage` | 3900 | Next.js | `npm run start` | `masterplan.zerwiz.org` |

### Docker Containers (Running)

| Container | Image | Ports | Purpose |
|-----------|-------|-------|---------|
| `docker-cloudsync-1` | `cloudsync:latest` | 4214 | CloudSync Hub |
| `homepage` | `ghcr.io/gethomepage/homepage` | 3000 | Dashboard |
| `activepieces` | `ghcr.io/activepieces/activepieces` | 8080 | Automation |
| `temporal` | `temporalio/auto-setup` | 7233 | Temporal Server |
| `temporal-ui` | `temporalio/ui` | 8082 | Temporal UI |
| `temporal-admin-tools` | `temporalio/admin-tools` | — | Temporal CLI |
| `temporal-elasticsearch` | `elasticsearch:7.17.27` | 9200/9300 | Temporal ES |
| `temporal-postgresql` | `postgres:16` | 5432 | Temporal DB |
| `postiz` | `gitroomhq/postiz-app` | 4007 | Social Scheduler |
| `postiz-postgres` | `postgres:17-alpine` | 5432 | Postiz DB |
| `postiz-redis` | `redis:7.2` | 6379 | Postiz Redis |
| `mautic-web` | `mautic/mautic` | 8001 | Marketing |
| `mautic-cron` | `mautic/mautic` | — | Mautic Cron |
| `mautic-worker` | `mautic/mautic` | — | Mautic Worker |
| `mautic-db` | `mariadb:10.11` | 3306 | Mautic DB |
| `forgejo` | `codeberg.org/forgejo/forgejo` | 3030 | Git Forge |
| `grafana` | `grafana/grafana` | 3003 | Metrics |
| `crafty-container` | `crafty-controller` | 8112, 8443, 25500-25600 | Minecraft Manager |
| `immich-redis` | `redis:6.2.20-alpine` | 6379 | Immich Redis |

### Database Instances

| Database | Host | Port | User | Database(s) | Access |
|----------|------|------|------|-------------|--------|
| PostgreSQL (system) | localhost | 5432 | wayofteams, anchor, forgejo, postiz | wayofteams_prod, anchor_prod, forgejo, postiz-db-local | Local + Tunnel |
| PostgreSQL (WayOfCollab) | localhost | 5444 | wayofcollab | wayofcollab_prod | Local |
| PostgreSQL (Docker) | localhost | 5432 (various) | various | temporal, postiz, mautic | Container |
| MariaDB | localhost | 3306 | mautic | mautic | Local |
| Redis | localhost | 6379 | — | — | Local |
| Elasticsearch | localhost | 9200 | — | temporal | Container |
| CouchDB | localhost | 5984 | — | obsidian-sync | Tunnel |

---

## 3. Devbox Projects — Details

### Anchor
- **Path:** `/home/zerwizserver/anchor`
- **Port:** 42777 (MCP), 5432 (PG)
- **Database:** `anchor_prod` (user: `anchor`)
- **Start:** `./scripts/startzerwiz.sh` / `./scripts/startzerwiz.sh --no-tunnel`
- **Tunnel:** `anchor.zerwiz.org` → localhost:42777
- **Env:** `.env.production` (DB_PASS, ANCHOR_API_KEYS, EMBED_MODEL, SUMMARIZE_MODEL)

### CloudSync
- **Path:** `/home/zerwizserver/cloudsync`
- **Port:** 4214
- **Database:** PostgreSQL in Docker (`postgres:5432`)
- **Start:** `./scripts/startprod.sh` (uses Docker Compose)
- **Tunnel:** `cloudsync.zerwiz.org` → localhost:4214
- **Env:** `.env.production` → `docker/app.env`
- **Systemd:** `cloudsync-tunnel.service`

### WayOfCollab
- **Path:** `/home/zerwizserver/wayofcollab`
- **Port:** 4003 (Phoenix), 5444 (PG)
- **Database:** `wayofcollab_prod` (user: `wayofcollab`, PGDATA: `~/.pgdata-collab`)
- **Start:** `./scripts/startprod.sh`
- **Tunnel:** `collab.zerwiz.org` → localhost:4003
- **Env:** `.env` (DATABASE_URL, SECRET_KEY_BASE)

### WayOfTeams
- **Path:** `/home/zerwizserver/wayofteams`
- **Ports:** 4000 (API), 4321 (Phoenix), 9877 (Chat), 3002 (PostgREST), 4321 (Astro), 3101-3110 (Workspaces)
- **Database:** `wayofteams_prod` (user: `wayofteams`, PG 5432)
- **Start (dev):** `./scripts/cloudflare/start.sh`
- **Start (prod):** `./scripts/cloudflare/startprod.sh`
- **Tunnels:** `config-wayofteams.yml` (multi-hostname)
- **Env:** `.env` (prod), `.env.example` (template)

---

## 4. Utility Services

| Service | Description | Management |
|---------|-------------|------------|
| **CasaOS** | App platform/dashboard | `systemctl start/stop/status casaos*` |
| **CUPS** | Printing | `systemctl start/stop cups cups-browsed` |
| **dnsmasq** | Local DNS/DHCP | `systemctl start/stop dnsmasq` |
| **SSH** | Remote access | `systemctl start/stop ssh` |
| **Forgejo Backup** | Daily backup timer | `systemctl start/stop forgejo-backup.timer` |
| **logrotate** | Log rotation | `systemctl start/stop logrotate.timer` |

---

## 5. Startup Scripts Summary

### WayOfTeams (Primary)
```bash
# Development
cd /home/zerwizserver/wayofteams && ./scripts/cloudflare/start.sh

# Production
cd /home/zerwizserver/wayofteams && ./scripts/cloudflare/startprod.sh

# Stop all
./scripts/cloudflare/stop-all.sh
```

### CloudSync
```bash
cd /home/zerwizserver/cloudsync && ./scripts/startprod.sh
# Uses Docker Compose: docker compose -f docker/docker-compose.yml up -d
```

### Anchor
```bash
cd /home/zerwizserver/anchor && ./scripts/startzerwiz.sh
# With --no-tunnel flag to skip Cloudflare
```

### WayOfCollab
```bash
cd /home/zerwizserver/wayofcollab && ./scripts/startprod.sh
# Sets up own PG on 5444, runs migrations, starts Phoenix, restarts tunnel
```

### Web Apps (Next.js/Vite)
```bash
# All use similar pattern
cd /home/zerwizserver/<app> && npm run build && npm run start
# Or for Bun-based: bun .next/standalone/server.js
```

---

## 6. Service Dependencies

```
┌─────────────────────────────────────────────────────────────┐
│                    zerwizserver                             │
├─────────────────────────────────────────────────────────────┤
│  Systemd Services                                           │
│  ├── ollama.service          → Ollama (port 11434)         │
│  ├── postgresql@16-main      → System PG (port 5432)       │
│  ├── redis-server            → Redis (port 6379)           │
│  ├── mariadb                 → MariaDB (port 3306)         │
│  ├── docker.service          → Docker Engine               │
│  ├── casaos*.service         → CasaOS (port 80)            │
│  ├── nginx                   → Reverse proxy (80/443)      │
│  ├── cloudflared-*.service   → Cloudflare Tunnels          │
│  └── cloudsync-tunnel.service → CloudSync Tunnel           │
├─────────────────────────────────────────────────────────────┤
│  Docker Compose Stacks                                      │
│  ├── Temporal Stack (temporal, temporal-ui,                │
│  │   temporal-postgresql, temporal-elasticsearch)          │
│  ├── CloudSync Stack (cloudsync + postgres)                │
│  ├── Postiz Stack (postiz + postgres + redis)              │
│  ├── Mautic Stack (mautic-web/worker/cron + mariadb)       │
│  ├── Forgejo (forgejo + postgres)                          │
│  ├── Grafana                                               │
│  └── Immich (postgres + redis)                             │
├─────────────────────────────────────────────────────────────┤
│  Devbox Projects (require devbox, Elixir, Node)            │
│  ├── Anchor (PG 5432) → config-anchor.yml tunnel           │
│  ├── CloudSync (Docker PG) → config-cloudsync.yml tunnel   │
│  ├── WayOfCollab (PG 5444) → config-wayofcollab.yml tunnel │
│  └── WayOfTeams (PG 5432) → config-wayofteams.yml tunnel   │
├─────────────────────────────────────────────────────────────┤
│  Web Apps (Node/Bun)                                        │
│  ├── investwayofteams (5179) → wayofteams tunnel           │
│  ├── wayofteams/astro (4321) → wayofteams tunnel           │
│  ├── chat-server (9877) → internal                         │
│  ├── aigeeksandfreaks (3800) → config.yml tunnel           │
│  ├── prdteams (3910) → config-prdteams.yml tunnel          │
│  ├── opticat (8083) → config-opticat.yml tunnel            │
│  ├── whynothomepage (4322) → config-whynot.yml tunnel      │
│  └── masterplanhomepage (3900) → config-masterplan.yml     │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. Backup Mechanisms

| Backup | Schedule | Location | Retention | Command |
|--------|----------|----------|-----------|---------|
| **Forgejo** | Daily (systemd timer) | `/home/zerwizserver/forgejo-backups/` | 14 days | `/home/zerwizserver/forgejo-backup.sh` |
| **WayOfTeams DB** | On deploy (startprod.sh) | `/home/zerwizserver/wayofteams/.deploy-backups/` | Manual | `pg_dump` in startprod.sh |
| **Anchor DB** | On deploy (startprod.sh) | `/home/zerwizserver/wayofteams/.deploy-backups/` | Manual | `pg_dump` in startprod.sh |
| **WayOfCollab DB** | On deploy (startprod.sh) | `/home/zerwizserver/wayofcollab/.deploy-backups/` | Manual | `pg_dump` in startprod.sh |
| **CloudSync** | Manual | N/A | N/A | Docker volume backup |
| **General** | Manual | `/home/zerwizserver/backups/` | Manual | User-initiated |

---

## 8. Disk Usage

```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb2       228G  184G   32G  86% /
```

**Note:** 86% usage — monitor and clean Docker images, old logs, backups periodically.

---

## 9. Key Configuration Files

| File | Purpose |
|------|---------|
| `/home/zerwizserver/.cloudflared/config-*.yml` | Cloudflare tunnel configs |
| `/home/zerwizserver/.cloudflared/*.json` | Tunnel credentials (keep secure) |
| `/home/zerwizserver/<project>/.env*` | Environment variables per project |
| `/home/zerwizserver/.pgpass` | PostgreSQL password file (chmod 600) |
| `/home/zerwizserver/<project>/devbox.json` | Devbox package definitions |
| `/home/zerwizserver/forgejo-backup.sh` | Forgejo backup script |
| `/etc/systemd/system/forgejo-backup.service` | Forgejo backup systemd unit |
| `/etc/systemd/system/forgejo-backup.timer` | Forgejo backup timer |
| `/home/zerwizserver/wayofteams/scripts/cloudflare/*.sh` | WayOfTeams start/stop/deploy scripts |

---

## 10. Quick Reference — Common Operations

### Check Service Health
```bash
# All Phoenix apps
curl http://localhost:4000/health   # WayOfTeams API
curl http://localhost:4321/health   # WayOfTeams Phoenix
curl http://localhost:4003/health   # WayOfCollab
curl http://localhost:42777/health  # Anchor
curl http://localhost:4214/health   # CloudSync

# Web apps
curl http://localhost:5179/         # Invest WayOfTeams
curl http://localhost:3800/         # AI Geeks & Freaks
curl http://localhost:8083/         # Opticat
curl http://localhost:4322/         # WhyNot Homepage
```

### Restart a Service
```bash
# Systemd services
systemctl restart ollama
systemctl restart postgresql@16-main
systemctl restart docker
systemctl restart cloudflared-aigeeksandfreaks

# Docker containers
docker restart <container-name>

# Devbox projects (from project root)
./scripts/cloudflare/stop-all.sh && ./scripts/cloudflare/startprod.sh

# Web apps (Next.js)
pkill -f "next-server" && npm run start
```

### View Logs
```bash
# Systemd
journalctl -u ollama -f
journalctl -u postgresql@16-main -f

# Devbox projects
tail -f /home/zerwizserver/<project>/tunnel-*.log
tail -f /tmp/wayofteams-*.log
tail -f /tmp/anchor-*.log

# Docker
docker logs -f <container-name>

# Cloudflare tunnels
tail -f /home/zerwizserver/tunnel-*.log
```

### Database Access
```bash
# System PostgreSQL
psql -h localhost -p 5432 -U wayofteams -d wayofteams_prod
psql -h localhost -p 5432 -U anchor -d anchor_prod
psql -h localhost -p 5432 -U forgejo -d forgejo

# WayOfCollab PostgreSQL (port 5444)
psql -h localhost -p 5444 -U wayofcollab -d wayofcollab_prod

# Docker PostgreSQL
docker exec -it temporal-postgresql psql -U temporal -d temporal
docker exec -it postiz-postgres psql -U postiz -d postiz
```

---

## 11. Environment Variables (Key)

| Variable | Used By | Typical Location |
|----------|---------|------------------|
| `DATABASE_URL` | All Elixir apps | `.env`, `.env.production` |
| `SECRET_KEY_BASE` | Phoenix apps | `.env` (prod) |
| `PHX_HOST` | WayOfTeams prod | `.env` |
| `ANCHOR_API_KEYS` | Anchor | `.env.production` |
| `LLM_MODEL` | LLM selection | `qwen3.5:2b` (Ollama) |
| `OLLAMA_MODEL` | Anchor LLM | `qwen3.6-35b-a3b@iq3_s` |
| `CHAT_PROVIDER` | WayOfTeams chat | `ollama` / `lmstudio` |
| `POSTGREST_JWT_SECRET` | PostgREST | `.env` |
| `BACKUP_CIPHER_PASSWORD` | Encrypted backups | `.env` (optional) |

---

## 12. Security Notes

- **Tunnel credentials** in `/home/zerwizserver/.cloudflared/*.json` — keep private
- **Database passwords** in `.env*` files and `.pgpass` (chmod 600)
- **Forgejo DB password** in `/home/zerwizserver/.config/forgejo/db-password`
- **SSH access** via Tailscale + ed25519 key only
- **Cloudflare tunnels** expose only specified hostnames; all else returns 404
- **Production deploys** verify DB roles exist; never auto-create (WOTEAMS-268)
- **Backup encryption** available via `BACKUP_CIPHER_PASSWORD` (AES)

---

## 13. Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Tunnel not connecting | cloudflared process dead | `systemctl restart cloudflared-<name>` or manual start |
| Phoenix won't start | Port in use / stale beam | `./scripts/cloudflare/stop-all.sh` then restart |
| PG connection failed | PG not running / wrong port | `systemctl status postgresql@16-main` check port |
| Docker container unhealthy | Health check failing | `docker logs <container>` check dependencies |
| High disk usage | Old Docker images/logs | `docker system prune -a`, clean logs |
| LLM not available | Ollama/LM Studio not running | `systemctl start ollama` or start LM Studio |

---

## 14. Adding a New Service

1. **Create project directory** under `/home/zerwizserver/<name>/`
2. **Add devbox.json** if Elixir/Node project
3. **Create Cloudflare tunnel config** in `/home/zerwizserver/.cloudflared/config-<name>.yml`
4. **Run `cloudflared tunnel login`** and create tunnel, get credentials
5. **Add systemd service** for auto-start (optional)
6. **Document start/stop commands** in project's scripts/
7. **Update this knowledge base**

---

*Generated by firstmate server-knowledge task. Keep updated as services change.*
# YMIR — Agent Operating System

A lean, single-operator agentic OS. Run an entire business, development, and personal life from one repo — powered by an autonomous Norse-named agent fleet.

## Lore (short version)

Ymir is not a theme — the myths are **load-bearing allegory**. The platform is the
primordial giant **Ymir**, slain so that the worlds could stand: **this** Ymir
stands, and from it the realms are carved. The fleet is the dwarf brothers —
**Brokk** at the bellows, **Eindri** at the craft — who out-forged the gods.
**Mimirsbrunn** is the well of memory at the root of **Yggdrasil**: the well is
engram (open-source, single-file vector memory), and **Kaia** is the oracle that
speaks from it. Every action is carved into **Runes** — an append-only ledger — and
the fleet forges for **houses**: Ymir Labs, Brokk Forge, Runestone (Runir), Muninn
Labs, Dvalin, Utgard Studios, Askr, and Mannheim. Work runs through **seven
gates** (Bifrost → Ratatoskr), built on **borrowed anvils** (open source first),
forged first in light metals (TypeScript, Python, React, Vue) and re-forged in
**Rut-steel** once the machine works end to end.

Each house is a real venture; each subsystem name is chosen because the myth
already describes the machine's job. The full tale, realm by realm: [`docs/lore.md`](docs/lore.md).

## System Map

| Subsystem | Norse Name | Role |
|-----------|-----------|------|
| Platform Root | **Ymir** | Master daemon, host OS |
| Main Agent | **Brokk** | Autonomous worker |
| Sub-Agent Workers | **Eindri** | Isolated sandboxed workers |
| Git Worktrees | **Yggdrasil** | Zero-collision parallel edits |
| Docker Sandbox | **Utgard** | Ephemeral execution barrier |
| Gateway | **Bifrost** | Reverse proxy / HTTP routing |
| OAuth Guard | **Heimdall** | GitHub OAuth authentication |
| Tunnel | **Gjallarhorn** | Cloudflare outbound tunnel |
| Dashboard | **Hlidskjalf** | Observability & control plane |
| File Browser | **Skrymir** | Web file explorer |
| Tenants | **Svartalfaheim** | Scoped realm workspaces |
| Shared Space | **Midgard** | Cross-tenant assets & repos |
| Message Bus | **Ratatoskr** | **A2A 1.0 backbone** — agent cards, task lifecycle, Redis queue |
| Vector Memory | **Mimirsbrunn** | **engram store** (SQLite + vec + FTS5) served by Kaia's bridge (`:4602`) |
| Audit Ledger | **Runes** | Append-only system log |
| Issue→PR Pipeline | **Mjollnir** | Autonomous bug fixes & PRs |
| Process Monitor | **Valhalla** | PM2/Docker supervisor |
| Þjazi Backend | **Experimental** | Terminal pane backend for sub-agent visibility (protocol 14+) |
| Skill Synthesis | **Gungnir** | Dynamic skill creation |

## 7 Realms (Ymir Rut)

Seven interlinked daemons, one minting: **Bifrost** (ingress gateway) ·
**Hlidskjalf** (control plane & observability) · **Svartalfaheim** (tenant realm
isolation, `sandbox_isolated`) · **Brokk** (autonomous agent workers) ·
**Utgard** (ephemeral sandboxes, `docker_ephemeral`) · **Yggdrasil** (git
worktree manager, `.treehouses`) · **Ratatoskr** (event bus / A2A backbone).

## Stack — Today vs Target

**Today (agent-proficient — what we build with):**

| Layer | Choice |
|---|---|
| Control plane & daemons | **TypeScript** (Node 22) |
| Agent orchestration | **Python 3.12+** + TypeScript |
| UI / UX | **React + Vue** |
| Inter-agent | **A2A 1.0** (JSON-RPC 2.0 / SSE) + **Redis** |
| Memory | **engram** (`engdbram`) — Mimirsbrunn well |
| Gateway / Auth / Tunnel | Traefik/Caddy · OAuth2-proxy · cloudflared |
| Sandbox | Docker (rootless, network-none) |
| Reused systems | `command-factory` · `firstmate` · `.compliance` |

**Target (Ymir Rut v2.6 — ported later, only after everything works end-to-end):**
Rust (Edition 2024) + Tokio · NATS JetStream · gRPC/Protobuf v3 · libgit2
`.treehouses` · cgroups v2 / seccomp · PostgreSQL 16 · MinIO/S3. One-for-one
re-floor, never a redesign — see [`docs/ymir-rut.md`](docs/ymir-rut.md).

## Design Language

**Carved, not skinned.** Cinzel (rune headings) · JetBrains Mono (code &
telemetry) · Inter (body). Canvas: obsidian slate (`#080c14–#060911`). Accents:
electric cyan (`#38bdf8`, `#0ea5e9`) for Bifrost beams, violet/indigo
(`#818cf8`, `#6366f1`) for the realms, muted slate borders (`#1e293b`,
`#334155`). Emblem: Algiz rune over a blacksmith anvil base, chiseled bevels.
Full spec: [`docs/ymir-rut.md`](docs/ymir-rut.md).

## Docs

- [`docs/lore.md`](docs/lore.md) — the mythos: giant, smiths, the well, the houses
- [`docs/design.md`](docs/design.md) — the design system: carved, not skinned (tokens in [`midgard/design-system/tokens.css`](midgard/design-system/tokens.css))
- [`docs/masterplan.md`](docs/masterplan.md) — the append-only masterplan: every forge order left (W0001–W0025)
- [`docs/Architecture.md`](docs/Architecture.md) — master architecture (7 realms, A2A doctrine, memory, migration path)
- [`docs/ymir-rut.md`](docs/ymir-rut.md) — Ymir Rut v2.6 target spec + reconciliation
- [`docs/plans/README.md`](docs/plans/README.md) — feature plan index (01–25)
- [`docs/append-only-log.md`](docs/append-only-log.md) — every decision, append-only

## Folder Structure

```
ymir/
├── AGENTS.md                    # Core directives for Brokk
├── .env.example                 # Secret template
├── .env.local                   # Local keys (git-ignored)
├── docker-compose.yml           # Master container manifest
├── .gitignore
│
├── .agents/                     # AUTOMATION ENGINE
│   ├── bus/                     # RATATOSKR (event bus)
│   ├── filebrowser/             # SKRYMIR (file access config)
│   ├── gateway/                 # BIFROST (reverse proxy)
│   ├── github/                  # HEIMDALL & MJOLLNIR (webhooks/CI)
│   │   ├── webhooks/
│   │   └── workflows/
│   ├── memory/                  # MIMIRSBRUNN (engram store + Kaia bridge `:4602`)
│   ├── sandbox/                 # UTGARD (isolated execution)
│   ├── skills/                  # GUNGNIR (reusable skills)
│   └── tools/                   # YGGDRASIL (worktree harness)
│
├── midgard/                     # GLOBAL SHARED WORKSPACE
│   ├── design-system/           # Design tokens (tokens.css), icons.md (TBD)
│   ├── shared-packages/
│   ├── infrastructure/
│   ├── company_wiki/
│   └── github_org_repos/
│
├── svartalfaheim/               # MULTI-TENANT REALMS
│   ├── way-of/                   # Company tenant (WOMONO, WOW, OPT)
│   │   ├── .env.realm.example
│   │   ├── Brokk.md
│   │   ├── projects/
│   │   └── workspace/
│   │       ├── company/
│   │       ├── marketing/
│   │       ├── development/
│   │       ├── life/
│   │       └── memory/
│   │           ├── daily/
│   │           └── entity_graph/
│   ├── zerwiz/                   # Personal tenant — zerwiz (Josef)
│   └── craig/                    # Member tenant — craig
│
├── workspace/                   # GLOBAL AUDIT & CONFIG
│   ├── config/
│   │   └── portfolio.md
│   └── memory/
│       └── runes_audit.md
│
├── docs/                        # PLATFORM KNOWLEDGE
│   ├── lore.md                  # THE MYTHOS — the giant, the smiths, the well, the houses
│   ├── Architecture.md          # Master architecture (7 realms, A2A, memory, port path)
│   ├── ymir-rut.md              # Ymir Rut v2.6 target spec + current-stack reconciliation
│   └── plans/                   # Per-feature planning docs (01–25)
│
└── apps/                        # USER INTERFACES
    └── hlidskjalf/              # MASTER CONTROL DASHBOARD
        └── src/
            ├── components/
            ├── services/
            └── app/
```

## Start Here

1. Read the lore — [`docs/lore.md`](docs/lore.md): the giant, the smiths, the well,
   and the houses you're about to work for
2. `cp .env.example .env.local` and fill in your keys
3. Pick a tenant: `svartalfaheim/way-of`, `zerwiz`, or `craig`
4. Read `AGENTS.md` for operational laws
5. Point Brokk at a task — it routes through the appropriate subsystem

## Architecture Trace

> "A webhook hits Bifrost and is queued on Ratatoskr. Ymir allocates resources and launches Brokk. Brokk drinks from Mimirsbrunn (recalls what Kaia remembers about this project), creates a branch via Yggdrasil inside Svartalfaheim, hands execution to Eindri inside an Utgard container. Once tests pass, Mjollnir pushes a Pull Request, the outcome is observed back into the well, Runes logs the entry, and status renders on Hlidskjalf."
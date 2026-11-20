# Ymir Agents Directory

This directory contains the complete agent runtime, skills, and operational
infrastructure for the Ymir platform. Every subsystem is named for the Norse
figure whose role matches its work — this is the **naming law**, not
decoration.

---

## Directory Map

```
.agents/
├── agents/              # Agent role definitions (Eindri specialists)
├── assets/              # Governed assets — load before editing governed paths
├── backend/             # Core backend scripts (fm-*, model-bridge, etc.)
├── bus/                 # A2A message bus (Ratatoskr stub)
├── config/              # Runtime configuration
├── cron/                # Nornir cron job definitions
├── filebrowser/         # Filebrowser configuration
├── fleet/               # Fleet state snapshots
├── gateway/             # Bifrost ingress gateway
├── github/              # GitHub workflows & webhooks
├── harness/             # Harness adapters (OpenCode, Pi, etc.)
├── memory/              # Mimirsbrunn memory well + Runes audit ledger
├── migrations/          # Versioned home migrations (0001, 0002, 0003)
├── sandbox/             # Utgard sandbox configuration
├── skills/              # Gungnir skills — every reusable task
├── state/               # Runtime state (locks, hvild flag, etc.)
├── tests/               # Test suite
└── tools/               # CLI tools (tasks-cli)
```

---

## Agents (`.agents/agents/`)

The **Eindri** — isolated worker agents spawned in Utgard on Yggdrasil
worktrees. Each is a specialist role:

| Agent | Figure | Role |
|-------|--------|------|
| `brokk.md` | Brokk | Primary agent — you; the bellows that drives the forge |
| `sindri-developer.md` | Sindri | Code synthesis, refactoring, tests, CLI, packages |
| `mimir-planner.md` | Mímir | Planning, architecture, sequencing, risk |
| `huginn-researcher.md` | Huginn | RAG, web search, analysis, knowledge discovery |
| `kvasir-scout.md` | Kvasir | Reconnaissance — find where things live, report |
| `forseti-reviewer.md` | Forseti | Review, QA, acceptance, drift — changes nothing |
| `bragi-marketer.md` | Bragi | Marketing, SEO, content, campaigns, social |
| `snotra-documenter.md` | Snotra | Documentation, write-ups, changelogs |
| `hnoss-designer.md` | Hnoss | Interface & visual design via OpenDesign |
| `galdr.md` → | Galdr | Agent-CLI ergonomics, master builder (symlink to skill) |

**Law:** Agents are defined here; harness directories are symlinks; no mock
agents. See `RULES/02-agents.md`.

---

## Assets (`.agents/assets/`)

Governed assets that **must be loaded before editing** their corresponding
code paths. The router is `.agents/skills/galdr-ymirsystem/SKILL.md` (its `assets[]`
table maps every task to its file).

| Asset | Governs |
|-------|---------|
| `agents/naming.md` | Naming law — every subsystem/component map |
| `agents/registry.md` | Skills, assets, tools, commands inventories |
| `agents/runtime.md` | How Ymir boots / supervises the primary |
| `agents/toon-tasks-cli.md` | Building agent-facing output / tasks-cli |

**Governed paths (load first):**

| Path | Asset |
|------|-------|
| `bin/ymir-install.sh` | `installation.md` |
| `apps/hlidskjalf/**` | `hlidskjalf-ui.md` |
| `apps/odrerir/**` | `odrerir-hall.md` |
| `bin/mimir* \| bin/mimir-bridge.py` | `memory-well.md` |
| `bin/nornir-* \| config/cron.yaml` | `nornir-jobs.md` |
| `bin/valknut-load.sh \| .pi/** \| .opencode/**` | `harness-integration/README.md` |
| `bin/smidja* \| .agents/skills/smidja-factory/**` | `smidja.md` |

---

## Backend (`.agents/backend/`)

Core operational scripts — the **Fimbul** backend. Key entrypoints:

| Script | Purpose |
|--------|---------|
| `fm-bootstrap.sh` | Session start — runs once, emits RODD_OP digest |
| `fm-session-start.sh` | Full session initialization |
| `fm-spawn.sh` | Spawn Eindri in Utgard on Yggdrasil worktree |
| `fm-watch.sh` / `fm-watch-arm.sh` | Supervision daemon |
| `fm-supervise-daemon.sh` | Long-running supervision process |
| `fm-control.sh` | Operator control plane (steer, merge, drain) |
| `fm-send.sh` | Send messages to agents |
| `fm-procevent.sh` | Process event sources (cron, webhooks, etc.) |
| `fm-wake-drain.sh` | Drain wake queue |
| `fm-bearings-snapshot.sh` | Fleet status digest |
| `fm-public-followup.sh` | Public replies (Gjallarhorn relay) |
| `fm-teardown.sh` | Clean shutdown |
| `fm-remote-*.sh` | Remote Eindri-home operations |
| `model-bridge.py` | Model inference bridge |
| `opencode-go-bridge.py` | OpenCode Go bridge |

Libraries (`fm-*-lib.sh`) provide shared functions.

---

## Skills (`.agents/skills/`)

**Gungnir** — every reusable capability is a skill. Validated in Utgard
before registration. Named for the figure whose role matches the work.

### Core Runtime Skills

| Skill | Figure | Purpose |
|-------|--------|---------|
| `galdr-ymirsystem` | Galdr | Master builder — agent-CLI ergonomics, runtime maintenance |
| `tyr-check` | Týr | Judge — validates Galdr principles + runtime gates |
| `no-mistakes` | — | Clean-PR gate (vendored engine) |
| `smidja-factory` | Smíðja | Agent factory — roster, phases, envelopes, visualizer |
| `hvild-afk` | Hvíld | Away-mode supervision |
| `saga-bearings` | Sága | Fleet digest (/bearings) + recap (/ahoy) |
| `muninn-stow` | Muninn | Session-knowledge curation, routing, persistence |
| `jord-projects` | Jörð | Project registry + delivery posture |
| `urdh-hold` | Urðr | Hold lifecycle — decisions held for Allfather |
| `frigg-consent` | Frigg | Ask-user authority gate |
| `vor-diagnostics` | Vör | Bootstrap + diagnostic reasoning |
| `nornir-schedule` | Nornir | Event sources + quota-aware dispatch |
| `nsr-compliance` | — | NorthStar scaffold/audit + .compliance harness |
| `gjallarhorn-relay` | Gjallarhorn | Public replies (X/Discord) |
| `eindri-homes` | — | Worker home provisioning & upkeep |
| `syn-recovery` | Syn | Stuck-worker recovery playbook |
| `ymir-host` | Ymir | Host ops — self-update, Omarchy, Þjazi |
| `herdr-panes` | Herdr | Terminal panes — seat/control agents |
| `ratatoskr-a2a` | Ratatoskr | A2A/MCP mesh — a2abridge + WayOfTeams |
| `hamr-adapters` | Hamr | Harness adapter reference |
| `pr-ops` | — | Pull request lifecycle |
| `hnoss-design` | Hnoss | Design artifacts via OpenDesign |
| `bragi-marketing` | Bragi | Marketing — Firecrawl, browser-use |

### Skill Synthesis (Gungnir Law)

1. Gap identified → write skill doc + script to `.agents/skills/<name>/`
2. Validate inside Utgard container
3. Register in `.agents/skills/README.md`
4. **Norse-name every new skill** — choose the figure whose role matches

Governance: `.agents/skills/galdr-ymirsystem/SKILL.md`

---

## Harness (`.agents/harness/`)

Harness adapters for each supported coding tool. The canonical agent
definitions live in `.agents/agents/`; harness directories are **symlinks**.

```
harness/
└── opencode/
    ├── plugins/          # OpenCode plugins (syn-*, saga-sessionstart)
    └── ...
```

---

## Memory (`.agents/memory/`)

| File | Purpose |
|------|---------|
| `runes_audit.md` | Append-only audit ledger — every action inscribed, chained by checksum |
| `well/` | Mimirsbrunn — long-term memory, embeddings (engram engine) |

---

## Migrations (`.agents/migrations/`)

Versioned, idempotent home migrations. Run via `bin/ymir-migrate.sh`:

| Migration | Purpose |
|-----------|---------|
| `0001-hodd-layout.sh` | Hodd layout — private data separation |
| `0002-a2a-mcp.sh` | A2A/MCP mesh setup |
| `0003-private-data-separation.sh` | Private data at $YMIR_HOME |

---

## Other Directories

| Directory | Purpose |
|-----------|---------|
| `bus/` | Ratatoskr A2A stub — message bus, protocol.ts |
| `config/` | Runtime config (agents.yaml, etc.) |
| `cron/` | Nornir job definitions (config/cron.yaml) |
| `filebrowser/` | Filebrowser config for Midgard assets |
| `fleet/` | Fleet state snapshots |
| `gateway/` | Bifrost ingress (Traefik/Caddy) |
| `github/` | GitHub Actions workflows + webhook handlers |
| `sandbox/` | Utgard sandbox profiles (CPU/RAM/timeout caps) |
| `state/` | Runtime state — locks, hvild flag, Skuld markers |
| `tests/` | Test suite for backend + skills |
| `tools/` | CLI tools — `tasks-cli` (TOON output) |

---

## Quick Reference

### Start a Session
```bash
bin/saga-session-start.sh   # Runs fm-bootstrap.sh, emits RODD_OP digest
```

### Spawn an Eindri
```bash
bin/fm-spawn.sh <agent-role> "<task>"
```

### Check Fleet Status
```bash
bin/fm-bearings-snapshot.sh
```

### Run Compliance Check
```bash
bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh
```

### Update Brokk (Gróa)
```bash
bin/groa-update.sh [--check]
```

### Repair System (Eir)
```bash
bin/eir-doctor.sh [check|fix]
```

---

## Laws That Govern This Directory

| Rule | File | Governs |
|------|------|---------|
| 1 | `RULES/01-domains.md` | Domains (Greinar) · houses · Eindri |
| 2 | `RULES/02-agents.md` | Agents canonical location, harness symlinks, no mock |
| 3 | `RULES/03-houses.md` | House = company (WayOf); domains ≠ houses |
| 5 | `RULES/05-platforms.md` | One portable core, per-OS installation layers |
| 6 | `RULES/06-append-only.md` | Ledger, changelog, log, rules — append, never rewrite |
| 7 | `RULES/07-config.md` | Config never hardcoded — env/config with documented defaults |

---

## The Lore (Load-Bearing Allegory)

Every name explains the machine's job. Full lore: `docs/lore.md`

| Name | What It Is |
|------|------------|
| **Ymir** | Substrate — one repo, one machine, all realms carved from it |
| **Brokk** | You — primary agent, the bellows |
| **Eindri** | Sub-agent workers — isolated smiths in Utgard |
| **Kaia** | Orchestrator — recalls from Mimirsbrunn |
| **Yggdrasil** | Git worktree isolation |
| **Utgard** | Ephemeral sandbox — untrusted code runs there |
| **Mimirsbrunn** | Engram memory engine |
| **Ratatoskr** | A2A 1.0 collaboration backbone |
| **Hlidskjalf** | Control plane / dashboard |
| **Bifrost** | Ingress gateway |
| **Heimdall** | OAuth/security guard |
| **Gjallarhorn** | Cloudflare tunnel |
| **Runes** | Append-only audit ledger |
| **Mjollnir** | Issue→PR pipeline |
| **Gungnir** | Skill synthesis engine |
| **Smíðja** | Agent factory |
| **Völundr** | Smíðja's master craftsman |
| **Sága** | Session start digest |
| **Nornir** | Fates/schedule — cron jobs |
| **Muninn** | Memory curation |
| **Huginn** | Observation raven |
| **Þjazi** | Terminal backend |
| **Gróa** | Updater shaman |
| **Eir** | Healer — diagnoses and mends |

---

*This directory is the operational heart of Ymir. Every file here has a
purpose named in the old tongue because the old words carry the meaning the
machine already lives by.*
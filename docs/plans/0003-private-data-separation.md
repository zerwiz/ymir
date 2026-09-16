# Plan 0003 — Private Data Separation for Open-Source Release

**Status:** DRAFT — awaiting Allfather review
**Created:** 2026-09-15
**Owner:** Brokk (primary agent)
**Scope:** Full Ymir repository transformation

---

## 1. The Problem

Ymir is preparing for open-source release via `npm`, `curl`, and direct installation. The current repository contains **operator-private data** that must never leave the machine:

| Category | Current Location | Must Become |
|----------|------------------|-------------|
| Secrets (API keys, tokens, auth) | `.env.local`, `hodd/secrets/` | User's Documents/Ymir/secrets/ |
| Company/tenant identity | `svartalfaheim/`, `hodd/identity/` | User's Documents/Ymir/identity/ |
| Project registries (git remotes, auth refs) | `workspace/projects.yaml` (in Hoard) | User's Documents/Ymir/projects.yaml |
| Workspace registry | `workspace/workspaces.yaml` (in Hoard) | User's Documents/Ymir/workspaces.yaml |
| Personal/work memory | `workspace/memory/`, `workspace/work/`, `workspace/personal/` | User's Documents/Ymir/memory/, work/, personal/ |
| Company-specific domains/projects | **Removed** (single tenant) | N/A |
| Agent/harness config | `config/agents.yaml` | User's Documents/Ymir/config/agents.yaml |
| Per-machine state | `state/`, `data/` | User's Documents/Ymir/state/, data/ |
| Engram memory well | `.agents/memory/kaia.engram*` | User's Documents/Ymir/memory/kaia.engram* |
| Smidja database | `smidja/smidja_data/smidja.db*` | User's Documents/Ymir/smidja/smidja.db* |
| Private docs (masterplan, append-only log) | `$YMIR_HOME/docs/` | User's Documents/Ymir/docs/ |

**Only public artifacts should remain in the repo:**
- Source code (`bin/`, `apps/`, `.agents/skills/`, `.agents/assets/`)
- Public documentation (`docs/`, `README.md`, `CHANGELOG.md`, `LICENSE`, `STRUCTURE.md`, `CONTRIBUTING.md`, `SECURITY.md`, `NOTICE`)
- Example configs (`*.example`, `*.sample`)
- RULES/ (house law)
- Midgard/ (shared company assets — public by design)

---

## 2. The New Architecture

### 2.1 Standard Storage Location

**User's Documents folder** (platform-agnostic):

| Platform | Path |
|----------|------|
| Linux (XDG) | `~/Documents/Ymir/` or `$XDG_DOCUMENTS_DIR/Ymir/` |
| macOS | `~/Documents/Ymir/` |
| Windows (WSL2) | `/mnt/c/Users/<user>/Documents/Ymir/` or `$HOME/Documents/Ymir/` |

The installer will **detect** the Documents folder and **offer it as default**, with an option to choose a custom path.

### 2.2 Ymir Data Root (YMIR_HOME)

```bash
# Environment variable (set by installer, sourced by all scripts)
YMIR_HOME="${YMIR_HOME:-$HOME/Documents/Ymir}"
```

All private data lives under `$YMIR_HOME/`:

```
$YMIR_HOME/
├── config/
│   ├── agents.yaml          # Private agent/harness/model config
│   └── agents.<host>.yaml   # Per-machine overlay
├── secrets/
│   └── platform.env         # All .env.local values (referenced, never inlined)
├── identity/
│   ├── workspaces.yaml      # Workspace registry
│   ├── projects.yaml        # Project registry (git{} blocks, auth refs)
│   └── companies/           # Company entities (private)
├── workspaces/
│   ├── work/
│   │   ├── company/
│   │   ├── marketing/
│   │   ├── development/
│   │   └── life/
│   └── personal/
│       ├── me/
│       ├── life/
│       └── development/
├── memory/
│   ├── daily/               # Daily briefings, runes
│   └── well/                # Mimirsbrunn append log
├── smidja/
│   └── smidja.db*           # Smidja session database
├── state/                   # Runtime state (locks, pids, cron)
└── data/                    # Operational data (backlog, fleet, learnings)
```

### 2.3 Single Private Git Repo for All User Data

**The entire `$YMIR_HOME` is one private git repo** (initialized by user choice), pushed to a **private GitHub repo** for multi-machine sync:

```
$YMIR_HOME/                    # ← git repo root
├── .git/
├── .gitignore                 # ignores smidja/, state/, *.wal, *.shm
├── config/
│   ├── agents.yaml
│   └── agents.<host>.yaml
├── secrets/
│   └── platform.env           # PLAINTEXT — safe in private GitHub repo
├── identity/
│   ├── workspaces.yaml
│   ├── projects.yaml
│   └── companies/
├── workspaces/
│   ├── work/
│   └── personal/
├── memory/
│   ├── daily/
│   └── well/
├── smidja/                    # gitignored — rebuilt per machine
├── state/                     # gitignored — runtime only
└── data/
```

**Secrets handling:** `$YMIR_HOME/secrets/platform.env` committed **as-is** to the private GitHub repo. No local encryption — GitHub's access control protects it. Only the user (and their authorized machines) can clone the private repo.

**Smidja & state:** Gitignored within the private repo (rebuilt per machine).

The installer will:
1. Detect `$YMIR_HOME`
2. Ask: "Initialize a private git repo for all your Ymir data at $YMIR_HOME? [Y/n]"
3. If yes: `git init`, offer `git remote add origin <url>`, create `.gitignore`
4. **Ask for GitHub sync:** "Push to a private GitHub repo for multi-machine sync? [Y/n]"
   - If yes: prompt for `git@github.com:user/private-repo.git`, push
5. Record in `$YMIR_HOME/.ymir-layout.yaml` (including `github_repo` URL)

---

## 3. Installation Transformation

### 3.1 New Installer Flow (`bin/ymir-install.sh`)

**Phase 0 — Choose Storage Location**
```
╭─────────────────────────────────────────────────────────────╮
│  Ymir First Setup                                           │
│                                                             │
│  Where should Ymir store your private data?                 │
│                                                             │
│  ▸ ~/Documents/Ymir/          (recommended, auto-detected)  │
│    ~/Ymir/                    (home directory)              │
│    /custom/path/              (specify your own)            │
│                                                             │
│  This location holds: secrets, projects, workspaces,        │
│  memory, agent config — NEVER committed to the Ymir repo.   │
╰─────────────────────────────────────────────────────────────╯
```

**Phase 1 — Initialize Layout**
```bash
mkdir -p "$YMIR_HOME"/{config,secrets,identity,workspaces/{work,personal},memory,daily,smidja,state,data}
```

**Phase 2 — Single Private Git Repo**
```bash
read -p "Initialize a private git repo for all Ymir data at $YMIR_HOME? [Y/n] "
# if yes: git init, offer remote add, create .gitignore
```

**Phase 3 — Seed from Templates & GitHub Sync Setup**
- Copy `.env.example` → `$YMIR_HOME/secrets/platform.env` (user fills in)
- Copy `config/agents.yaml.example` → `$YMIR_HOME/config/agents.yaml`
- Copy `workspace/projects.yaml.example` → `$YMIR_HOME/identity/projects.yaml`
- Copy `workspace/workspaces.yaml.example` → `$YMIR_HOME/identity/workspaces.yaml`
- Create `$YMIR_HOME/.gitignore` (ignores `smidja/`, `state/`, `*.wal`, `*.shm`, `config/agents.*.yaml`)
- **Ask for private GitHub repo:** "Push this data to a private GitHub repo for multi-machine sync? [Y/n]"
  - If yes: prompt for `git@github.com:user/private-repo.git` (or HTTPS), `git remote add origin`, `git push -u origin main`
- Create `$YMIR_HOME/.ymir-layout.yaml` recording choices (including `github_repo` if set)

**Phase 4 — Symlink/Config References**
- `bin/hodd.sh` reads `YMIR_HOARD=$YMIR_HOME` (not `$ROOT/hodd`)
- `bin/hodd.sh emit` sources `$YMIR_HOME/secrets/platform.env` directly (no decryption needed)
- `bin/agents-config.sh` reads `YMIR_AGENTS_YAML=$YMIR_HOME/config/agents.yaml`
- `bin/realm-lib.sh` reads `$YMIR_HOME/data/realm.md`
- All scripts source `$YMIR_HOME/secrets/platform.env` via `bin/hodd.sh emit`

### 3.2 Backwards Compatibility

For **existing users** (like the Allfather's current machine):
- Installer detects existing `hodd/`, `svartalfaheim/`, `workspace/` in repo
- Offers **one-time migration**: `bin/ymir-migrate.sh private-data`
- Migration copies data to `$YMIR_HOME`, updates symlinks
- Old locations become **deprecated** (read-only, with warnings)

---

## 4. Scripts Requiring Changes

### 4.1 Core Scripts (must read `YMIR_HOME`)

| Script | Current Private Path Reference | New Pattern |
|--------|--------------------------------|-------------|
| `bin/hodd.sh` | `HOARD="${YMIR_HOARD:-$ROOT/hodd}"` | `HOARD="${YMIR_HOARD:-$YMIR_HOME}"` |
| `bin/agents-config.sh` | `CFG="${YMIR_AGENTS_YAML:-$ROOT/config/agents.yaml}"` | `CFG="${YMIR_AGENTS_YAML:-$YMIR_HOME/config/agents.yaml}"` |
| `bin/realm-lib.sh` | `head -n1 "$root/data/realm.md"` | `head -n1 "$YMIR_HOME/data/realm.md"` |
| `bin/ymir-install.sh` | `WORKSPACE="$ROOT/workspace"`, `HOARD="${YMIR_HOARD:-$ROOT/hodd}"` | All paths under `$YMIR_HOME` |
| `bin/ymir-migrate.sh` | `STATE_DIR="$ROOT/state"` | `STATE_DIR="$YMIR_HOME/state"` |
| `bin/eir-doctor.sh` | `STATE="${BROKK_STATE_OVERRIDE:-$ROOT/state}"` | `STATE="${BROKK_STATE_OVERRIDE:-$YMIR_HOME/state}"` |
| `bin/groa-update.sh` | `REG="${BROKK_EINDRI_HOMES:-$ROOT/data/eindri-homes.md}"` | `REG="${BROKK_EINDRI_HOMES:-$YMIR_HOME/data/eindri-homes.md}"` |
| `bin/secret-guard.sh` | Scans `$ROOT` | Scans repo only; `$YMIR_HOME` is never in repo |
| `bin/private-guard.sh` | FORBID patterns include `hodd/`, `svartalfaheim/`, `workspace/` | Remove these from FORBID (they're no longer in repo) |
| `bin/public-guard.sh` | APPEND_ONLY includes `svartalfaheim/` | Remove `svartalfaheim/` from APPEND_ONLY |

### 4.2 Runtime Scripts (state, memory, cron)

| Script | Change |
|--------|--------|
| `bin/nornir-cron-start.sh` | PID/log files → `$YMIR_HOME/state/` |
| `bin/mimir-bridge.sh` | Engram DB → `$YMIR_HOME/memory/kaia.engram` |
| `bin/smidja-bootstrap.sh` | Smidja DB → `$YMIR_HOME/smidja/smidja.db` |
| `bin/saga-session-start.sh` | Digest output → `$YMIR_HOME/state/` |
| All `bin/*-ensure.sh` | Install/check paths relative to `$YMIR_HOME` |

### 4.3 Apps (Hlidskjalf, Óðrerir)

| App | Change |
|-----|--------|
| `apps/hlidskjalf/` | Config reads `$YMIR_HOME/secrets/platform.env` via bridge |
| `apps/odrerir/` | Config reads `$YMIR_HOME/secrets/platform.env` |

### 4.4 Harness Configs (`.pi/`, `.opencode/`, `.claude/`)

| File | Change |
|------|--------|
| `.pi/mcp.json.example` | Paths use `$YMIR_HOME` env var |
| `opencode.json.example` | Paths use `$YMIR_HOME` env var |
| `.claude.json` (if exists) | Paths use `$YMIR_HOME` env var |

---

## 5. Migration Strategy

### 5.1 New Migration: `0003-private-data-separation.sh`

```bash
#!/usr/bin/env bash
# 0003-private-data-separation — move all private data to YMIR_HOME
# Idempotent, safe to run repeatedly.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
YMIR_HOME="${YMIR_HOME:-$HOME/Documents/Ymir}"

# 1. Create target layout
mkdir -p "$YMIR_HOME"/{config,secrets,identity,workspaces/{work,personal},memory/{daily,well},smidja,state,data}

# 2. Migrate hodd/ (Hoard) → YMIR_HOME/
# Secrets (if plaintext exists, encrypt after copy)
[ -d "$ROOT/hodd/secrets" ] && cp -rn "$ROOT/hodd/secrets/"* "$YMIR_HOME/secrets/" 2>/dev/null || true
# Identity (workspaces.yaml, projects.yaml, companies/)
[ -d "$ROOT/hodd/identity" ] && cp -rn "$ROOT/hodd/identity/"* "$YMIR_HOME/identity/" 2>/dev/null || true
# Docs (masterplan, append-only-log, plans, ratatoskr, reports)
[ -d "$ROOT/hodd/docs" ] && cp -rn "$ROOT/hodd/docs/"* "$YMIR_HOME/memory/" 2>/dev/null || true

# 3. Migrate svartalfaheim/ (tenant data) → YMIR_HOME/workspaces/ + identity/companies/
# Work workspace
[ -d "$ROOT/svartalfaheim/work/workspace" ] && cp -rn "$ROOT/svartalfaheim/work/workspace/"* "$YMIR_HOME/workspaces/work/" 2>/dev/null || true
# Company entities
[ -d "$ROOT/svartalfaheim/wayof/companies" ] && cp -rn "$ROOT/svartalfaheim/wayof/companies/"* "$YMIR_HOME/identity/companies/" 2>/dev/null || true

# 4. Migrate workspace/ (operator's world-tree) → YMIR_HOME/workspaces/
for d in work personal memory companies; do
  [ -d "$ROOT/workspace/$d" ] && cp -rn "$ROOT/workspace/$d/"* "$YMIR_HOME/workspaces/$d/" 2>/dev/null || true
done

# 5. Migrate config/agents.yaml → YMIR_HOME/config/
[ -f "$ROOT/config/agents.yaml" ] && cp -n "$ROOT/config/agents.yaml" "$YMIR_HOME/config/agents.yaml" 2>/dev/null || true

# 6. Migrate state/ → YMIR_HOME/state/
[ -d "$ROOT/state" ] && cp -rn "$ROOT/state/"* "$YMIR_HOME/state/" 2>/dev/null || true

# 7. Migrate data/ → YMIR_HOME/data/
[ -d "$ROOT/data" ] && cp -rn "$ROOT/data/"* "$YMIR_HOME/data/" 2>/dev/null || true

# 8. Migrate .agents/memory/kaia.engram* → YMIR_HOME/memory/
[ -f "$ROOT/.agents/memory/kaia.engram" ] && cp -n "$ROOT/.agents/memory/kaia.engram" "$YMIR_HOME/memory/kaia.engram" 2>/dev/null || true
[ -f "$ROOT/.agents/memory/kaia.engram-wal" ] && cp -n "$ROOT/.agents/memory/kaia.engram-wal" "$YMIR_HOME/memory/kaia.engram-wal" 2>/dev/null || true
[ -f "$ROOT/.agents/memory/kaia.engram-shm" ] && cp -n "$ROOT/.agents/memory/kaia.engram-shm" "$YMIR_HOME/memory/kaia.engram-shm" 2>/dev/null || true

# 9. Migrate smidja/smidja_data/smidja.db* → YMIR_HOME/smidja/
[ -f "$ROOT/smidja/smidja_data/smidja.db" ] && cp -n "$ROOT/smidja/smidja_data/smidja.db" "$YMIR_HOME/smidja/smidja.db" 2>/dev/null || true

# 10. Create .gitignore for private repo
cat >"$YMIR_HOME/.gitignore" <<'GITIGNORE'
# Runtime — rebuilt per machine
smidja/
state/
*.wal
*.shm
*.pid
*.lock

# Local overlays
config/agents.*.yaml
GITIGNORE

# 11. Initialize git repo if not already
if [ ! -d "$YMIR_HOME/.git" ]; then
  git -C "$YMIR_HOME" init >/dev/null 2>&1 && echo "  initialized private git repo at $YMIR_HOME"
fi

# 12. Offer to add GitHub remote for multi-machine sync
if [ -d "$YMIR_HOME/.git" ] && [ -t 0 ]; then
  read -p "  Add private GitHub remote for multi-machine sync? (git@github.com:user/repo.git) [y/N]: " yn
  case "$yn" in [Yy]*)
    read -p "    GitHub repo URL: " gh_url
    [ -n "$gh_url" ] && git -C "$YMIR_HOME" remote add origin "$gh_url" && \
      git -C "$YMIR_HOME" add -A && \
      git -C "$YMIR_HOME" commit -m "chore: initial Ymir private data" >/dev/null 2>&1 && \
      git -C "$YMIR_HOME" push -u origin main && \
      echo "    pushed to $gh_url" || true
    ;;
  esac
fi

# 13. Write layout record
cat >"$YMIR_HOME/.ymir-layout.yaml" <<YAML
version: 1
migrated_from: "$ROOT"
migrated_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
layout:
  config: "$YMIR_HOME/config"
  secrets: "$YMIR_HOME/secrets"
  identity: "$YMIR_HOME/identity"
  workspaces: "$YMIR_HOME/workspaces"
  memory: "$YMIR_HOME/memory"
  smidja: "$YMIR_HOME/smidja"
  state: "$YMIR_HOME/state"
  data: "$YMIR_HOME/data"
git_repo: "$YMIR_HOME"
github_repo: "${gh_url:-}"
secrets_encrypted: false
YAML

echo "0003-private-data-separation: done — private data now at $YMIR_HOME"
```

### 5.2 Post-Migration Cleanup

After migration succeeds and is verified:
1. **Remove old private dirs from repo** (they're in `.gitignore` but still exist locally):
   ```bash
   rm -rf hodd/ svartalfaheim/ workspace/work workspace/personal workspace/memory workspace/companies
   rm -rf state/ data/ config/agents.yaml config/agents.*.yaml
   rm -rf .agents/memory/kaia.engram* smidja/smidja_data/smidja.db*
   ```
2. **Update `.gitignore`** — remove old patterns, add `$YMIR_HOME` patterns (for local dev only)
3. **Update `private-guard.sh`** — remove `hodd/`, `svartalfaheim/`, `workspace/` from FORBID
4. **Update `public-guard.sh`** — remove `svartalfaheim/` from APPEND_ONLY
5. **Commit the cleanup** as "chore: private data separation for open-source release"

---

## 6. Environment Variable Contract

### 6.1 New Standard Variables

| Variable | Purpose | Set By |
|----------|---------|--------|
| `YMIR_HOME` | Root of all private user data | Installer, sourced by all scripts |
| `YMIR_HOARD` | Alias for `$YMIR_HOME` (legacy compat) | `bin/hodd.sh` |
| `YMIR_AGENTS_YAML` | Path to agents config | `bin/agents-config.sh` |
| `YMIR_SECRETS_DIR` | Path to secrets | `bin/hodd.sh` |
| `YMIR_IDENTITY_DIR` | Path to identity registries | `bin/hodd.sh` |
| `YMIR_WORKSPACES_DIR` | Path to workspaces | `bin/realm-lib.sh` |
| `YMIR_MEMORY_DIR` | Path to memory/well | `bin/mimir-bridge.sh` |
| `YMIR_SMIDJA_DIR` | Path to smidja DB | `bin/smidja-bootstrap.sh` |
| `YMIR_STATE_DIR` | Path to runtime state | `bin/eir-doctor.sh`, cron |
| `YMIR_DATA_DIR` | Path to operational data | `bin/ymir-migrate.sh` |

### 6.2 Sourcing Convention

Every script that needs private paths:
```bash
# At top of script, after ROOT/SCRIPT_DIR:
YMIR_HOME="${YMIR_HOME:-$HOME/Documents/Ymir}"
[ -d "$YMIR_HOME" ] || { echo "error: YMIR_HOME not set or not a directory: $YMIR_HOME" >&2; exit 1; }
```

**The installer writes a shell snippet** to `$YMIR_HOME/env.sh` that users can `source`:
```bash
# $YMIR_HOME/env.sh — source this in your shell for Ymir CLI access
export YMIR_HOME="$HOME/Documents/Ymir"
export YMIR_HOARD="$YMIR_HOME"
export YMIR_AGENTS_YAML="$YMIR_HOME/config/agents.yaml"
export YMIR_SECRETS_DIR="$YMIR_HOME/secrets"
export YMIR_IDENTITY_DIR="$YMIR_HOME/identity"
export YMIR_WORKSPACES_DIR="$YMIR_HOME/workspaces"
export YMIR_MEMORY_DIR="$YMIR_HOME/memory"
export YMIR_SMIDJA_DIR="$YMIR_HOME/smidja"
export YMIR_STATE_DIR="$YMIR_HOME/state"
export YMIR_DATA_DIR="$YMIR_HOME/data"
```

---

## 7. Open-Source Release Checklist

### 7.1 Repo Hygiene (must be clean before `npm publish` / `gh release`)

- [ ] No `.env.local`, `.env.realm`, `*.env.local` in git history (use `git filter-repo` if needed)
- [ ] No hardcoded `/home/zerwiz`, `/home/<user>`, tenant names in tracked files
- [ ] No API keys, tokens, or secret-shaped strings in tracked files
- [ ] `hodd/`, `svartalfaheim/`, `workspace/work`, `workspace/personal`, `workspace/memory`, `workspace/companies` **not tracked** (only `*.example` scaffolds)
- [ ] `state/`, `data/`, `config/agents.yaml`, `.agents/memory/kaia.engram*`, `smidja/smidja_data/smidja.db*` **not tracked**
- [ ] `.agents/config/agents.yaml`, `.agents/config/agents.*.yaml` **not tracked**
- [ ] `opencode.json`, `.pi/mcp.json` **not tracked** (only `.example` versions)
- [ ] `CHANGELOG.md`, `docs/append-only-log.md`, `RULES/` — append-only, never rewritten

### 7.2 Documentation Updates

- [ ] `README.md` — add "Private Data Storage" section explaining `$YMIR_HOME`
- [ ] `docs/installations/` — new guide for per-platform Documents folder detection
- [ ] `CONTRIBUTING.md` — note that contributors' private data never enters the repo
- [ ] `docs/lore.md` — add YMIR_HOME to the lore table

### 7.3 Installer Verification

- [ ] Fresh clone → `bin/ymir-install.sh --check` → shows "would create ~/Documents/Ymir/"
- [ ] Fresh clone → `bin/ymir-install.sh` → interactive path choice, git repo prompts
- [ ] Existing machine → `bin/ymir-install.sh` → detects existing data, offers migration
- [ ] Migration → `bin/ymir-migrate.sh private-data` → moves data, updates layout
- [ ] Post-migration → `bin/ymir-validate.sh` → all checks pass with new paths

---

## 8. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Users lose data during migration | Migration is **copy-only** (cp -n), never mv; originals remain until verified |
| Scripts break due to path changes | All scripts use `YMIR_HOME` env var with fallback; comprehensive test suite |
| Users confused by new location | Installer is interactive with clear explanations; `bin/ymir-install.sh --status` shows current layout |
| Git repos for user data cause conflicts | Single private repo for all of `$YMIR_HOME`; user chooses GitHub remote |
| Secrets accidentally committed | Private GitHub repo = private data; only user has access. No local encryption needed. |
| Existing users' workflows break | Backwards compat: `YMIR_HOARD` still works; migration is one-way but reversible |

---

## 9. Implementation Order

| Phase | Tasks | Est. Effort |
|-------|-------|-------------|
| **1. Core Infrastructure** | Add `YMIR_HOME` detection to `bin/ymir-platform.sh`; update `bin/hodd.sh`, `bin/agents-config.sh`, `bin/realm-lib.sh` | 1 day |
| **2. Installer Rewrite** | New Phase 0 (path choice), Phase 2 (git repo + GitHub remote), Phase 3 (seed templates), Phase 4 (layout record) | 2 days |
| **3. Migration Script** | Create `.agents/migrations/0003-private-data-separation.sh` (no encryption, GitHub remote prompt) | 0.5 day |
| **4. Script Updates** | Update all scripts in §4 to use `$YMIR_HOME` | 2 days |
| **5. App Config Updates** | Update Hlidskjalf, Óðrerir, harness configs | 1 day |
| **6. Guard Updates** | Update `private-guard.sh`, `public-guard.sh`, `.gitignore` | 0.5 day |
| **7. Documentation** | Update README, CONTRIBUTING, installation guides | 1 day |
| **8. Testing & Validation** | Fresh install, migration, upgrade scenarios, GitHub sync | 2 days |
| **Total** | | **~10 days** |

---

## 10. Decisions from Allfather (2026-09-15)

1. ✅ **Default Documents path**: `~/Documents/Ymir/` — **APPROVED**
2. ✅ **Secrets encryption**: **NONE** — use private GitHub repo as the sync mechanism. Private repo = private data. GitHub's access control replaces local encryption.
3. ⏳ **Backwards compat period**: TBD — keep deprecated `hodd/`/`svartalfaheim` read paths with warnings for **one major release cycle** (until next minor version).
4. ✅ **npm/curl install flow**: **Prompt the user** — the installer asks how they want to set up their private data sync (GitHub repo URL, or local only).
5. ❌ **Age key management**: **Not needed** — no local encryption.

**Core requirement:** Users must be able to share their data between machines via **private GitHub repos**. The `$YMIR_HOME` git repo pushes to a user-owned private GitHub repo. Secrets (`platform.env`) live in that private repo — safe because only the user (and their machines) have access.

---

## Appendix: Current Private Data Inventory (Audit Results)

### Tracked in Repo (MUST BE REMOVED)
- `hodd/` — entire directory (private hoard → now at `$YMIR_HOME/`)
- `svartalfaheim/wayof/` — **REMOVED** (single tenant; company data lives in Way of Teams product)
- `workspace/work/`, `workspace/personal/`, `workspace/memory/`, `workspace/companies/`
- `config/agents.yaml` (gitignored but exists locally)
- `state/` (gitignored but exists locally)
- `data/` (gitignored but exists locally)
- `.agents/memory/kaia.engram*` (gitignored but exists locally)
- `smidja/smidja_data/smidja.db*` (gitignored but exists locally)
- `opencode.json`, `.pi/mcp.json` (gitignored, rendered from examples)

### Already Correctly Gitignored (stay as-is)
- `.env.local`, `.env.realm`
- `certs/*.pem`, `certs/*.key`
- `.yggdrasil/`, `.treehouses/`
- `apps/hlidskjalf/node_modules/`, `apps/hlidskjalf/dist/`
- `apps/odrerir/node_modules/`, `apps/odrerir/dist/`

### Public Artifacts (REMAIN IN REPO)
- All `bin/` scripts
- All `.agents/skills/`, `.agents/assets/`
- All `apps/` source code (not build artifacts)
- `docs/` (public documentation)
- `midgard/` (shared company assets)
- `RULES/`, `README.md`, `CHANGELOG.md`, `LICENSE`, `STRUCTURE.md`, `CONTRIBUTING.md`, `SECURITY.md`, `NOTICE`
- All `*.example`, `*.sample` files

---

*This plan is a living document. Append amendments below; never rewrite.*

---

## Amendment 1 — 2026-09-15: Single Private Git Repo for All User Data

**Decision by Allfather:** Everything in `$YMIR_HOME` goes to the user's private git repo (one repo, not per-section).

**Changes from original plan:**
- §2.3: Replaced "per-section git repos" with single `$YMIR_HOME` git repo
- §3.1 Phase 2: Single prompt "Initialize private git repo for all Ymir data? [Y/n]"
- §3.1 Phase 3: Added GitHub remote setup for multi-machine sync, `.gitignore` creation, git init
- §5.1: Migration script now creates `.gitignore`, initializes git repo, prompts for GitHub remote
- §8: Updated risk table for single repo model with GitHub sync
- §10: Decisions recorded — no local encryption, GitHub private repo is the sync mechanism

**Secrets handling:** `platform.env` committed **as-is** to the private GitHub repo. No local encryption — GitHub's access control protects it. Only the user (and their authorized machines) can clone the private repo.

**Gitignore within private repo:** `smidja/`, `state/`, `*.wal`, `*.shm`, `config/agents.*.yaml` — machine-specific, never synced.

---

## Amendment 2 — 2026-09-15: No Local Encryption, GitHub Private Repo Sync

**Decisions by Allfather:**
1. ✅ Default path: `~/Documents/Ymir/`
2. ✅ No encryption — private GitHub repo = private data
3. ⏳ Deprecation: one major release cycle
4. ✅ Installer prompts for GitHub repo setup
5. ❌ Age keys not needed

**Core requirement implemented:** Users share data between machines via **private GitHub repos**. The `$YMIR_HOME` git repo pushes to a user-owned private GitHub repo. Secrets (`platform.env`) live in that private repo — safe because only the user has access.

---

## Amendment 3 — 2026-09-15: Implementation Complete

**What was actually done in the repo:**

1. **Private data untracked from git** — `smidja/smidja_data/` (52 files), `workspace/config/portfolio.md`, `workspace/config/toolchain.md`, `workspace/marketing/` (2 files), `workspace/INSTALL.md` all removed from git index via `git rm --cached`
2. **`.gitignore` hardened** — `smidja/smidja_data/` now covers ALL of smidja_data (was only sessions/ + smidja.db*). Added `workspace/config/`, `workspace/marketing/`, `workspace/INSTALL.md`
3. **Scripts updated to `$YMIR_HOME`** — `bin/hodd.sh`, `bin/agents-config.sh`, `bin/ymir-install.sh`, `bin/realm-lib.sh`, `bin/ymir-migrate.sh`, `bin/eir-doctor.sh`, `bin/groa-update.sh`, `bin/mimir-bridge.sh`, `bin/mimir.sh`, `bin/a2a-mcp.sh` all prefer `$YMIR_HOME` (default `~/Documents/Ymir`)
4. **Guards updated** — `private-guard.sh` expanded FORBID to include workspace/config/, workspace/marketing/, workspace/INSTALL.md. `public-guard.sh` removed `svartalfaheim/` from APPEND_ONLY. `docs-guard.sh` added PATTERN_ALLOW exception for `0003-private-data-separation.md`
5. **Plan document** — this file at `docs/plans/0003-private-data-separation.md`

**Not yet done (next session):**
- Create migration `0003-private-data-separation.sh` in `.agents/migrations/`
- Update remaining scripts: `nornir-job-observer.sh`, `smidja-bootstrap.sh`, `ymir-validate.sh`
- Update hodd/legacy paths in `bin/hodd.sh` for full backwards compat
- Document the `$YMIR_HOME` env var contract in docs/installations/

---

## Amendment 4 — 2026-09-15: All Amendment 3 Items Complete

**All four "Not yet done" items from Amendment 3 are now complete:**

1. ✅ **Migration script** — `.agents/migrations/0003-private-data-separation.sh` created. Copy-only, idempotent, creates `.gitignore`, initializes git repo, prompts for GitHub remote, writes `.ymir-layout.yaml`.
2. ✅ **Remaining scripts updated** — `bin/nornir-job-observer.sh` (SMIDJA_DB, RUNES_LEDGER prefer YMIR_HOME), `bin/smidja-bootstrap.sh` (DB prefers YMIR_HOME), `bin/ymir-validate.sh` (smidja-db and runes checks prefer YMIR_HOME) all updated.
3. ✅ **Hodd backwards compat** — `bin/hodd.sh` already had `HOARD="${YMIR_HOARD:-${YMIR_HOME:-$ROOT/hodd}}"` — falls back to repo hodd/ when YMIR_HOME unset.
4. ✅ **YMIR_HOME documentation** — `docs/installations/ymir-home.md` created with full env var contract, layout, and sourcing convention. `docs/installations/README.md` updated to reference `$YMIR_HOME/secrets/platform.env`.

**Additional changes this session:**
- `AGENTS.md` updated for YMIR_HOME architecture (directory rules, private data section, append-only, security, GitHub & isolates, agent set, private contract path).

**Total commits on `sync/sessrumnir-pi-desktop-v0.1.8`:**
- `2eb4def` — chore: separate private data from open-source repo
- `fbadf91` — docs: Amendment 3 to plan 0003
- `cd99b5e` — docs: update AGENTS.md for YMIR_HOME architecture
- `43641dc` — chore: finish private data separation — scripts, migration, docs

---

## Amendment 5 — Post-release session: data moved out of repo, YMIR_HOME populated

**What was done this session:**

1. **`data/` → `$YMIR_HOME/data/`** — All 7 operational data files
   (backlog.md, eindri-homes.md, fleet.md, learnings.md, operator.md,
   projects.md, realm.md) moved from repo root to `$YMIR_HOME/data/`.
   `data/*` was already in `.gitignore`; the directory is now removed
   from the repo entirely.

2. **`memory/` → `$YMIR_HOME/memory/`** — All engram runtime files
   (kaia.engram, kaia.engram-shm, kaia.engram-wal) moved from repo
   root to `$YMIR_HOME/memory/`. `memory/` directory removed from repo.

3. **`hodd/` private data → `$YMIR_HOME/`** — All private hodd/
   contents copied to their YMIR_HOME destinations:
   - `hodd/docs/` → `$YMIR_HOME/docs/`
   - `hodd/identity/` → `$YMIR_HOME/identity/`
   - `hodd/secrets/` → `$YMIR_HOME/secrets/`
   - `hodd/tenants/` → `$YMIR_HOME/tenants/`
   - `hodd/AGENTS.md` → `$YMIR_HOME/AGENTS.md`
   - hodd/.gitignore, hodd/README.md, hodd/AGENTS.example.md remain
     at repo as scaffolds and guards.

4. **`$YMIR_HOME` is now fully populated** — The private git repo
   at `$YMIR_HOME` has real data: docs/, identity/, secrets/,
   tenants/, data/, memory/, config/, workspaces/.

5. **Private data is NOT gitignored** — The user's YMIR_HOME git
   repo commits all private data (except smidja/, state/, *.wal,
   *.shm). This enables sharing between machines via the private
   GitHub repo.

6. **RULES/ updated:**
   - `RULES/04-hoard.md` — rewritten to reflect two-tier hoard:
     scaffolds at repo (`hodd/`), real data at YMIR_HOME (committed,
     shareable). Added YMIR_HOME mapping table and clarified that
     user data is NOT gitignored.
   - `RULES/06-append-only.md` — updated paths:
     `workspace/memory/runes_audit.md` → `$YMIR_HOME/memory/runes_audit.md`;
     `docs/append-only-log.md` → `$YMIR_HOME/docs/append-only-log.md`;
     `hodd/**` → `$YMIR_HOME/**`; updated move-check script to use
     YMIR_HOME paths.

7. **CONTRIBUTING.md** — added Members section listing zerwiz (Allfather)
   and craig (member contributor), with reminder about realm boundaries.

8. **README.md** — added GitHub section (repo link, PR flow, CI guards,
   secret handling) and npm section (global install, npx one-shot, private
   data note).

**Not yet done (next session):**
- Verify `$YMIR_HOME/tenants/` and `$YMIR_HOME/secrets/` have real data
  (currently some dirs may be empty: secrets/, tenants/)
- Remove hodd/ private data from repo working tree (currently still on disk
  but untracked): `rm -rf hodd/docs hodd/identity hodd/secrets hodd/tenants hodd/AGENTS.md`
- Update `bin/hodd.sh` and other scripts that reference `hodd/` paths
  to prefer `$YMIR_HOME` equivalents
- Add `$YMIR_HOME/tenants/` to AGENTS.md YMIR_HOME tree
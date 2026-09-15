# YMIR_HOME — the private data root

All private user data lives at **`$YMIR_HOME`** (default `~/Documents/Ymir`).
The open-source repo contains **only** public artifacts (source code, docs,
examples). No secrets, no identity, no state.

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `YMIR_HOME` | Root of all private user data | `~/Documents/Ymir` |
| `YMIR_HOARD` | Alias for `$YMIR_HOME` (legacy compat) | `$YMIR_HOME` |
| `YMIR_AGENTS_YAML` | Path to agent/harness config | `$YMIR_HOME/config/agents.yaml` |
| `YMIR_SECRETS_DIR` | Path to secrets | `$YMIR_HOME/secrets` |
| `YMIR_IDENTITY_DIR` | Path to identity registries | `$YMIR_HOME/identity` |
| `YMIR_WORKSPACES_DIR` | Path to workspaces | `$YMIR_HOME/workspaces` |
| `YMIR_MEMORY_DIR` | Path to memory/well | `$YMIR_HOME/memory` |
| `YMIR_SMIDJA_DIR` | Path to smidja DB | `$YMIR_HOME/smidja` |
| `YMIR_STATE_DIR` | Path to runtime state | `$YMIR_HOME/state` |
| `YMIR_DATA_DIR` | Path to operational data | `$YMIR_HOME/data` |

## Sourcing Convention

Every script that needs private paths declares YMIR_HOME at the top:

```bash
YMIR_HOME="${YMIR_HOME:-$HOME/Documents/Ymir}"
[ -d "$YMIR_HOME" ] || { echo "error: YMIR_HOME not set or not a directory" >&2; exit 1; }
```

Private paths then resolve as `${YMIR_HOME}/<subdir>` — no hardcoded paths.

## Per-Machine Env Profile

The installer writes `$YMIR_HOME/env.sh` which users source in their shell:

```bash
# $YMIR_HOME/env.sh — source this for Ymir CLI access
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

## Layout

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
│   ├── work/                # company, marketing, development, life
│   └── personal/            # me, life, development
├── memory/
│   ├── daily/               # Daily briefings
│   └── well/                # Mimirsbrunn append log
├── smidja/
│   └── smidja.db*           # Smidja session database
├── state/                   # Runtime state (locks, pids, cron)
├── data/                    # Operational data (backlog, fleet, learnings)
├── .gitignore               # Ignores smidja/, state/, *.wal, *.shm
└── .ymir-layout.yaml        # Layout record (migration origin, github_repo)
```

## Single Private Git Repo

The entire `$YMIR_HOME` is one git repo pushed to a **private GitHub repo**
for multi-machine sync. Secrets (`platform.env`) live in that private repo —
safe because only the user (and their authorized machines) can clone it.
No local encryption needed.

Smidja DB, runtime state, and local overlays are gitignored within the
private repo (rebuilt per machine).

## Backwards Compatibility

Scripts fall back to `$ROOT/hodd` (legacy Hoard in repo) when
`YMIR_HOARD` and `YMIR_HOME` are both unset. The migration script
(`bin/ymir-migrate.sh private-data`) copies data to `$YMIR_HOME` and
writes `.ymir-layout.yaml`.

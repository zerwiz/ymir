# Integrating Ymir into an existing harness workflow

> **Purpose:** add Ymir (Brokk, the memory well, the A2A mesh, the Hlidskjalf
> control plane) to a machine that already runs agent harnesses and other MCP
> servers — **without touching the global configuration** of those harnesses.
> Project-scoped, additive, one-command rollback. Obeys Rule 05 (portability) and
> Rule 07 (no hardcoded config).

## The stance

Ymir's harness wiring lives **inside the checkout**: `.opencode/plugins/*.js` (the
Brokk adapters) and the project `opencode.json` / `.pi/mcp.json`. A harness that
merges project config with global config therefore gains Ymir **only when opened
in the Ymir directory**; every other project is untouched.

## Three planes

| Plane | What | Where |
|---|---|---|
| Substrate | the runtime, services, cron | the box (bare, or a Quadlet/compose container) |
| MCP surfaces | the memory well (`engram`) + the mesh (`a2abridge`) | project config |
| Control plane | Hlidskjalf | the substrate's published port |

## Wire it (project-scoped)

```bash
cd <ymir-checkout>
bin/prereq-ensure.sh engram        # the well engine (if absent)
bin/a2abridge-ensure.sh ensure --install   # the A2A mesh engine + directory daemon
bin/a2a-mcp.sh install --project   # writes THIS repo's config only: engram + a2abridge
bin/a2a-mcp.sh show --project      # verify
bin/valknut-load.sh --opencode     # bind Ymir's agents/skills into OpenCode
```

`bin/a2a-mcp.sh install` (no `--project`) also writes Pi's **global**
`~/.pi/agent/mcp.json`. When Pi is used in other areas, prefer `--project`: it
writes the repo's `.pi/mcp.json` instead, and Pi picks it up only when launched
with `pi --mcp-config .pi/mcp.json`.

### Order matters

`bin/valknut-load.sh --opencode` renders the project `opencode.json` from its
`.example`; run it **before** `bin/a2a-mcp.sh install --project` so the MCP block
is not overwritten. `bin/agents-config.sh apply` merges in local providers and
should also run before the MCP install.

## Models

`config/agents.yaml` (private, gitignored) is the roster: local providers, the
default model, and per-agent `model:`/`harness:`. `bin/models-detect.sh` reports
what is running; `bin/agents-config.sh apply` writes the local providers into the
project `opencode.json` and the chosen `model:` into `.agents/agents/*.md`. Rule:
local models via `pi`, hosted via `opencode` — an agent may override `harness:`.

## Seating Brokk

The adapters are **path-loaded**: open the harness with the checkout as the working
directory. OpenCode's `.opencode/plugins/` then seat Brokk (Sága's digest arrives
before the first turn), arm Sýn, guard the turn end, and enforce the PreToolUse
seatbelts. There is **no Brokk adapter for Zed** — Zed gets the memory plane only
(add the well as a context server, mirroring any other MCP entry).

## Working across repositories

Ymir binds to **one home**, and the machine has **one Brokk primary**:

- The primary's helm is a **machine-global** lock
  (`${XDG_STATE_HOME:-$HOME/.local/state}/ymir/brokk.lock`). A second Brokk session
  anywhere is read-only; an *Eindri-home* (a worker home) keeps its own per-home
  lock and runs beside the primary.
- A pane in another repository does **not** auto-seat Brokk — the adapter lives in
  the Ymir checkout. Panes elsewhere are for observation and terminal work.
- To have Ymir **work** another project, dispatch it:
  `bin/einherjar-spawn.sh <task-id> <project-dir>` creates an Yggdrasil worktree of
  that project and seats the worker pane there. Herdr panes carry their own cwd
  (`bin/herdr-run.sh seat_tab <name> <cwd>`), so the pane layout is unchanged.

Hlidskjalf is the Ymir home's control plane; other projects surface there through
the project registry and their worktrees.

## Verification

```bash
systemctl --user status ymir.service        # substrate (Quadlet) — if containerised
bin/a2abridge-ensure.sh status              # engine / directory / service
bin/a2a-mcp.sh show --project               # MCP wiring in this repo
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:4602/health   # the well
```

## Rollback (nothing global was changed)

```bash
rm -f .pi/mcp.json opencode.json            # project wiring (private/generated)
git checkout -- .agents/agents/             # roster model lines, if applied
systemctl --user stop ymir.service          # the substrate
```

## Cautions

- **Do not run `scripts/start.sh` on the host while a container runs the
  substrate** — the ports collide.
- The **seatbelts** (`bin/syn-pretool-check.sh`, `syn-cd-check.sh`) refuse some
  dangerous shell operations *inside the checkout*; that is the feature.
- One**helm per home**: a second session in the same checkout should use an
  Yggdrasil worktree.

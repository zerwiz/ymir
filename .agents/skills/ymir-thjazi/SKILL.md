---
name: ymir-thjazi
description: >-
  Þjazi — the terminal backend that hosts Ymir's agent panes. Use when spawning,
  supervising, or debugging Eindri workers and presentation spaces, when choosing
  or verifying the herdr/tmux backend, when herdr is missing or too old to install
  or upgrade it, or when presentation spaces (herdr 0.8.0+) are involved. Load
  before changing backend selection, pane layout, or spawn behaviour.
allowed-tools: read,write,bash,glob,grep
---

# Þjazi — the terminal backend

Þjazi is the giant who carries the gods' errands across the mountains; the backend
that carries Ymir's agents across terminal panes. In the code it is **herdr** (and
its verified reference sibling **tmux**). This skill is how Ymir is a
herdr-first system without breaking on a tmux-only host.

**Router:** `.agents/skills/galdr/SKILL.md`.

## Ymir is herdr-first

At install, Ymir guarantees a terminal backend exists. The order is:

```
backend_priority[3]{rank,backend,note}:
  "1","herdr","Þjazi — preferred; carries protocol + presentation spaces"
  "2","tmux","the verified reference backend; always acceptable"
  "3","none","spawn is refused with a plain reason — never a silent fallback"
```

Selection is by config/env, in this order:

```bash
config/backend          # repo-level choice, if present
BROKK_BACKEND           # env override
HERDR_ENV=1             # set inside a herdr pane
# else: tmux when available
```

## Verify before you trust

```bash
command -v herdr && herdr --version          # e.g. herdr 0.8.2
echo "$BROKK_BACKEND"                         # explicit choice, if any
```

**Protocol floors** — check the version, not just the presence:

| Capability | Minimum |
|---|---|
| Agent panes (spawn/supervise) | Þjazi protocol **14+** |
| Presentation spaces | herdr **0.8.0+** |

A present-but-too-old herdr is a **failure**, not a fallback: refuse the capability
with a plain reason rather than degrading silently.

## Installing and upgrading

`bin/herdr-ensure.sh` (when present) is the single owner of provisioning; it
detects, installs when absent, and verifies the reported version. The pinned,
SHA-verified installer for the CI lane is `.agents/backend/fm-install-herdr.sh`
— it installs an **exact** version from official release assets, verifies SHA-256,
and refuses to finish unless the binary reports the pinned version and the
required protocol. Never install a floating "latest" for the pinned lane.

```bash
# CI/pinned lane (exact version + protocol check) — signature: <destination-dir>
.agents/backend/fm-install-herdr.sh "$HOME/.local/bin"

# User-space, if the helper is present
bin/herdr-ensure.sh status
bin/herdr-ensure.sh ensure --install
```

Opting out of presentation spaces (they are presentation-only, never correctness)
is done with `config/herdr-presentation-spaces` — see AGENTS.md.

## What the backend actually does

- **Spawn** carries an Eindri into an isolated pane, on top of an isolated
  Yggdrasil worktree, optionally inside Utgard. It prints one line:
  `spawned <id> harness=<h> kind=<ship|scout> [mode=<m> yolo=<y>] backend=<b> target=<t> worktree=<wt> isolation=<on|off>`
- **Supervision** keeps one pane per worker and observes it; the Pi/OpenCode
  extensions own continuity — never background the watcher arm by hand.
- **Presentation spaces** (herdr 0.8.0+) give a worker a shareable view; they are
  presentation, not a control channel.

## Debugging

```bash
scripts/electron.sh status        # if the app surface is the question
bin/backend/* or bin/einherjar-spawn.sh --help    # spawn contract
# one pane, one worker: a second spawn for the same id must be refused
```

If workers vanish, compare the spawn line's `backend=` against the intended
backend selection above — a tmux fallback on a herdr-first host is a
misconfiguration, not a mystery.

## Maintaining this

- **Owner:** Brokk. **Router:** `.agents/skills/galdr/SKILL.md`.
- Source of truth for the backend spec: `assets/brokk-distro-runtime.md` (backends)
  and `assets/pi-boot-guide.md` (pane supervision). Keep this skill's floors in
  sync with those when the protocol advances.

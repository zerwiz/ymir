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

## Raising an Eindri (the two roads)

An **Eindri** is a delegated hand (AGENTS.md; `docs/lore.md` §II — Brokk works the
bellows, Eitri/Eindri works the craft). Two roads seat one, and each fits its own
country. `bin/herdr-run.sh` is the runner; `bin/eindri-role.sh` names the smith.

```
herdr_roads[2]{road,shape,use_when}:
  "tab","one tab in this home's workspace (durable, the default)","the work outlasts the moment — a task with an artifact"
  "space","a disposable workspace holding exactly this one errand, gone when it ends","the errand should leave no trace in the workspace you are living in"
```

**A tab is a tab, not a pane split.** Firstmate's grain — and now ours — is that a
worker takes its **own tab in the home's workspace**, never a slice of yours. Your
pane keeps its width; the smith sits beside your tabs, reachable with a tab switch.

```
bin/herdr-run.sh available                      # reach herdr? which session/workspace?
bin/herdr-run.sh worth-a-smith "<errand>"       # THE FIRST LAW (see below)
bin/herdr-run.sh eindri -- "<task>"             # the RIGHT smith, seated in a TAB
bin/herdr-run.sh eindri --space -- "<task>"     # ...or in a disposable WORKSPACE
bin/herdr-run.sh eindri sindri -- "<task>"      # name the smith explicitly
bin/herdr-run.sh eindri --role huginn -- "<task>"
bin/herdr-run.sh run <name> -- <command...>     # a command in a tab (not an agent)
bin/herdr-run.sh agent-status                   # who stands, and in what state
bin/herdr-run.sh status                         # what seats we recorded
bin/herdr-run.sh close-all                      # clear the tabs/workspaces we made
```

### The first law — a short errand is done in hand

A smith costs a context, a seat, and the Allfather's attention. So an errand is
weighed before it is seated:

- **A question is answered in hand.** "What is the pid?" "Why did it fail?" —
  answered directly, never seated.
- **A one-line check is done in hand.** Brevity is not a task.
- **A task earns a smith** — work with an artifact: build, fix, implement, port,
  research, audit, plan, document, review.

`worth-a-smith` decides, and `eindri` refuses to seat a smith for a question or a
trifle. Ask it first when you are unsure.

### The projection floor

A disposable workspace needs **herdr 0.8.0+** (protocol 19). Below that floor a
workspace-emptying close can steal the active workspace, so `--space` falls back
to a tab and says so, rather than risking your focus. `available` reports
`space_ok` for the running release.

### The law of the runner

Inside herdr the work is shown in its own tab or workspace; outside herdr it runs
**inline — the same result, no seats** — and if a seat cannot be raised the
command runs in place, so no work is ever lost to the theatre.
`YMIR_HERDR_PANES=0` forces inline anywhere.

### Session routing (a trap worth naming)

`HERDR_SESSION` alone is **not** a reliable router: with another herdr server
bound on the machine, a command silently reaches the wrong one. The runner always
passes the trailing `--session <name>` flag, which routes correctly. (Firstmate's
`docs/herdr-backend.md` owns the evidence.)

## The right smith for the right task

An Eindri is a delegated hand (AGENTS.md; `docs/lore.md` §II: Brokk works the
bellows, Eitri/Eindri works the craft). The wrong smith for the metal produces
bad work, so the role is chosen deliberately:

```
eindri_roles[8]{role,craft}:
  "sindri","code — build, refactor, fix, test"
  "bragi","content — marketing, SEO, social"
  "huginn","research — search, analyse, discover"
  "kvasir","scout — recon a codebase before work"
  "mimir","plan — design the approach"
  "snotra","document — prose, guides, references"
  "forseti","review — judge the work"
  "galdr","runtime — the Ymir distro itself"
```

```
bin/eindri-role.sh list                 # the roster
bin/eindri-role.sh choose "<task text>" # the craft that fits
bin/eindri-role.sh for <role>           # exact lookup
```

A named role wins; otherwise the craft is read from the errand itself ("write a
blog post" → `bragi`; "fix the login bug" → `sindri`). Several may stand at once.

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

## The seat hierarchy (panes · tabs · spaces)

herdr is `Session > Workspace > Tab > Pane`. An Eindri can be seated at each rung,
chosen by `bin/eindri-start.sh` / `bin/herdr-run.sh eindri`:

| flag | rung | road | when |
|------|------|------|------|
| *(default)* | **pane** | `herdr pane split <pane> --direction right` | the companion — an Eindri beside the work; splits the current pane inside herdr, else this home's active pane |
| `--tab` | **tab** | `herdr tab create` | a separate view in this workspace |
| `--space` | **workspace** | `herdr workspace create` | a disposable space for one errand (needs the 0.8.0 floor) |

All three roads then `herdr agent start <name> --kind <kind> --pane <pane>` and
`herdr agent prompt`. Use panes by default so agents are visible side by side,
tabs to group parallel work, spaces to isolate an errand. `herdr-run.sh close-all`
tears the recorded seats down.

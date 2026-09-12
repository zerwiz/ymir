# Eindri Orchestration — worker spawn, brief, state, isolation, and supervision

Purpose: the complete, production-grade reference for how Brokk gathers an **Eindri** worker
(Einherjar → Erindi → Vör → Yggdrasil → Utgard → Valhalla) from dispatch to delivery.

> **One worker, one brief, one worktree.** Every Eindri is gathered by
> `bin/einherjar-spawn.sh`, reads exactly one brief at `data/<task-id>/brief.md`, and runs in
> exactly one Yggdrasil worktree at `.yggdrasil/<task-id>`. The brief and the recorded task
> cannot drift: both carry the same `Delivery contract: mode=<mode>` line.
>
> Provenance: the upstream agent-distro spawn/brief/state pattern
> (`/home/zerwiz/Brokk/bin/fm-spawn.sh`, `fm-brief.sh`, `fm-crew-state.sh`) is the source
> of the pattern; Ymir's runtime is `bin/einherjar-spawn.sh`, `bin/erindi-brief.sh`, and
> `bin/vor-crew-state.sh`, retargeted for plan 29. Upstream nautical labels are provenance
> only — the Ymir names are Norse.

---

## 1. The orchestration chain

| Stage | Norse name | Owner artifact | Lives at |
|---|---|---|---|
| Dispatch decision | **Brokk** | `config/eindri-dispatch.json` | repo config |
| Harness detection | **Hamr** | `bin/hamr-harness.sh` | repo bin |
| Worker gather | **Einherjar** | `bin/einherjar-spawn.sh` | repo bin |
| Worker brief | **Erindi** | `bin/erindi-brief.sh` → `data/<id>/brief.md` | private `data/` |
| Worktree isolation | **Yggdrasil** | `.yggdrasil/<id>` (git worktree) | private `.yggdrasil/` |
| Sandbox seal | **Utgard** | `.agents/sandbox/Dockerfile.utgard` | repo `.agents/` |
| State reconciliation | **Vör** | `bin/vor-crew-state.sh` | repo bin |
| Status event log | (Eindri writes) | `state/<id>.status` | private `state/` |
| Steering inbox | (Brokk writes) | `state/<id>.inbox/*.msg` | private `state/` |
| Record | (spawn writes) | `state/<id>.meta` | private `state/` |
| Supervision | **Valhalla** | tmux/herdr pane or supervision tree | backend |
| Human merge gate | **Glitnir** | PR review card in Hlidskjalf | portal |

`DATA`, `STATE`, and `CONFIG` default to `$BROKK_HOME/data`, `$BROKK_HOME/state`, and
`$BROKK_HOME/config`. They are gitignored (`.gitignore:59-63`) and are the only writable
surface outside the worktree.

---

## 2. Spawn interface — `bin/einherjar-spawn.sh`

### 2.1 Usage forms

```
einherjar-spawn.sh <task-id> <project-dir> --mode <direct-PR|local-only|no-mistakes>
    [--yolo on|off] [--harness <name>] [--model <name>]
    [--effort <low|medium|high|xhigh|max>] [--backend tmux|herdr]
    [--isolation on|off|auto]

einherjar-spawn.sh <task-id> <project-dir> --scout
    [--harness <name>] [--model <name>] [--effort <...>]
    [--backend <...>] [--isolation <...>]

einherjar-spawn.sh <task-id> --relaunch
    [--harness <name>] [--model <name>] [--effort <...>] [--isolation <...>]
```

Every spawn prints exactly one record line to stdout:

```
spawned <id> harness=<h> kind=<kind> mode=<m> yolo=<y> backend=<b> target=<t> worktree=<wt> isolation=<on|off>
```

(`--scout` omits `mode=`/`yolo=`; the output shape is defined at
`bin/einherjar-spawn.sh:550-554`.)

### 2.2 Flag reference

| Flag | Values | Default | Meaning / failure mode |
|---|---|---|---|
| `<task-id>` (positional 1) | `[A-Za-z0-9._-]+` | required | No `/`, no leading `.`, no spaces; else exit 2. |
| `<project-dir>` (positional 2) | path | required for fresh spawn | Must be a git working tree; else error. Resolved absolute. |
| `--mode` | `direct-PR`, `local-only`, `no-mistakes` | — | **Required for ship spawns.** Refused with `--scout` and `--relaunch`. |
| `--scout` | flag | off | Deliverable is `data/<id>/report.md`; no branch, no push, no PR. |
| `--relaunch` | flag | off | Reuse recorded worktree/kind/mode from `state/<id>.meta`; only harness/model/effort/isolation may change. |
| `--yolo` | `on`, `off` | `off` | Merge posture recorded in the meta for a ship task; not a brief input. |
| `--harness` | name **or** raw command | detected | Verified: `opencode pi pi-signed`. A value containing whitespace is a raw launch escape hatch. |
| `--model` | token | harness default | Passed through as `--model` (opencode/pi). |
| `--effort` | `low`, `medium`, `high`, `xhigh`, `max` | harness default | Passed to `pi` as `--thinking`; opencode ignores it. |
| `--backend` | `tmux`, `herdr` | resolved | tmux window `eindri-<id>` or herdr workspace `eindri-<id>`. |
| `--isolation` | `on`, `off`, `auto` | `auto` | `auto` seals only when the Utgard image is present, and reports the decision. |

### 2.3 Environment overrides

| Variable | Effect |
|---|---|
| `BROKK_ROOT_OVERRIDE` | Root used when `BROKK_HOME` is unset. |
| `BROKK_HOME` | Home owning `data/ state/ config/`; defaults to repo root. |
| `BROKK_STATE_OVERRIDE` | Override `state/` (metas, status, launch scripts). |
| `BROKK_DATA_OVERRIDE` | Override `data/` (briefs, reports). |
| `BROKK_CONFIG_OVERRIDE` | Override `config/` (dispatch, harness, backend). |
| `BROKK_BACKEND` | Force `tmux` or `herdr` when `--backend` is absent. |
| `BROKK_TMUX_SESSION` | tmux session name when not already inside tmux (default `brokk`). |
| `TMUX` / `HERDR_ENV` | Runtime detection of the active multiplexer. |
| `BROKK_PI_HARNESS` | `pi-signed` selects the signed pi adapter in Hamr. |

### 2.4 Harness resolution and the fail-closed law

`bin/einherjar-spawn.sh:166-237` resolves the harness in this order:

1. **Explicit `--harness <name>`** → verified against `VERIFIED_HARNESSES='opencode pi pi-signed'`.
2. **Explicit `--harness '<raw command>'`** (contains whitespace) → the raw-launch escape hatch;
   prints a warning and names the derived harness. Use only to trial a new adapter.
3. **`config/eindri-dispatch.json` present** → a fresh spawn with no explicit `--harness`
   is **refused** (consultation backstop: the dispatch profiles must be read, never skipped).
4. **`bin/hamr-harness.sh crew`** when executable, else an inline detector
   (`config/eindri-harness` → env markers → process ancestry → `opencode`).

Fail-closed rules:

- An unverified harness is refused with a plain reason, never silently downgraded.
- A verified harness whose executable is not on `PATH` is refused.
- `--relaunch` re-verifies the recorded harness (or recorded raw command) the same way.

---

## 3. Erindi — the worker brief

`bin/erindi-brief.sh` scaffolds `data/<id>/brief.md`. It **refuses to overwrite** an existing
brief unless `--relaunch` is given.

### 3.1 Usage

```
erindi-brief.sh <task-id> <repo-name> --mode <no-mistakes|direct-PR|local-only>
erindi-brief.sh <task-id> <repo-name> --scout
erindi-brief.sh <task-id> --relaunch
```

`--relaunch` regenerates from `state/<id>.meta` so a replacement Eindri receives the **same**
delivery contract; it re-derives the mode and refuses `--mode`. `--yolo` is rejected here — it
belongs to spawn (`bin/erindi-brief.sh:70`).

### 3.2 Brief structure (ship)

| Section | Content |
|---|---|
| Role line | "You are an Eindri: an autonomous worker agent managed by Brokk. Work on your own; do not wait for the Allfather." |
| `# Task` | `{TASK}` placeholder Brokk replaces at dispatch. |
| `# Delivery contract` | The fixed machine-readable line `Delivery contract: mode=<mode>`. |
| `# Setup` | Disposable worktree of `<repo>` at `.yggdrasil/<id>` (or `/sandbox/workspace` under Utgard), detached HEAD. Isolation assertion first: `pwd -P` + `git rev-parse --show-toplevel` must resolve to the worktree. |
| Branch step | `git checkout -b eindri/<id>` (plus `no-mistakes doctor`/`init` for `no-mistakes`). |
| `# Rules` | Never push default branch / never merge; stay inside the worktree; status protocol; block after two failures; escalate product decisions. |
| Brokk instruction inbox | Read `state/<id>.inbox/*.msg` in numeric order; acknowledge by moving to `handled/`. |
| `# Definition of done` | Mode-specific terminal action and status line. |

### 3.3 The `Delivery contract:` line

- Written only for ship briefs, as `Delivery contract: mode=<mode>`
  (`bin/erindi-brief.sh:245`).
- Read by `bin/einherjar-spawn.sh:327-335`: if present and it disagrees with the explicit
  `--mode`, the launch is **refused**. A missing line warns but launches on `--mode`.
- Scout briefs carry `Delivery contract: mode=scout` (`bin/erindi-brief.sh:183`) and are not
  mode-checked at launch.

### 3.4 Delivery modes

| Mode | Branch/push | Pipeline | Terminal status | Merge owner |
|---|---|---|---|---|
| `no-mistakes` | push `eindri/<id>`, open the pipeline PR | `no-mistakes` | `done: <PR url> (pipeline <status>)` | Glitnir human gate |
| `direct-PR` | push `eindri/<id>`, open PR via `gh` | none | `done: opened PR <url>` | Glitnir human gate |
| `local-only` | `eindri/<id>` only, no push/PR | none | `done: ready in branch eindri/<id>` | Brokk merges local `main` after Allfather approval |
| `scout` | none | none | `done: {conclusion}` with report at `data/<id>/report.md` | n/a (report only) |

### 3.5 Status protocol (the event log)

The brief instructs the worker to append one line to `state/<id>.status`:

```
echo "{state}: {one short line}" >> 'state/<id>.status'
```

| State | Meaning |
|---|---|
| `working` | Non-terminal phase change; do not end the turn on it. |
| `needs-decision` | A choice belongs to the Allfather; Brokk replies. |
| `blocked` | The worker is stuck and needs Brokk to act. |
| `paused` | Deliberately idling on a known external wait expected to clear (differs from `blocked`). |
| `done` | A Definition-of-done gate is met. |
| `failed` | The task cannot complete. |
| `resolved` | Closes a decision/blocker by exact key; **not** a state. |

A decision/blocker stays open until a `resolved` line carrying its exact key lands; a later
`done:`/`working:` never closes it.

### 3.6 Steering inbox

`state/<id>.inbox/*.msg` is Brokk's durable channel into a running worker. The worker lists
`*.msg`, reads in numeric order, acts, then moves each handled message to
`state/<id>.inbox/handled/`. **The move is the acknowledgement** — without it Brokk rings
again and eventually treats the worker as stuck.

---

## 4. Vör — deterministic state reconciliation

`bin/vor-crew-state.sh <task-id>` reads the current state without a model and without trusting
a `tail -1` of the append-only log. Output is one stable line:

```
state: <working|parked|done|blocked|paused|failed|unknown> · source: <backend|status-log|none> · <detail>
```

The separator is a middle dot surrounded by spaces (` · `). Exit code is **0** on any
successful read regardless of state; **2** on a usage error (no id).

### 4.1 Reconciliation order (`bin/vor-crew-state.sh:40-124`)

1. Read `worktree`, `kind`, `backend`, `window` from `state/<id>.meta`.
2. Missing/gone worktree → `state: unknown · source: none · worktree gone (torn down?)`.
3. No recorded backend target:
   - a log verb mapping to a recognized run-state → `source: status-log`;
   - otherwise → `state: unknown · source: none · no backend target recorded`.
4. Backend target **alive** (`tmux display-message -p -t <t> '#{pane_id}'` / `herdr pane get <t>`):
   - terminal log verdict (`done`/`failed`) → `source: status-log`;
   - working/parked/blocked/paused → `source: status-log`;
   - otherwise → `state: working · source: backend · endpoint alive: <t>`.
5. Backend target **gone**: a terminal log verdict is durable truth; otherwise
   `state: unknown · source: none · backend target gone: <t>`.

### 4.2 Verb → state map (`bin/vor-crew-state.sh:71-81`)

| Log verb | Canonical state |
|---|---|
| `working` | `working` |
| `needs-decision` | `parked` |
| `blocked` | `blocked` |
| `done` | `done` |
| `failed` | `failed` |
| `paused` (configurable verb) | `paused` |
| anything else, incl. `resolved` | `unknown` (never emitted as state) |

`BROKK_PAUSED_VERB` (default `paused`) retargets the paused verb consistently across brief,
state, and reconciliation.

---

## 5. Dispatch profiles and harness override

### 5.1 `config/eindri-dispatch.json`

Brokk reads the dispatch rules **before** dispatching and passes concrete flags. Schema:
`version`, `platform`, `notes`, `rules[]` (`when`, `use[]`, `why`), `default[]`.

| Rule (`when`) | Harness | Model | Effort |
|---|---|---|---|
| General implementation, refactoring, bug fixes | `opencode` | `opencode-go/deepseek-v4.1-flash` | `medium` |
| Deep investigation, diagnosis, planning, design | `opencode` | `opencode-go/deepseek-v4.1-flash` | `xhigh` |
| Trivial mechanical edits / file gathering | `opencode` | `opencode-go/deepseek-v4.1-flash` | `low` |
| Long-running autonomous / background execution | `pi` | (Pi default) | `medium` |
| **default** | `opencode` | `opencode-go/deepseek-v4.1-flash` | `medium` |

Because this file exists, a fresh spawn without an explicit `--harness` is refused — the agent
must consult the rules and pass the resolved harness. Validate it with:

```bash
python3 -c "import json;json.load(open('config/eindri-dispatch.json'))"
```

### 5.2 `config/eindri-harness` (harness override)

Single first non-empty, non-comment line: `<harness> [<model>] [<effort>]`
(`bin/hamr-harness.sh:21-24`). Today's file is just `opencode` (harness-only).

```bash
bin/hamr-harness.sh eindri          # effective Eindri harness
bin/hamr-harness.sh eindri-model    # optional model token (empty when absent)
bin/hamr-harness.sh eindri-effort   # optional effort token (empty when absent)
```

Model/effort come **only** from this file. `default` or absent resolves to Brokk's own harness.

---

## 6. Yggdrasil — worktree isolation

`bin/einherjar-spawn.sh` creates or reuses the worktree at `$BROKK_HOME/.yggdrasil/<id>`:

- Base ref: `origin/HEAD` when resolvable, else `HEAD`; created `--detach` so the worker's
  branch is its own (`bin/einherjar-spawn.sh:373-386`).
- A pre-existing directory that is not a worktree root is refused (no silent reuse).
- A relaunch reuses the exact recorded `worktree` and **refuses if it is gone**.
- The linked worktree's `.git` file points at the project's common git dir; that dir's path is
  recorded (`GIT_COMMON`) so Utgard can mount it at the same path.

Manual equivalents (for inspection/repair):

```bash
git -C <project-dir> worktree add --detach .yggdrasil/<id> HEAD
git -C .yggdrasil/<id> rev-parse --show-toplevel
git -C <project-dir> worktree list
git -C <project-dir> worktree remove .yggdrasil/<id>    # teardown
```

> **Isolation assertion is authoritative.** The brief makes the worker prove
> `pwd -P` and `git rev-parse --show-toplevel` are the worktree, not the primary checkout. If
> they are not, the worker must append `blocked: launched in primary checkout, not an isolated
> worktree` and stop.

---

## 7. Utgard — Docker sealing

`--isolation auto` seals when `docker` is on `PATH` **and** `utgard-runner:latest` exists;
otherwise it runs in the worktree and reports the decision. `--isolation on` fails closed if
either is missing.

Build the image:

```bash
docker build -f .agents/sandbox/Dockerfile.utgard -t utgard-runner:latest .agents/sandbox
```

The exact launch line emitted by `bin/einherjar-spawn.sh:471` (real flags):

```bash
docker run --rm -it --network none --cpus 1.0 --memory 512m \
  --security-opt no-new-privileges --user "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "<worktree>:/sandbox/workspace" \
  [-v "<git-common-dir>:<git-common-dir>"] \
  -v "<STATE>:<STATE>" -v "<DATA>:<DATA>" \
  -w /sandbox/workspace utgard-runner:latest bash "<state>/<id>.launch.sh"
```

| Flag | Why it is there |
|---|---|
| `--rm` | No residue; a failed run never accumulates containers. |
| `--network none` | No network by law (`.agents/sandbox/README.md`). |
| `--cpus 1.0 --memory 512m` | Hard CPU/RAM caps mirroring `sandcastle.config.json`. |
| `--security-opt no-new-privileges` | No privilege escalation. |
| `--user "$(id -u):$(id -g)"` | **The host UID/GID fix.** Without it the worker writes files owned by `agentuser`/root and the host cannot manage them. |
| `-e HOME=/tmp` | The image's `HOME` is read-only/absent for the mounted user; `/tmp` keeps tool caches writable. |
| `-v <worktree>:/sandbox/workspace` | The worktree is the only working surface. |
| `-v <git-common-dir>:<same path>` | **The `.git` fix.** A linked worktree's `.git` is a file pointing at the common git dir; mounting it at the identical path lets git resolve inside the container. Without it every git command fails with "not a git repository". |
| `-v <STATE>:<STATE>` / `-v <DATA>:<DATA>` | The brief's status, inbox, meta, and report paths resolve identically inside and outside. |
| `-w /sandbox/workspace` | Working directory matches the brief's under-Utgard path. |

The sidecar `state/<id>.utgard` records the effective seal:

```
image=utgard-runner:latest
network=none
cpus=1.0
memory=512m
security_opt=no-new-privileges
user=<uid>:<gid>
worktree_mount=<wt>:/sandbox/workspace
git_common_mount=<path>:<path>|none
state_mount=<STATE>:<STATE>
data_mount=<DATA>:<DATA>
launch=<state>/<id>.launch.sh
```

`--isolation off` removes `state/<id>.utgard` and launches `bash <state>/<id>.launch.sh` in
the worktree.

---

## 8. Valhalla — supervision

- **tmux**: creates/detaches window `eindri-<id>` in the current or `brokk` session, disables
  auto-rename, sends the launch command. A duplicate window name is refused
  (`bin/einherjar-spawn.sh:478-499`).
- **herdr**: creates workspace `eindri-<id>` with `--cwd <worktree> --no-focus`, then sends
  the launch command to its pane (`bin/einherjar-spawn.sh:501-516`).
- **Skill assets**: `assets/pi-boot/supervision-tree.yml` defines the Valhalla supervision
  branch (brokk-primary, three Eindri workers, herdr, Mimirsbrunn, Ratatoskr) and
  `assets/pi-boot/herdr-profile.toml` the pane layout. These are reference configurations;
  apply them through the process supervisor, do not hand-run panes.

Inspect a worker:

```bash
bin/vor-crew-state.sh <id>
tmux list-windows -t brokk -F '#{window_name}'
tmux capture-pane -pt brokk:eindri-<id> | tail -40
herdr pane list --workspace <ws>
```

---

## 9. Worked examples

### 9.1 Ship a direct PR

```bash
# 1. Brief (mode resolved at intake)
bin/erindi-brief.sh W0123 my-repo --mode direct-PR
# 2. Brokk replaces {TASK} in data/W0123/brief.md
# 3. Spawn with an explicit dispatch-resolved harness
bin/einherjar-spawn.sh W0123 /home/zerwiz/repos/my-repo \
    --mode direct-PR --harness opencode \
    --model opencode-go/deepseek-v4.1-flash --effort medium \
    --backend tmux --isolation auto
# 4. Watch state
bin/vor-crew-state.sh W0123
```

### 9.2 Scout a codebase (report only)

```bash
bin/erindi-brief.sh W0124 my-repo --scout
bin/einherjar-spawn.sh W0124 /home/zerwiz/repos/my-repo --scout \
    --harness opencode --effort xhigh
```

Report lands at `data/W0124/report.md`; the worktree is scratch.

### 9.3 Relaunch after a crash

```bash
bin/erindi-brief.sh W0123 --relaunch          # same delivery contract
bin/einherjar-spawn.sh W0123 --relaunch --harness pi --effort high
```

Worktree, kind, and mode come from `state/W0123.meta`; only harness/model/effort/isolation may
change. If the worktree is gone, the relaunch is refused — recover it first.

### 9.4 Sealed run (Utgard)

```bash
docker build -f .agents/sandbox/Dockerfile.utgard -t utgard-runner:latest .agents/sandbox
bin/einherjar-spawn.sh W0125 my-repo --mode local-only --harness opencode --isolation on
cat state/W0125.utgard
```

### 9.5 Steer a running worker

```bash
mkdir -p state/W0123.inbox
printf 'Use the v2 API; the v1 endpoint is deprecated.\n' > state/W0123.inbox/001.msg
# worker reads, acts, then acknowledges:
#   mv state/W0123.inbox/001.msg state/W0123.inbox/handled/
```

---

## 10. The record — `state/<id>.meta`

Line-oriented `key=value` written atomically by spawn:

| Key | Meaning |
|---|---|
| `id`, `kind` | Task id; `ship` or `scout`. |
| `mode`, `yolo` | Ship only: the delivery mode and merge posture. |
| `harness`, `raw_launch` | Adapter name; raw command when the escape hatch was used. |
| `model`, `effort` | Resolved model/effort (may be empty). |
| `backend`, `window` | `tmux`/`herdr` and the target id. |
| `worktree`, `project` | The isolated worktree and its source repo. |
| `brief`, `launch` | Paths to `brief.md` and the generated `.launch.sh`. |
| `isolation` | `on`/`off` effective seal. |
| `spawn_gen` | Unique spawn generation (`s<epoch>.<pid>.<rand>`). |

`meta_value` reads the **last** matching key (`grep ... | tail -1`), so a torn write can never
shadow a completed record once the atomic `mv` lands.

---

## 11. Verification

```bash
# 1. Scripts parse
for f in bin/einherjar-spawn.sh bin/erindi-brief.sh bin/vor-crew-state.sh \
         bin/hamr-harness.sh bin/gleipnir-lock-lib.sh; do bash -n "$f" && echo "OK $f"; done

# 2. Dispatch config parses
python3 -c "import json;json.load(open('config/eindri-dispatch.json'))"

# 3. Harness detection answers
bin/hamr-harness.sh
bin/hamr-harness.sh eindri

# 4. Help/usage renders (exit 0)
bin/einherjar-spawn.sh --help >/dev/null && echo "spawn help OK"
bin/erindi-brief.sh --help   >/dev/null && echo "brief help OK"

# 5. Fail-closed on a fresh spawn without an explicit harness (dispatch active)
bin/einherjar-spawn.sh demo /tmp/not-a-repo --mode local-only; echo "exit=$?"

# 6. Worktree isolation for a real git repo
git -C <project-dir> worktree list | grep .yggdrasil/<id>
```

---

## 12. Gotchas

- **Ymir itself is not a git repo.** `git -C /home/zerwiz/Ymir rev-parse` fails; a spawn's
  `<project-dir>` must be a real git working tree or Yggdrasil cannot create the worktree.
- **`config/eindri-dispatch.json` active ⇒ no implicit harness.** Omitting `--harness` is a
  hard error, not a fallback.
- **Verified set is small.** `opencode pi pi-signed` only. `claude`/`codex`/`cursor` are
  **detected** but not launch-verified; pass a raw `--harness` command to trial one.
- **Brief must exist before spawn.** Spawn refuses with the exact regeneration command in the
  error.
- **Mode drift is refused.** If `Delivery contract: mode=` ≠ `--mode`, spawn exits 1.
- **tmux window collision.** `brokk:eindri-<id>` already existing aborts the spawn; tear it
  down or relaunch.
- **`--relaunch` refuses a vanished worktree.** Recover or recreate it; do not delete the meta.
- **Docker UID/GID and `.git` mount are mandatory** for a sealed run; see §7.
- **`resolved` is never a state.** Vör explicitly maps it to `unknown`/non-state so a closed
  decision cannot masquerade as current work.
- **`paused` ≠ `blocked`.** Paused = known external wait expected to clear; blocked = Brokk
  must act.
- **Status is an event log, not state.** Always reconcile with `vor-crew-state.sh`, not `tail`.

## 13. Maintaining this

- When a spawn flag or the printed `spawned` line changes, update §2 and the compiled example
  in the plan (`docs/plans/29-brokk-distro-runtime.md`).
- When a delivery mode is added, update the brief (`bin/erindi-brief.sh`), the dispatch rules,
  and the tables in §3.4 in the same change.
- When the Utgard `docker run` line changes (`bin/einherjar-spawn.sh:451-475`), re-run §11 and
  update §7 verbatim.
- Keep `VERIFIED_HARNESSES`, the dispatch profiles, and `bin/hamr-harness.sh`'s adapter set in
  agreement; a mismatch is a compliance failure (see `runtime-compliance.md`).

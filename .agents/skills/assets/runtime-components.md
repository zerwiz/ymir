# Runtime Components — complete inventory of the Brokk distro runtime

> **Purpose:** Enumerate every runtime component under `bin/`, `.pi/extensions/`, `.opencode/plugins/`, the harness hook files, and the `config/` + `data/` home, with each component's Norse role, purpose, usage, environment, exit codes, and what it calls — precise enough for an agent to operate or rebuild any part from this page alone.

This is the companion reference to [`harness-integration/README.md`](harness-integration/README.md) and plan [`docs/plans/29-brokk-distro-runtime.md`](../../../../docs/plans/29-brokk-distro-runtime.md). The **code is authoritative**; disagreements are listed in §11.

---

## 1. The home model

Ymir separates **tracked code** from **private state**, exactly as the upstream distro pattern does.

| Layer | Location | Tracked? | Contents |
|---|---|---|---|
| Root | `BROKK_ROOT_OVERRIDE` → repo root | yes | `bin/`, `AGENTS.md`, `opencode.json`, `.agents/`, `.pi/`, `.opencode/` |
| Home | `BROKK_HOME` → `BROKK_ROOT_OVERRIDE` or repo root | — | the runtime's private home |
| Data | `$BROKK_HOME/data` | gitignored | operator/projects/learnings/realm/backlog, per-task briefs |
| State | `$BROKK_HOME/state` | gitignored | lock, metas, status logs, wake queue, cron, runes lock |
| Config | `$BROKK_HOME/config` | gitignored | cron.yaml, eindri-harness, eindri-dispatch.json |
| Worktrees | `$BROKK_HOME/.yggdrasil/<id>` | gitignored | per-Eindri git worktrees |

`.gitignore` enforces the privacy: `data/*` (except `*.example`), `state/*`, `config/*`, `.yggdrasil/`, `svartalfaheim/*/.env.realm`, `.agents/memory/*.db`.

---

## 2. Environment contract (all components)

| Variable | Meaning | Default | Used by |
|---|---|---|---|
| `BROKK_ROOT_OVERRIDE` | tracked code root | script-relative repo root | all scripts |
| `BROKK_HOME` | private home | `BROKK_ROOT_OVERRIDE` or root | all scripts |
| `BROKK_STATE_OVERRIDE` | state dir | `$BROKK_HOME/state` | all scripts |
| `BROKK_DATA_OVERRIDE` | data dir | `$BROKK_HOME/data` | brief, jobs, spawn |
| `BROKK_CONFIG_OVERRIDE` | config dir | `$BROKK_HOME/config` | hamr, spawn, cron |
| `BROKK_REALM` | active realm | `data/realm.md` line 1, else `way-of` | digest, jobs |
| `BROKK_SESSION_PID` | live harness pid bound to the lock | `${BROKK_SESSION_PID:-$$}` | lock, Pi/OpenCode adapters |
| `BROKK_PROC_ROOT_OVERRIDE` | `/proc` root for Cursor identity | `/proc` | hamr |
| `BROKK_PI_HARNESS` | `pi-signed` selects the signed Pi identity | unset | hamr |
| `BROKK_SESSIONSTART_INELIGIBLE` | `1` makes Pi's prerequisite exit 3 | unset | sessionstart-run |
| `RODD_OPERATIONAL_INPUT_SCRIPT` | override the Rödd CLI path | adapter-relative | Pi Rödd lib |

Per-component variable lists appear in each section below.

---

## 3. `bin/` script inventory

### 3.1 Summary table

| Script | Norse | Purpose | Usage | Exit |
|---|---|---|---|---|
| `bin/saga-session-start.sh` | **Sága** | one-command session-start digest (8 stages) | `saga-session-start.sh` | 0 |
| `bin/saga-sessionstart-run.sh` | **Sága** | session-open router for run-tier harnesses | `saga-sessionstart-run.sh [--source <s>] [--pi-prerequisite]` | 0 (3 if Pi stand-down) |
| `bin/saga-wake-drain.sh` | **Sága** | present durable wakes + open decisions | `saga-wake-drain.sh` | 0 |
| `bin/syn-watch-arm.sh` | **Sýn** | arm one watcher cycle | `syn-watch-arm.sh --restart` / `--handling-delivered <g> --watcher-pid <p>` | 0 |
| `bin/syn-turnend-guard.sh` | **Sýn** | refuse a blind turn end | `syn-turnend-guard.sh [--claude]` | 0 healthy/inert; 2 off |
| `bin/syn-arm-pretool-check.sh` | **Sýn** | deny backgrounding the arm | `... --command <cmd>` | 0 allow; 2 block |
| `bin/syn-cd-pretool-check.sh` | **Sýn** | deny escaping `cd` | `... --command <cmd>` | 0 allow; 2 block |
| `bin/gleipnir-lock-lib.sh` | **Gleipnir** | per-home session lock library | source only | fn return 0/1 |
| `bin/rodd-operational-input.sh` | **Rödd** | operational wire encode/kind/classify/body | `... encode <kind>` \| `kind` \| `classify` \| `body` \| `--help` | 0; 1 non-match; 2 usage |
| `bin/hamr-harness.sh` | **Hamr** | detect harness identity | `hamr-harness.sh` \| `eindri` \| `eindri-model` \| `eindri-effort` | 0 |
| `bin/einherjar-spawn.sh` | **Einherjar** | spawn an Eindri worker | `einherjar-spawn.sh <id> <project> --mode <m> [flags]` | 0; 1 error; 2 usage |
| `bin/erindi-brief.sh` | **Erindi** | scaffold a worker brief | `erindi-brief.sh <id> <repo> --mode <m>` \| `--scout` \| `--relaunch` | 0; 1 error; 2 usage |
| `bin/vor-crew-state.sh` | **Vör** | read a worker's current state | `vor-crew-state.sh <id>` | 0; 2 usage |
| `bin/nornir-cron-start.sh` | **Nornir** | ensure scheduled jobs run (idempotent) | `nornir-cron-start.sh [--status\|--stop]` | 0 |
| `bin/nornir-job-daily-briefing.sh` | **Sága** | 07:00 deterministic briefing | `nornir-job-daily-briefing.sh` | 0; 1 IO |
| `bin/nornir-job-git-sync.sh` | **Yggdrasil** | safe git fetch/push | `nornir-job-git-sync.sh` | 0; 1 git missing; 2 bad mode |
| `bin/nornir-job-memory-housekeeping.sh` | **Muninn** | backup-gated memory snapshot/prune | `nornir-job-memory-housekeeping.sh` | 0 |
| `bin/nornir-job-observer.sh` | **Huginn** | read-only observation of command + Brokk | `nornir-job-observer.sh` | 0 |
| `bin/runes-append.sh` | **Runes** | append-only chained audit ledger | `... <actor> <event> [--order W] [--realm R] --message "..."` \| `--help` | 0; 1 IO; 2 usage |

### 3.2 `bin/saga-session-start.sh` — Sága, the session digest

The one-command session open. Prints **one ordered digest** and does nothing else. Source it? No — it is a script; it sources `gleipnir-lock-lib.sh`.

Sections, in order:

| # | Section | Content |
|---|---|---|
| 1 | `LOCK` | acquire the per-home lock; on refusal print `READ-ONLY: session lock held by pid N` |
| 2 | `BOOTSTRAP` | detect-only: `git bash node` present, `svartalfaheim/<realm>/.env.realm` present/ABSENT |
| 3 | `WAKE QUEUE` | calls `bin/saga-wake-drain.sh`; prints pending wakes and `open decisions: N` |
| 4 | `SUPERVISION` | static instruction: arm via the harness adapter, never run `syn-watch-arm.sh` by hand |
| 5 | `FLEET DIGEST` | count of `state/*.meta`; count of `^- Status: ADDED` in `docs/masterplan.md` (open forge orders) |
| 6 | `CONTEXT DIGEST` | realm, then `data/operator.md`, `data/projects.md`, `data/learnings.md`, each with `ABSENT:` when missing |
| 7 | `CRON START` | calls `bin/nornir-cron-start.sh` |
| 8 | `NEXT STEP` | closing pointer: "Ascend Hlidskjalf as Brokk. Address the Allfather. Read once; act." |

- **Never re-read** the digest's sources unless a source was reported absent/corrupt (read-once contract).
- Env: `BROKK_ROOT_OVERRIDE`, `BROKK_HOME`, `BROKK_STATE_OVERRIDE`, `BROKK_DATA_OVERRIDE`, `BROKK_CONFIG_OVERRIDE`, `BROKK_REALM`, `BROKK_SESSION_PID`.
- Calls: `saga-wake-drain.sh`, `nornir-cron-start.sh`.
- Exit: 0 always.

### 3.3 `bin/saga-sessionstart-run.sh` — Sága, the session-open router

The single command every session-open adapter invokes. Decides full run / re-emit / nudge from the source.

```
saga-sessionstart-run.sh [--source startup|new|clear|compact|resume|reload|fork] [--pi-prerequisite]
```

| Source | Behavior |
|---|---|
| `startup`, `new`, `*` (default) | run `saga-session-start.sh`; write `state/.session-start-complete` |
| `clear`, `compact` | if `.session-start-complete` exists → print `CONTEXT RE-EMIT`; else run the full digest |
| `resume`, `reload`, `fork` | print `Run \`bash .../saga-session-start.sh\` exactly once now ...` |

- With no `--source` and a non-tty stdin, parses `"source":"..."` from a Claude/Codex JSON payload.
- `--pi-prerequisite` + `BROKK_SESSIONSTART_INELIGIBLE=1` → **exit 3** (stand-down).
- Every ordinary transport path exits 0: a failed start must reach the agent as text, never block the session.
- Env: `BROKK_ROOT_OVERRIDE`, `BROKK_HOME`, `BROKK_STATE_OVERRIDE`, `BROKK_SESSIONSTART_INELIGIBLE`.
- Calls: `saga-session-start.sh`.

### 3.4 `bin/saga-wake-drain.sh` — Sága, the wake presenter

Prints the durable wake queue (`state/.wake-queue`) and the count of open decision markers (`state/*.decision`).

```
wake queue: N pending
WAKE <record>
WAKE_ACK_REQUIRED: acknowledge handled wakes to drop them from the queue
open decisions: N
```

Records stay durable until acknowledged. Env: `BROKK_ROOT_OVERRIDE`, `BROKK_HOME`, `BROKK_STATE_OVERRIDE`.

### 3.5 `bin/syn-watch-arm.sh` — Sýn, the watcher cycle

Arms one supervision cycle. `--restart` prints `watcher: started pid=<pid> recovery-generation=<gen>`, writes `state/.supervision-armed`, and loops.

| Actionable condition | Line | Effect |
|---|---|---|
| non-empty `state/.wake-queue` | `signal: wake queue` | exits 0 |
| any `state/*.signal` | `signal: <name>` (file removed) | exits 0 |
| any `state/*.check` | `check: <name>` (file removed) | exits 0 |
| `state/.watcher-stop` | `stale: watcher stopped by operator` (file removed) | exits 0 |

- Refuses with exit 0 + stderr `watcher: read-only - no live session holds the lock` when no live lock owner.
- Writes `state/.watch.heartbeat` each loop iteration (every `BROKK_WATCH_POLL_SECONDS`).
- `--handling-delivered <generation> --watcher-pid <pid>` prints `watcher: handling delivered ...` and exits 0 (ack path used by Gná/Sýn plugins).
- Env: `BROKK_ROOT_OVERRIDE`, `BROKK_HOME`, `BROKK_STATE_OVERRIDE`, `BROKK_WATCH_POLL_SECONDS` (5), `BROKK_WATCH_HEARTBEAT_STALE_SECONDS` (60), `BROKK_WATCH_PREDECESSOR_ARM_PID`.
- Sources `gleipnir-lock-lib.sh`.

### 3.6 `bin/syn-turnend-guard.sh` — Sýn, the blind-turn refusal

```
syn-turnend-guard.sh [--claude]
# drains stdin ({"stop_hook_active":false})
# inert until state/.supervision-armed exists → exit 0
# stale when now - state/.watch.heartbeat > BROKK_WATCH_HEARTBEAT_STALE_SECONDS → exit 2
```

On exit 2 stderr carries the recovery instruction. Env: `BROKK_ROOT_OVERRIDE`, `BROKK_HOME`, `BROKK_STATE_OVERRIDE`, `BROKK_WATCH_HEARTBEAT_STALE_SECONDS`.

### 3.7 `bin/syn-arm-pretool-check.sh` / `bin/syn-cd-pretool-check.sh` — Sýn, seatbelts

v0 inert-by-default policy owners.

```bash
syn-arm-pretool-check.sh --command <cmd>   # denies *syn-watch-arm.sh*&  or  &*syn-watch-arm.sh*
syn-cd-pretool-check.sh  --command <cmd>   # denies *'cd '*'/../'*
# exit 0 allow; exit 2 block with reason on stderr
```

Unknown flags are ignored (`shift`). No env. Both accept `--claude`/`--cursor` as ignored transport tags.

### 3.8 `bin/gleipnir-lock-lib.sh` — Gleipnir, the session lock (source library)

Source-safe. Writes/releases `state/.lock` as a bare pid.

| Function | Signature | Notes |
|---|---|---|
| `gleipnir_root` | `<result-var>` | root path |
| `gleipnir_state_dir` | `<result-var>` | state dir |
| `gleipnir_pid_alive` | `<pid>` | numeric-guarded `kill -0` |
| `gleipnir_lock_path` | `<result-var>` | `$state/.lock` |
| `gleipnir_lock_owner` | `<result-var>` | trims whitespace from `.lock` |
| `gleipnir_lock_owned` | — | exit 0 if an ancestor pid (≤8 levels) owns the lock |
| `gleipnir_lock_acquire` | — | returns 1 if another **live** pid holds it; else writes `${BROKK_SESSION_PID:-$$}` |
| `gleipnir_lock_release` | — | removes `.lock` only if `$$` is the owner |

Exports `GLEIPNIR_LOCK_ACQUIRED=0`. Env: `BROKK_ROOT_OVERRIDE`, `BROKK_HOME`, `BROKK_STATE_OVERRIDE`, `BROKK_SESSION_PID`.

### 3.9 `bin/rodd-operational-input.sh` — Rödd, the operational wire

Both a source-safe library and the cross-language CLI. **Single owner** of the wire grammar; callers never re-parse.

Wire form: `<U+2063>RODD_OP: v1 <kind>: <body>`.

| Command | stdin | stdout | Exit |
|---|---|---|---|
| `encode <kind>` | body | encoded message | 0; 2 invalid kind/no body |
| `kind` | current input | kind | 0; 1 non-match |
| `classify` | current or legacy input | kind | 0; 1 non-match |
| `body` | current input | body | 0; 1 non-match |
| `--help` | — | usage | 0 |

Current kinds (`RODD_KINDS`): `session-start watcher turn-end-guard away-supervisor launch-brief branch-outcome`, plus the `from-brokk` compatibility carrier (`RODD_FROMBROKK_MARK`). Legacy detection exists only for persisted pre-protocol transcripts. Bash 3.2 compatible. No env required; the Pi Rödd lib may set `RODD_OPERATIONAL_INPUT_SCRIPT`.

### 3.10 `bin/hamr-harness.sh` — Hamr, the shape detector

Prints the harness identity of the current process tree.

```
hamr-harness.sh               → claude|codex|opencode|pi|pi-signed|grok|kimi|cursor|unknown
hamr-harness.sh eindri        → config/eindri-harness harness, or own when absent/"default"
hamr-harness.sh eindri-model  → optional model token from config/eindri-harness
hamr-harness.sh eindri-effort → optional effort token
```

- Layer 1 env markers, checked **in order**: `CURSOR_AGENT`/`CURSOR_INVOKED_AS` → `CLAUDECODE` → `PI_CODING_AGENT` (with `BROKK_PI_HARNESS`) → `GROK_AGENT`.
- Layer 2 walks ancestors ≤8 levels by `comm`, then `argv0`/`args` for bare interpreters.
- `config/eindri-harness` format: one line `<harness> [<model>] [<effort>]`; first non-blank, non-`#` line wins.
- Rejects a bare `agent`/`MainThread` unless structural Cursor evidence exists.
- Env: `BROKK_ROOT_OVERRIDE`, `BROKK_HOME`, `BROKK_CONFIG_OVERRIDE`, `BROKK_PROC_ROOT_OVERRIDE`.

### 3.11 `bin/einherjar-spawn.sh` — Einherjar, the worker spawn

```
einherjar-spawn.sh <task-id> <project-dir> --mode <direct-PR|local-only|no-mistakes>
    [--yolo on|off] [--harness <name>] [--model <name>]
    [--effort low|medium|high|xhigh|max] [--backend tmux|herdr]
    [--isolation on|off|auto]
einherjar-spawn.sh <task-id> <project-dir> --scout [flags...]
einherjar-spawn.sh <task-id> --relaunch [--harness ...] [--model ...] [--effort ...] [--isolation ...]
```

Behavior:

1. Validates the task id (no `/`, no leading `.`, no spaces).
2. Resolves the harness; **fails closed** against `VERIFIED_HARNESSES='opencode pi pi-signed'` (line 53). A `--harness` with whitespace is a raw launch escape hatch with a warning. If `config/eindri-dispatch.json` exists, fresh spawns must pass an explicit `--harness`.
3. Requires the brief at `data/<id>/brief.md`; a ship launch refuses if the brief's `Delivery contract: mode=` disagrees with `--mode`.
4. Creates/reuses a Yggdrasil worktree at `$BROKK_HOME/.yggdrasil/<id>` (detached at `origin/HEAD` or `HEAD`).
5. Resolves isolation: `on` requires docker + `utgard-runner:latest`; `auto` picks it when present and reports the decision.
6. Builds `state/<id>.launch.sh`, writes `state/<id>.utgard` when isolated, then launches in tmux (`eindri-<id>` window) or herdr (`eindri-<id>` workspace).
7. Records `state/<id>.meta` and prints `spawned <id> harness=... kind=... mode=... yolo=... backend=... target=... worktree=... isolation=...`.

Env: `BROKK_ROOT_OVERRIDE`, `BROKK_HOME`, `BROKK_STATE_OVERRIDE`, `BROKK_DATA_OVERRIDE`, `BROKK_CONFIG_OVERRIDE`, `BROKK_BACKEND`, `BROKK_TMUX_SESSION`, `TMUX`, `HERDR_ENV`, plus harness markers for detection.
Exit: 0 ok; 1 operational error; 2 missing task-id/project.
The `.utgard` file records: image, `network=none`, cpus 1.0, memory 512m, `no-new-privileges`, uid:gid, worktree/state/data mounts, launch script.

### 3.12 `bin/erindi-brief.sh` — Erindi, the worker brief

Scaffolds `data/<id>/brief.md` with the Setup / Rules / Definition-of-done contract and the fixed `Delivery contract: mode=<mode>` line that `einherjar-spawn.sh` reads.

```
erindi-brief.sh <task-id> <repo-name> --mode <no-mistakes|direct-PR|local-only>
erindi-brief.sh <task-id> <repo-name> --scout
erindi-brief.sh <task-id> --relaunch
```

- `--scout` writes the report contract (`data/<id>/report.md`); no branch/PR.
- `--relaunch` re-derives kind/mode from `state/<id>.meta`; refuses to invent a mode.
- Refuses to overwrite an existing brief unless `--relaunch`.
- Status protocol states: `working, needs-decision, blocked, <paused>, done, failed` appended to `state/<id>.status`.
- Steering inbox: `state/<id>.inbox/NNN.msg`; moving to `handled/` is the acknowledgement.
- Env: `BROKK_ROOT_OVERRIDE`, `BROKK_HOME`, `BROKK_DATA_OVERRIDE`, `BROKK_STATE_OVERRIDE`, `BROKK_PAUSED_VERB` (default `paused`).

### 3.13 `bin/vor-crew-state.sh` — Vör, the state reconciler

Read-only deterministic read of a worker's **current** state, reconciling the append-only status log against the live backend endpoint recorded in the meta.

```
state: <working|parked|done|blocked|paused|failed|unknown> · source: <backend|status-log|none> · <detail>
```

- Maps `needs-decision` → `parked`; `resolved` is never a state.
- Verifies endpoint liveness with `tmux display-message` or `herdr pane get`.
- Env: `BROKK_ROOT_OVERRIDE`, `BROKK_HOME`, `BROKK_STATE_OVERRIDE`, `BROKK_PAUSED_VERB`.
- Exit 0 on any successful read; 2 usage.

### 3.14 `bin/nornir-cron-start.sh` — Nornir, the scheduler

Idempotently keeps one scheduler loop alive (pid in `state/cron.pid`).

```
nornir-cron-start.sh            # start if not running
nornir-cron-start.sh --status   → cron: running pid=<p> jobs=<n>  |  cron: stopped jobs=<n>
nornir-cron-start.sh --stop     # kill the loop, remove the pid file
```

- Reads `config/cron.yaml` (`HH:MM <command>` lines); no jobs → `cron: no jobs configured` exit 0.
- The loop polls every 45s, matches `HH:MM` once per day via a per-command stamp under `state/.cron-fired/<key>`, and holds a per-job `flock` under `state/.cron-locks/`.
- Exports `BROKK_HOME`/`BROKK_STATE_OVERRIDE`/`BROKK_CONFIG_OVERRIDE`/`BROKK_ROOT_OVERRIDE`/`BROKK_REALM` to each job; runs from `$BROKK_HOME`.
- `running_pid` verifies the live pid's command line contains `cron run:` to defeat pid reuse.
- Logs to `state/cron.log` with rotation at `BROKK_CRON_LOG_MAX_BYTES` (1 MiB).
- Env: `BROKK_ROOT_OVERRIDE`, `BROKK_HOME`, `BROKK_STATE_OVERRIDE`, `BROKK_CONFIG_OVERRIDE`, `BROKK_CRON_LOG_MAX_BYTES`.

### 3.15 `bin/nornir-job-daily-briefing.sh` — Sága, the daily seeing

Deterministic (no model call) daily briefing. Writes `svartalfaheim/<realm>/workspace/memory/daily/YYYY-MM-DD.md` atomically from four inputs: open forge orders from `docs/masterplan.md`, fleet/state, active plan statuses, and today's Runes tail. Safe to re-run within a day.

Env: `BROKK_HOME`, `BROKK_STATE_OVERRIDE`, `BROKK_DATA_OVERRIDE`, `BROKK_REALM`, `BROKK_BRIEF_DIR`, `BROKK_BRIEF_MAX_ORDERS` (15), `BROKK_BRIEF_MAX_RUNES` (12). Sources `runes-append.sh`. Exit 1 if the output dir cannot be created/written.

### 3.16 `bin/nornir-job-git-sync.sh` — Yggdrasil, the world-tree sync

Never force, never discard unlanded work.

- `BROKK_GIT_SYNC_MODE=fetch` (default): `fetch --prune`, then `merge --ff-only` on the tracked upstream; divergence is reported and left untouched.
- `BROKK_GIT_SYNC_MODE=push` (opt-in): commit dirty tree (`nornir git-sync <stamp>`), then push (no force).
- Discovers targets from `BROKK_GIT_SYNC_TARGETS` (colon-separated) or auto-discovery of `$BROKK_HOME`, `workspace/`, `midgard/`, realm `projects/`.
- Env: `BROKK_ROOT_OVERRIDE`, `BROKK_HOME`, `BROKK_DATA_OVERRIDE`, `BROKK_GIT_SYNC_MODE`, `BROKK_GIT_SYNC_REMOTE` (origin), `BROKK_GIT_SYNC_TARGETS`, `BROKK_REALM`. Sources `runes-append.sh`. Exit 1 if git missing; 2 bad mode.

### 3.17 `bin/nornir-job-memory-housekeeping.sh` — Muninn, the memory raven

Backup-first, prune-gated.

1. Reports the engram/vector store state (`BROKK_MIMIR_DB`); says `ABSENT` when unwired — never fakes decay/compress.
2. Snapshots memory roots to `$BROKK_BACKUP_DIR/memory-YYYY-MM-DD.tar.gz`.
3. Prunes ephemeral files only when `BROKK_MEMORY_PRUNE=1` **and** a backup succeeded.

Env: `BROKK_HOME`, `BROKK_STATE_OVERRIDE`, `BROKK_DATA_OVERRIDE`, `BROKK_BACKUP_DIR` (`$state/backups`), `BROKK_MEMORY_ROOTS` (`.agents/memory:workspace/memory:svartalfaheim/<realm>/workspace/memory`), `BROKK_MIMIR_DB`, `BROKK_MEMORY_PRUNE`, `BROKK_MEMORY_PRUNE_DAYS` (7), `BROKK_REALM`. Sources `runes-append.sh`.

### 3.18 `bin/nornir-job-observer.sh` — Huginn, the observation raven

**Read-only** observation of Ymir's own runtime (`docs/masterplan.md` orders, `.agents/agents` roster, `.agents/memory/well`, `workspace/memory/runes_audit.md`, `smidja/smidja_data/smidja.db` read-only SQLite) plus an external, read-only worktree root. Never writes the runtime; carves a Runes line and appends `state/observer.log` for every observation, including explicit `ABSENT` lines.

Env: `BROKK_ROOT_OVERRIDE`, `BROKK_HOME`, `BROKK_STATE_OVERRIDE`, `BROKK_YGGDRASIL_ROOT` (`~/.Yggdrasil`). Sources `runes-append.sh`.

### 3.19 `bin/runes-append.sh` — Runes, the audit ledger

Append-only, checksum-chained JSONL under `workspace/memory/runes_audit.md`.

```
runes-append.sh <actor> <event> [--order Wxxxx] [--realm R] --message "..."
# library: . bin/runes-append.sh ; runes_append <actor> <event> ... --message "..."
```

Each entry folds the previous `checksum` into its own (`prev` field), appended under one exclusive `flock` so concurrent writers cannot fork the chain. Never rewrites or truncates. Head: `# YGGDRASIL Audit Trail`.

Env: `BROKK_HOME`, `BROKK_RUNES_FILE`, `BROKK_RUNES_DIR` (`$home/workspace/memory`), `BROKK_RUNES_LOCK` (`$home/state/runes.lock`), `BROKK_ROOT_OVERRIDE`. Exports `RUNES_LAST_CHECKSUM`. Exit 0 appended; 1 IO; 2 usage (prints `error:` + `help:`).

---

## 4. `.pi/extensions/` — Pi adapter components

| File | Norse | Function |
|---|---|---|
| `syn-turnend-guard.ts` | **Sýn** | session-start injection (`before_agent_start`), compaction re-emit (`session_compact`), turn-end guard (`agent_settled`), PreToolUse seatbelts (`tool_call`) |
| `gna-pi-watch.ts` | **Gná** | watcher continuity: `session_start`/`session_shutdown`, `gna_watch_arm` tool, `/gna-watch-arm` command, arm child supervision |
| `lib/vordr-sessionstart-supervisor.mjs` | **Vörðr** | detached digest child supervisor with IPC `{type:"result",code,bytes}` |
| `lib/rodd-operational-input.ts` | **Rödd** | `encodeRoddOperationalInput`, `classifyRoddOperationalText`, `classifyRoddCurrentOperationalText` |

State markers: `state/.pi-syn-turnend-loaded`, `state/.pi-gna-watch-loaded` (each holds `<sha256>\n<pid>`). Full deep dive: [`harness-integration/pi.md`](harness-integration/pi.md).

---

## 5. `.opencode/plugins/` — OpenCode adapter components

| File | Export | Function |
|---|---|---|
| `saga-sessionstart.js` | `SagaSessionstart` | `session.created` → run wrapper, inject via `promptAsync` |
| `syn-watch-arm.js` | `SynWatchArm` | `session.idle` → arm; publishes `globalThis.__brokkOpenCodeWatchArm` |
| `syn-turnend-guard.js` | `SynTurnendGuard` | `session.idle` → consult coordinator, then guard, re-prompt on exit 2 |
| `syn-pretool-check.js` | `SynPretoolCheck` | `tool.execute.before` → arm seatbelt (throw to block) |
| `syn-cd-check.js` | `SynCdCheck` | `tool.execute.before` → cd seatbelt (throw to block) |
| `lib/rodd-operational-input.js` | `encodeRoddOperationalInput(root, kind, content)` | Rödd wire bridge |
| `package.json` | — | `{"private":true,"type":"module"}`; plugins auto-load by path |

Full deep dive: [`harness-integration/opencode.md`](harness-integration/opencode.md).

---

## 6. Harness hook files

| File | Harness | Hook groups | Deep dive |
|---|---|---|---|
| `.claude/settings.json` | Claude Code | `SessionStart`, `Stop` (guard + asyncRewake arm) | [`claude-code.md`](harness-integration/claude-code.md) |
| `.codex/hooks.json` | Codex | `SessionStart`, `PreToolUse` (Bash), `Stop` + `[features].hooks=true` | [`codex.md`](harness-integration/codex.md) |
| `.cursor/hooks.json` | Cursor | `sessionStart`, `preToolUse` (Shell), `stop` | [`cursor.md`](harness-integration/cursor.md) |
| *(none)* | Grok | not implemented in Ymir | — |

`opencode.json` is the OpenCode harness config: `default_agent: brokk`, agent roster, `skills.paths: [".agents/skills"]`. Plugins are discovered by path, not declared.

---

## 7. `config/` files

| File | Format | Purpose |
|---|---|---|
| `config/cron.yaml` | `HH:MM <command>` lines, `#` comments | Nornir schedule. Current jobs: `07:00` daily briefing, `06:00` observer, `00:30` memory housekeeping, `00:00` git sync |
| `config/eindri-harness` | one line `<harness> [<model>] [<effort>]` | default harness for dispatched Eindri. Current: `opencode` |
| `config/eindri-dispatch.json` | JSON (rules + default) | per-task harness/model/effort selection rules. If present, `einherjar-spawn.sh` requires an explicit `--harness` |
| `config/backend` *(optional)* | one word `tmux`/`herdr` | backend override for `einherjar-spawn.sh`; absent here |
| `config/x-mode.env` *(optional)* | shell env | sourced by the OpenCode arm spawn; makes `shouldArm` true. Absent by default |

`config/eindri-dispatch.json` rules (current):

| When | Use |
|---|---|
| General implementation / refactoring / bug fixes | opencode + `opencode-go/deepseek-v4.1-flash`, effort `medium` |
| Deep investigation / planning / ambiguous design | opencode + flash, effort `xhigh` |
| Trivial mechanical edits | opencode + flash, effort `low` |
| Long-running autonomous/background workers | pi, effort `medium` (no model → Pi default) |
| default | opencode + flash, `medium` |

---

## 8. `data/` files

| File | Purpose |
|---|---|
| `data/realm.md` | active realm (one line). Current: `way-of` |
| `data/operator.md` | Allfather preferences and working style, injected at session start |
| `data/projects.md` | realm/project registry table (project, realm, house, path, posture) |
| `data/learnings.md` | curated dated operational facts |
| `data/backlog.md` | pointer/queue summary; the source of truth is `docs/masterplan.md` |
| `data/<id>/brief.md` | per-Eindri errand (scaffolded by `erindi-brief.sh`) |
| `data/<id>/report.md` | scout deliverable |

---

## 9. `state/` runtime files (reference)

| Path | Written by | Meaning |
|---|---|---|
| `.lock` | Gleipnir | live session pid |
| `.supervision-armed` | `syn-watch-arm.sh` | guard-enable marker |
| `.watch.heartbeat` | `syn-watch-arm.sh` | epoch seconds heartbeat |
| `.wake-queue` | watcher/peers | durable wake records |
| `*.signal`, `*.check` | watchers/peers | actionable signals consumed by the arm |
| `.watcher-stop` | operator | asks the arm to exit `stale:` |
| `*.decision` | approval gates | open decisions counted by wake-drain |
| `<id>.meta` | `einherjar-spawn.sh` | task record (id, kind, mode, harness, model, effort, backend, window, worktree, project, brief, isolation, launch, spawn_gen) |
| `<id>.status` | Eindri worker | append-only status log |
| `<id>.launch.sh` | `einherjar-spawn.sh` | exact launch command script |
| `<id>.utgard` | `einherjar-spawn.sh` | isolation record (image, mounts, limits) |
| `<id>.inbox/` | Brokk | steering messages; `handled/` subdir |
| `.session-start-complete` | `saga-sessionstart-run.sh` | records a completed startup (for re-emit) |
| `.pi-syn-turnend-loaded`, `.pi-gna-watch-loaded` | Pi extensions | load markers |
| `.afk` | operator | suppresses arming in `shouldArm` |
| `cron.pid`, `cron.log` | `nornir-cron-start.sh` | scheduler pid + log |
| `.cron-fired/<key>` | scheduler | per-command day stamp |
| `.cron-locks/<key>.lock` | scheduler | per-job flock |
| `backups/` | Muninn | memory snapshots |
| `observer.log`, `observer.last` | Huginn | observation log + last summary |
| `runes.lock` | Runes | append lock |

---

## 10. Verification

### 10.1 Scripts parse

```bash
cd "$BROKK_HOME"
for f in bin/*.sh; do bash -n "$f" || echo "SYNTAX FAIL: $f"; done && echo "bash -n clean"
```

### 10.2 Libs behave under `set -u` when sourced

```bash
bash -c '. bin/gleipnir-lock-lib.sh; . bin/runes-append.sh; . bin/rodd-operational-input.sh; echo "sourced ok"'
```

### 10.3 JSON and YAML-shaped config

```bash
python3 -m json.tool config/eindri-dispatch.json >/dev/null && echo "dispatch ok"
python3 -m json.tool opencode.json >/dev/null && echo "opencode ok"
python3 -m json.tool .opencode/plugins/package.json >/dev/null && echo "plugins pkg ok"
grep -vE '^[[:space:]]*(#|$)' config/cron.yaml | wc -l
```

### 10.4 Digest is complete

```bash
bin/saga-session-start.sh | grep -E '^== ' 
# expect: LOCK, BOOTSTRAP, WAKE QUEUE, SUPERVISION, FLEET DIGEST, CONTEXT DIGEST, CRON START, NEXT STEP
```

### 10.5 Watcher, guard, wake drain

```bash
bin/saga-wake-drain.sh
: > state/.wake-queue; bin/syn-watch-arm.sh --restart   # exits "signal: wake queue"
rm -f state/.supervision-armed
echo '{"stop_hook_active":false}' | bin/syn-turnend-guard.sh; echo "inert -> $? (0)"
touch state/.supervision-armed; rm -f state/.watch.heartbeat
echo '{"stop_hook_active":false}' | bin/syn-turnend-guard.sh; echo "stale -> $? (2)"
```

### 10.6 Harness detection

```bash
bin/hamr-harness.sh
bin/hamr-harness.sh eindri        # honour config/eindri-harness
bin/hamr-harness.sh eindri-model
bin/hamr-harness.sh eindri-effort
```

### 10.7 Rödd round-trip

```bash
printf 'hello' | bin/rodd-operational-input.sh encode watcher \
  | bin/rodd-operational-input.sh kind        # → watcher
printf 'hello' | bin/rodd-operational-input.sh encode watcher \
  | bin/rodd-operational-input.sh body        # → hello
bin/rodd-operational-input.sh --help >/dev/null && echo "rodd help ok"
```

### 10.8 Runes append (safe in a temp home)

```bash
tmp=$(mktemp -d); mkdir -p "$tmp/state"
BROKK_ROOT_OVERRIDE="$tmp" BROKK_HOME="$tmp" bin/runes-append.sh tester probe --message "smoke"
grep -c '"checksum":"' "$tmp/workspace/memory/runes_audit.md"
```

### 10.9 Cron status

```bash
bin/nornir-cron-start.sh --status       # → cron: running pid=... jobs=4
```

---

## 11. Gotchas

- **`saga-session-start.sh` acquires but never releases the lock.** A refused lock means the whole session is read-only. Release is process-exit bound.
- **The fleet digest counts `state/*.meta`, not `data/backlog.md`.** Plan §6 claims `data/backlog.md` feeds the fleet digest; the code does not read it there.
- **The digest has 8 sections, not the 9 in plan §6.** There is no `NETWORK CHECKS` stage.
- **`bin/einherjar-spawn.sh:170` calls `hamr-harness.sh crew`, but the subcommand is `eindri`.** `crew` falls through to `detect_own`, so `config/eindri-harness` is ignored on the Hamr path (the inline fallback honours it). See §12.
- **`config/eindri-dispatch.json` makes fresh spawns require an explicit `--harness`.** This is intentional (consultation backstop) but surprises callers who omit it.
- **`--relaunch` cannot change mode/kind/project.** Only harness/model/effort/isolation may change; mode is re-derived from the meta.
- **The daily briefing is deterministic by design.** No model call; do not "improve" it into an LLM summary.
- **Muninn never prunes without a successful backup.** `BROKK_MEMORY_PRUNE=1` is inert if the backup failed.
- **Huginn observes only Ymir's own tree** (plus the read-only external worktree root). Never add a write path.
- **`BROKK_GIT_SYNC_MODE=push` commits a dirty tree.** That is not a bug; it is the "never discard unlanded work" law. Still no force.
- **`nornir-cron-start.sh --stop` leaves `.cron-fired` stamps in place.** A job restarted the same day will not double-run until the date rolls.
- **`.afk` suppresses arming** (`shouldArm` in the OpenCode plugin and the equivalent gate). If supervision "won't arm", check for `state/.afk`.
- **A linked worktree never owns supervision.** `isPrimaryRoot` requires `git-dir == git-common-dir`.
- **`rodd-operational-input.sh` printed `body` without a trailing newline; `kind`/`classify` print one.** Callers strip as needed.

---

## 12. Code-vs-doc disagreements (truth is the code)

| Doc says | Code says (truth) |
|---|---|
| Plan §12/§13 and `.pi/extensions/README.md` name OpenCode adapter files `syn-sessionstart.js` / `gna-watch-arm.js` | actual: `saga-sessionstart.js`, `syn-watch-arm.js` |
| `.pi/extensions/README.md:36-38` says OpenCode/Claude/Codex/Cursor adapters "are still to come" | all four are landed (`.opencode/plugins/*`, `.claude/settings.json`, `.codex/hooks.json`, `.cursor/hooks.json`) |
| Plan §13 lists `bin/hamr-harness.sh`, `bin/einherjar-spawn.sh`, `bin/erindi-brief.sh`, `bin/vor-crew-state.sh`, `bin/nornir-job-*.sh`, `bin/runes-append.sh`, `config/eindri-dispatch.json` as "still to build" | all are present and `bash -n` clean |
| Plan §6 digest: 9 stages incl. `NETWORK CHECKS`, fleet digest from `data/backlog.md` | 8 sections; no NETWORK CHECKS; fleet digest reads `state/*.meta` + `docs/masterplan.md` |
| Plan §7 OpenCode session-start file `syn-sessionstart.js` | `saga-sessionstart.js` |
| Plan §7 Grok "project hooks (`grok --trust`)" | no `.grok/` exists in Ymir; Grok unimplemented |
| Plan §7 Codex "nudge-tier / bounded foreground checkpoint" | Codex is run-tier via `SessionStart` JSON + `PreToolUse` + `Stop` |
| Plan §7 Cursor "run interactive only (no headless turn-end)" | also implements `sessionStart` + `stop` hooks; headless still lacks the turn-end hook |
| `bin/einherjar-spawn.sh` calls `hamr-harness.sh crew` | `hamr-harness.sh` supports `eindri`/`eindri-model`/`eindri-effort`; `crew` silently falls through to `detect_own` |
| `bin/erindi-brief.sh` / `einherjar-spawn.sh` reference `.agents/sandbox/Dockerfile.utgard` and `utgard-runner:latest` | the Dockerfile and `sandcastle.config.json` exist; no image is guaranteed built, so `--isolation auto` reports `off` until it is |
| Plan §13 says `docs/supervision-protocols/` will be created | directory does not exist in Ymir |

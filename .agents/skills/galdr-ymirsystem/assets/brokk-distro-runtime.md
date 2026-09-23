# Brokk Distro Runtime — the definitive runtime spec

> Purpose: the maintainer's reference for how Ymir turns any verified harness into **Brokk** — home layout, the 8-stage Sága digest, Gleipnir, Sýn/Gná supervision, the Nornir cron spine, the Einherjar/Erindi/Vör worker model, restart semantics, and the production acceptance criteria.

Companion docs: `norse-naming.md` (the component law and map), `porting-upstream-to-norse.md` (how this runtime was ported from the validated upstream distro), `docs/plans/29-brokk-distro-runtime.md` (the plan).

## 1. What the Brokk distro is

A **distro** is not a model, harness, CLI, or app. It is a **directory of instructions, skills, tooling, policies, and state conventions that turns a general-purpose agent into a specialized one**. Launching a supported harness inside the clone *instantiates the primary agent and makes the user the operator*.

The upstream distro this was ported from states the mechanism at `README.md:36-41` of `$BROKK_UPSTREAM`:

> "Brokk is an agent distro for running a crew of agents. An agent distro is a portable directory of instructions, skills, tooling, policies, and state conventions that turns a general-purpose agent into a specialized one. There is no app to install: the cloned repo is the distro — `AGENTS.md`, bundled Brokk skills, and helper scripts that any terminal coding agent can follow. Launching a supported harness inside it instantiates your first mate — and makes you the Allfather."

Ymir adopts the identical shape, retargeted:

| Upstream role | Ymir role |
|---|---|
| Primary agent (first mate) | **Brokk** |
| Human operator (Allfather) | **Allfather** |
| Sub-agents (Eindri) | **Eindri** |
| Crew spawn (fm-spawn) | **Einherjar** (`bin/einherjar-spawn.sh`) |
| Worktree engine (Yggdrasil) | **Yggdrasil** (`<BROKK_HOME>/.yggdrasil/<id>`) |
| Isolated home variable (`FM_HOME`) | **`BROKK_HOME`** |

**Brokk = the primary.** Read-only over projects except under a concrete, approved operation. **Eindri = sub-agents.** One autonomous agent per task, isolated worktree, optional Utgard sandbox. **Allfather = the operator.** Talks only to Brokk; Eindri never address the Allfather.

## 2. Home layout — tracked vs private

`BROKK_HOME` selects an *instance's private* `data/`, `state/`, and `config/`, while scripts continue to come from the tracked code root (`BROKK_ROOT_OVERRIDE`, defaulting to the repo root). This is the upstream `FM_HOME` separation (`$BROKK_UPSTREAM/AGENTS.md:42-54`) mapped onto Ymir.

```text
BROKK_HOME = repo root ($YMIR_ROOT)  ── platform home
           = svartalfaheim/<realm>/         ── realm home (when provisioned)

tracked (shared, committed)            private (gitignored)
  AGENTS.md                              data/     durable context + briefs
  opencode.json                          state/    runtime records, lock, status
  bin/            runtime scripts        config/   local operating choices
  .agents/        skills, profiles       .yggdrasil/  ephemeral task worktrees
  .pi/ .opencode/ .claude/ .codex/ .cursor/   harness adapters
  docs/           plans, masterplan
```

Resolution order used by every script (all overridable):

| Variable | Default | Meaning |
|---|---|---|
| `BROKK_ROOT_OVERRIDE` | `dirname(bin)/..` | the tracked code root; scripts are read from here |
| `BROKK_HOME` | `BROKK_ROOT_OVERRIDE` | the private home that owns `data/ state/ config/` |
| `BROKK_DATA_OVERRIDE` | `$BROKK_HOME/data` | durable context + per-task briefs/reports |
| `BROKK_STATE_OVERRIDE` | `hoard_state_dir` (`$YMIR_STATE_DIR` → `$YMIR_HOME/state`) | lock, cron, metas, status logs, backups |
| `BROKK_CONFIG_OVERRIDE` | `$BROKK_HOME/config` | cron.yaml, eindri-harness, dispatch rules |

### 2.1 Tracked surface

| Path | Holds |
|---|---|
| `AGENTS.md` | The always-loaded contract: mandate, naming, laws, routing |
| `opencode.json` | `default_agent: "brokk"`, the `brokk` primary, subagent profiles, `skills.paths: [".agents/skills"]` |
| `bin/` | Every runtime script (Sága, Sýn, Gná, Gleipnir, Nornir, Einherjar, Erindi, Vör, Rödd, Runes, Hamr) |
| `.agents/` | Skills (`skills/`), Eindri profiles (`subagents/`), sandbox (`sandbox/Dockerfile.utgard`), tools, bus |
| `.pi/extensions/` | `syn-turnend-guard.ts` (Sýn), `gna-pi-watch.ts` (Gná), `lib/vordr-sessionstart-supervisor.mjs` (Vörðr), `lib/rodd-operational-input.ts` (Rödd) |
| `.opencode/plugins/` | `saga-sessionstart.js`, `syn-watch-arm.js`, `syn-turnend-guard.js`, `syn-pretool-check.js`, `syn-cd-check.js`, `lib/rodd-operational-input.js` |
| `.claude/settings.json` | `SessionStart` + `Stop` hooks (run-tier) |
| `.codex/hooks.json` | `SessionStart`, `PreToolUse`, `Stop` hooks (nudge-tier; payload via stdin) |
| `.cursor/hooks.json` | `sessionStart`, `stop`, `preToolUse` hooks (interactive only) |
| `docs/plans/`, `docs/masterplan.md` | Plans and the append-only order ledger |

### 2.2 Private surface (`.gitignore` at repo root)

`data/*` (except `*.example`), `state/*` (except `.gitkeep`), `config/*` (except `*.example`), `.yggdrasil/`, `svartalfaheim/*/.env.realm`, `.env.local`.

| Path | Holds | Notes |
|---|---|---|
| `data/operator.md` | Allfather preferences/working style | read at every session start; inspect-then-update |
| `data/projects.md` | realm-scoped project registry | one row per project |
| `data/learnings.md` | curated, dated, evidence-backed facts | prune often |
| `data/realm.md` | active realm name | `way-of` today |
| `data/backlog.md` | pointer to `docs/masterplan.md` open orders | never replaces the masterplan |
| `data/<id>/brief.md` | the Erindi brief handed to an Eindri | fixed `Delivery contract: mode=<mode>` line |
| `data/<id>/report.md` | a scout Eindri's deliverable | report only, no branch/PR |
| `state/.lock` | Gleipnir session lock (bare pid) | written by `bin/gleipnir-lock-lib.sh` |
| `state/<id>.meta` | task metadata (harness, model, worktree, backend…) | authoritative task record |
| `state/<id>.status` | append-only best-effort event log | last line = last event, not current state |
| `state/<id>.inbox/` | Brokk→Eindri steering message files | `mv NNN.msg handled/` is the ack |
| `state/cron.pid`, `state/cron.log` | Nornir scheduler loop + log | managed by `bin/nornir-cron-start.sh` |
| `state/.cron-fired/`, `state/.cron-locks/` | once-a-day date guards + per-job flock | chronological edge protection |
| `state/.wake-queue` | durable Sága wakes | drained, stay until acknowledged |
| `state/.supervision-armed`, `state/.watch.heartbeat` | Sýn arm marker + liveness | guard is inert until first arm; the watcher re-verifies the lock every poll and retires silently when the owner dies |
| `state/.lock-path` | resolved session-lock path | pointer the harness extensions read; written by `gleipnir_lock_acquire`. The lock is machine-local but the pointer lives in the synced home, so a pointer outside the current user's home is stale: both harness readers validate it and heal it (2026-09-23) |
| `state/backups/` | Muninn memory snapshots | written before any prune |
| `state/observer.log`, `state/observer.last` | Huginn observation output | read-only bridge |
| `workspace/memory/runes_audit.md` | Runes chained JSONL ledger | append-only, never rewritten |

## 3. The 8-stage Sága session-start digest

`bin/saga-session-start.sh` prints **one ordered digest** and does nothing else. It composes existing scripts; it never re-implements them. The section headers it emits are `== LOCK ==`, `== BOOTSTRAP ==`, `== WAKE QUEUE ==`, `== SUPERVISION ==`, `== UPDATE ==`, `== FLEET DIGEST ==`, `== CONTEXT DIGEST ==`, `== TODAY ==`, `== ASSET ROUTING ==`, `== TOOL SURFACE ==`, `== CRON START ==`, `== NEXT STEP ==`.

| # | Stage | What it emits | Source / helper |
|---|---|---|---|
| 1 | **LOCK** | `session lock held (pid N)` or `READ-ONLY: session lock held by pid N - no spawn, steer, merge, drain, or repair this session` | `bin/gleipnir-lock-lib.sh` → machine-global `brokk.lock` for the primary, per-home `state/.lock` for an Eindri-home |
| 2 | **BOOTSTRAP** | `tool floors OK` or `MISSING: …`; `realm env: present` or `realm env: ABSENT (svartalfaheim/<realm>/.env.realm)` | checks `git bash node`; checks `.env.realm` in `$BROKK_HOME` then `$ROOT` |
| 3 | **WAKE QUEUE** | `wake queue: N pending`, each `WAKE <record>`, `WAKE_ACK_REQUIRED`, `open decisions: N` | `bin/eindri-handoff.sh sweep` (the failsafe — sweeps undelivered reports/questions into the queue) **then** `bin/saga-wake-drain.sh` → `state/.wake-queue`, `state/*.decision` |
| 4 | **SUPERVISION** | one operating block: `harness next step: arm supervision via the installed harness adapter; never run bin/syn-watch-arm.sh by hand.` | Sýn/Gná per-harness protocols |
| 4b | **UPDATE** | `current — no newer Ymir on npm`, or the newer version with its remedy (`npm i -g @zerwiz/ymir`, then `ymir groa`) | `bin/ymir-update-check.sh` — one cached lookup a day; silent with no network; **exit 3** when a newer version stands |
| 5 | **FLEET DIGEST** | `task metadata records: N` (count of `state/*.meta`) and `open forge orders: N` (`grep -c '^- Status: ADDED' docs/masterplan.md`) | `state/*.meta`, `docs/masterplan.md` |
| 6 | **CONTEXT DIGEST** | `--- realm ---`, then `data/operator.md`, `data/projects.md`, `data/learnings.md`, each delimited; `ABSENT: <path>` when missing | **`$YMIR_HOME/hodd/data/`** via `bin/hoard-lib.sh` (`BROKK_DATA_OVERRIDE` wins) — never `$BROKK_HOME/data`, the code tree, which no operator record has ever occupied |
| 6b | **TODAY** | the day's work, appended blocks under each actor | `bin/daily-log.sh today` → `$YMIR_HOME/hodd/memory/daily/YYYY-MM-DD.md` |
| 7 | **CRON START** | `cron: running pid=N jobs=M` or `cron: started …` / `cron: no jobs configured …` | `bin/nornir-cron-start.sh` (idempotent) |
| 7b | **TOOL SURFACE** | the Allfather's own handles: `/edit <path>`, `bin/ymir-say.sh`, `bin/omarchy-plugins.sh`, `bin/herdr-run.sh` | inline |
| 8 | **NEXT STEP** | `Ascend Hlidskjalf as Brokk. Address the Allfather. Read once; act.` | closing pointer |

**Read-once contract.** The digest is this turn's startup and recovery input. Brokk must **not** re-read the context/backlog/status it just printed unless a source was reported `ABSENT` or corrupt.

### 3.1 The runner — source routing

`bin/saga-sessionstart-run.sh` decides, from the session-open source, whether the open needs the full digest, a context re-emit, or a short nudge. It exits 0 on every ordinary transport path: a failed session start must reach the agent as digest text it can act on, never as a refusal to open the session.

| Source | Behavior |
|---|---|
| `startup`, `new`, unknown | run the full `bin/saga-session-start.sh`; touch `state/.session-start-complete` |
| `clear`, `compact` | if complete: print `CONTEXT RE-EMIT (source=…)` and a reminder to re-read context only if needed; else run the full digest |
| `resume`, `reload`, `fork` | print the instruction `Run bash …/saga-session-start.sh exactly once now` |
| `--pi-prerequisite` and `BROKK_SESSIONSTART_INELIGIBLE=1` | intentional stand-down, exit 3 |

The source is passed with `--source` or parsed from a Claude/Codex-shaped JSON hook payload on stdin (`"source":"startup"` etc.).

Before routing, the runner raises the Mimirsbrunn well bridge
(`bin/mimir-bridge.sh --start`, idempotent) so `:4602` listens on **every** open —
the well extension's `session_start` probe finds it up even on a re-emit or nudge.

### 3.2 Harness adapter matrix

| Harness | Surface | Mechanism | Tier |
|---|---|---|---|
| OpenCode | `.opencode/plugins/saga-sessionstart.js` | `session.created` → run digest once per session id, inject via `client.session.promptAsync`; `syn-watch-arm.js` owns `session.idle` | nudge/run |
| Pi | `.pi/extensions/syn-turnend-guard.ts` | native session-open run; digest injected before the first turn; re-emit on compaction; refuse blind turn end | run |
| Claude Code | `.claude/settings.json` | `SessionStart` runs `saga-sessionstart-run.sh`; `Stop` runs `syn-turnend-guard.sh --claude` then async `syn-watch-arm.sh --restart` | run |
| Codex | `.codex/hooks.json` | `SessionStart` pipes the payload to `saga-sessionstart-run.sh`; `Stop` runs the guard; `PreToolUse` runs the Sýn seatbelts | nudge |
| Cursor | `.cursor/hooks.json` | `sessionStart` captures digest and returns `{additional_context}`; `stop` returns `{followup_message}` on guard exit 2; `preToolUse` runs seatbelts | interactive only |
| Grok / Kimi | not yet ported (see `.claude/settings.json` guards `${GROK_AGENT}`/`${GROK_HOOK_EVENT}` to avoid double-fire) | — | — |

`bin/hamr-harness.sh` (Hamr) detects the harness this process tree wears, in two layers: verified environment markers first (`CURSOR_AGENT=1`, `CURSOR_INVOKED_AS=cursor-agent`, `CLAUDECODE=1`, `PI_CODING_AGENT=true`, `GROK_AGENT=1`), then an 8-hop process-ancestry walk. It prints `claude|codex|opencode|pi|pi-signed|grok|kimi|cursor|unknown`. Subcommands: `eindri`, `eindri-model`, `eindri-effort` resolve the configured Eindri harness/model/effort from `config/eindri-harness` (format `<harness> [<model>] [<effort>]`; `default`/absent resolves to own).

Dispatch is **fail-closed**: `bin/einherjar-spawn.sh` refuses any harness outside the verified set `opencode pi pi-signed` unless a raw launch command (a `--harness` value containing whitespace) is supplied as the deliberate escape hatch.

## 4. Gleipnir — the per-home session lock

Gleipnir is the impossible chain that binds one live Brokk session per home so a second session cannot mutate shared state.

- **File:** `state/.lock` — a bare PID, read by the Pi extensions.
- **Library:** `bin/gleipnir-lock-lib.sh` (source-safe). Functions: `gleipnir_lock_acquire`, `gleipnir_lock_release`, `gleipnir_lock_owner`, `gleipnir_lock_owned`, `gleipnir_pid_alive`, `gleipnir_lock_path`, `gleipnir_state_dir`, `gleipnir_root`.
- **Critical invariant:** the lock must bind to the **live harness process**, not the short-lived digest helper. Harnesses pass `BROKK_SESSION_PID`; when it is absent, `gleipnir_session_pid` walks the ancestry (up to 8 levels) for the harness itself (`pi`, `opencode`, `claude`, `cursor`, `codex`, `grok`, `kimi`, `muse`, `hermes`) and binds to that — only a run with no harness ancestor falls back to `$$`.
- **Why the walk matters:** running `bin/saga-session-start.sh` **manually** leaves `BROKK_SESSION_PID` unset. Writing `$$` recorded the digest helper's pid, which is dead a second later — an orphan lock that reads as "no live session" and silently blocks supervision from arming. The ancestry walk is the fix; a helper's pid is never authoritative.
- `gleipnir_lock_owned` walks up to 8 ancestry levels so a helper can prove the session owns the lock.
- **Refused lock ⇒ read-only session.** No spawn, steer, merge, drain, or repair. The digest says so in stage 1.
- **One lock per machine (primary).** The primary's lock is machine-global — `${XDG_STATE_HOME:-$HOME/.local/state}/ymir/brokk.lock` (override `BROKK_MACHINE_STATE_DIR`) — so a second checkout of the same host is read-only and cannot masquerade as its own home. **Eindri-homes are exempt:** an Eindri-home holds its own `<home>/state/.lock` so workers run in parallel with the primary (and on remote hosts). `data/eindri-home` or `BROKK_HOME_KIND=eindri` marks a home as an Eindri-home. `gleipnir_lock_acquire` writes `state/.lock-path` (the resolved path) for the non-bash harness readers, and the extensions fall back to the legacy `state/.lock` for a session that started before this contract. **The pointer's state dir is the operator's hoard state** (`gleipnir_state_dir` resolves through `bin/hoard-lib.sh` for the primary, `<home>/state` for an Eindri-home), so writer and readers agree; a synced pointer naming another user's home (a box reinstalled under a new username) is rejected and healed rather than trusted.
- **Reclaim:** a lock whose pid is not alive is reclaimable; a live foreign pid is never overridden. The guard's `lockOwnership()` treats missing / other / pid 1 as non-owned.

## 5. Sýn / Gná — supervision model

Supervision is **event-driven and zero-token**: no polling by the model, no babysitting. It has three pieces.

| Piece | Figure | Owns | Files |
|---|---|---|---|
| Watcher cycle | **Sýn** | one arm cycle; prints `signal:`/`stale:`/`check:`/`heartbeat:` when the primary is needed, then exits | `bin/syn-watch-arm.sh` |
| Turn-boundary guard | **Sýn** | refuses a blind turn end when supervision is off | `bin/syn-turnend-guard.sh`, `.pi/extensions/syn-turnend-guard.ts`, `.opencode/plugins/syn-turnend-guard.js` |
| Continuity messenger | **Gná** | arms, re-arms, delivers actionable wakes to the Pi session | `.pi/extensions/gna-pi-watch.ts` |
| Digest child warden | **Vörðr** | supervises the Sága digest child so Pi can stream and cap its output | `.pi/extensions/lib/vordr-sessionstart-supervisor.mjs` |

Mechanics:

- `bin/syn-watch-arm.sh --restart` verifies a live lock owner **at arm and on every poll**, writes `state/.supervision-armed`, touches `state/.watch.heartbeat` each cycle, polls `BROKK_WATCH_POLL_SECONDS` (default 5), and exits on a `signal:`/`stale:`/`check:`/`heartbeat:` line. The per-cycle re-check retires an orphaned watcher silently (`watcher: retired - session lock is no longer held`, not actionable) once its home's lock owner dies, so a leftover checkout cannot keep `state/.supervision-armed` fresh for a dead session and silence the turn-end guard. The harness extension owns continuity and re-arms.
- `bin/syn-turnend-guard.sh` is **inert until the first successful arm** (it returns 0 unless `state/.supervision-armed` exists). When armed, if the heartbeat is missing or older than `BROKK_WATCH_HEARTBEAT_STALE_SECONDS` (default 60), it prints the recovery instruction and exits 2 so the adapter re-prompts.
- **Do not arm before the first successful arm** and **never run `bin/syn-watch-arm.sh` by hand** — the Pi/OpenCode extensions own continuity. The PreToolUse seatbelts exist so the extension can deny a bash command that violates an invariant: `bin/syn-arm-pretool-check.sh` blocks backgrounding/detaching the arm (a real `&` or nohup/setsid/disown; `&&` chaining and `bash -n` are allowed), and `bin/syn-guard-pretool-check.sh` blocks destructive shapes against the session lock, the supervision markers, the append-only Runes ledger, the guard/extension machinery itself, secrets, and the fleet-steering registries. They are best-effort guardrails, not a security boundary.
- **Calm presentation** and the **Pi supervision branch** were deliberately dropped from the port; they are deferred (see `porting-upstream-to-norse.md` §6).

## 6. Nornir — the cron spine

Nornir are the fates who govern time. `bin/nornir-cron-start.sh` keeps exactly **one** lightweight scheduler loop alive (idempotent), started by Sága stage 7 at every session start.

- **Schedule:** `config/cron.yaml`, one `HH:MM <command>` per line, `#` comments.
- **PID/log:** `state/cron.pid`, `state/cron.log` (rotates at `BROKK_CRON_LOG_MAX_BYTES`, default 1 MiB).
- **Once-a-day guard:** `state/.cron-fired/<key>` stores the date; the loop matches `HH:MM` once per day so a job cannot double-run in the same minute or across a loop restart.
- **No overlap:** each job runs under a per-job `flock` in `state/.cron-locks/`; a busy job is skipped with `cron skip (busy)`.
- **Environment:** every job inherits `BROKK_HOME`, `BROKK_STATE_OVERRIDE`, `BROKK_CONFIG_OVERRIDE`, `BROKK_ROOT_OVERRIDE`, `BROKK_REALM`; jobs run from `BROKK_HOME`.
- **Identity guard:** a live loop is a live pid whose `/proc/<pid>/cmdline` still contains `cron run:`, defeating pid reuse.
- **CLI:** `bin/nornir-cron-start.sh [--status|--stop]`; status prints `cron: running pid=N jobs=M` or `cron: stopped jobs=M`.

Current schedule (`config/cron.yaml`):

| Time | Command | Figure | Output |
|---|---|---|---|
| 07:00 | `bin/nornir-job-daily-briefing.sh` | Sága | `svartalfaheim/<realm>/workspace/memory/daily/YYYY-MM-DD.md` (deterministic, atomic re-run) |
| 06:00 | `bin/nornir-job-observer.sh` | Huginn | read-only, self-contained observation of the Ymir runtime; Runes + `state/observer.log`; `ABSENT` is never silence |
| 00:30 | `bin/nornir-job-memory-housekeeping.sh` | Muninn | snapshot memory trees to `state/backups/` **before** any prune; engine state reported, not faked |
| 00:00 | `bin/nornir-job-git-sync.sh` | Yggdrasil | `fetch` (safe, `--ff-only`) by default or opt-in `push`; never force, never discard unlanded work |

All jobs are **stateless spawns**: fresh process → inject directives → execute → write output → exit. Each carves a Runes line.

## 7. Einherjar / Erindi / Vör — the worker model

| Step | Figure | Script | Artifact |
|---|---|---|---|
| Write the errand | **Erindi** | `bin/erindi-brief.sh <id> <repo> --mode <…>` | `data/<id>/brief.md` |
| Gather + launch the worker | **Einherjar** | `bin/einherjar-spawn.sh <id> <project> --mode <…>` | Yggdrasil worktree + backend pane + `state/<id>.meta` |
| Read the worker's true state | **Vör** | `bin/vor-crew-state.sh <id>` | one line: `state: <…> · source: <backend|status-log|none> · <detail>` |

**Delivery contract.** A ship brief carries a fixed machine-readable line `Delivery contract: mode=<mode>`; `bin/einherjar-spawn.sh` refuses to launch a ship task whose explicit `--mode` disagrees, so an adjusted brief and the recorded task cannot drift. A scout brief carries `Delivery contract: mode=scout` and delivers `data/<id>/report.md` (no branch, no push, no PR).

**Modes** (ship): `direct-PR` (push `eindri/<id>`, open PR; never merge), `local-only` (work on `eindri/<id>`; Brokk merges local `main` after approval), `no-mistakes` (run the `no-mistakes` pipeline, open the PR it produces). Merge authority stays with the **Glitnir human gate** — Brokk never force-merges.

**Isolation.** Every worker runs in a Yggdrasil worktree at `<BROKK_HOME>/.yggdrasil/<id>`, created read-only-referencing the project. `--isolation on|off|auto` seals the worker in an Utgard container (`utgard-runner:latest`, `--network none --cpus 1.0 --memory 512m --security-opt no-new-privileges`), mounting the worktree at `/sandbox/workspace`, plus `state/` and `data/` at their host paths. `auto` selects Utgard only when the image is present and reports the decision. The brief's first instruction to the worker is to verify isolation with `pwd -P` and `git rev-parse --show-toplevel` before touching anything.

**Status protocol.** A worker appends one line `{state}: {one short line}` to `state/<id>.status`; states are `working, needs-decision, blocked, paused, done, failed` (`paused` is configurable via `BROKK_PAUSED_VERB`). Each append wakes Brokk, so reports are sparse. `Vör` reconciles the possibly-stale log against the authoritative backend endpoint recorded in the meta and never infers current state from `tail -1` alone.

**Steering inbox.** Brokk steers a live worker through durable messages in `state/<id>.inbox/NNN.msg`; the worker reads them in numeric order and acknowledges by `mv`-ing each into `state/<id>.inbox/handled/`. The move **is** the acknowledgement.

**Backends.** `tmux` (verified reference) or `herdr` (Þjazi protocol 14+). `config/backend` / `BROKK_BACKEND` / `TMUX` / `HERDR_ENV=1` select it. Spawn prints one line: `spawned <id> harness=<h> kind=<ship|scout> [mode=<m> yolo=<y>] backend=<b> target=<t> worktree=<wt> isolation=<on|off>`.

**Dispatch profiles.** `config/eindri-dispatch.json` holds natural-language rules choosing a per-task harness/model/effort. When it is active, `bin/einherjar-spawn.sh` requires an explicit `--harness` resolved from those rules (consultation backstop, so profiles are never silently skipped). Verified models/effort: `opencode` is primary, `pi` is the verified secondary; effort values are `low|medium|high|xhigh|max`.

## 8. Context sources

At stage 6 the digest injects, each delimited with an explicit `ABSENT` marker:

| Source | Purpose | Absent means |
|---|---|---|
| `data/realm.md` | active realm | digest defaults realm to `wayof` (when the tenant is seated) |
| `data/operator.md` | Allfather voice, working style, standing rules | use built-in defaults |
| `data/projects.md` | realm project registry | rebuild from realm `projects/` |
| `data/learnings.md` | curated operational facts | no curated facts yet |
| `svartalfaheim/<realm>/HOOD.md` | the holdings map (private hoard + realm seat) | `hood` printed ABSENT; seat not carved yet |
| `docs/masterplan.md` | open forge orders (counted, not dumped) | `open forge orders` omitted |

Absence is meaningful: **an absent file is never confused with an empty-but-present one.** The fleet digest additionally reads `state/*.meta` and the bounded `state/*.status` tail; the wake drain reads `state/.wake-queue` and `state/*.decision`.

## 9. Runes and Rödd

- **Runes** (`bin/runes-append.sh`): append-only chained JSONL under `workspace/memory/runes_audit.md`. Each entry folds the previous checksum into its own (`"prev"` field), so a line cannot be altered or removed without breaking every later line. CLI/library: `runes-append.sh <actor> <event> [--order Wxxxx] [--realm R] --message "…"`; exit 0 appended, 1 IO error, 2 usage. Locked with `flock` on `state/runes.lock` so concurrent writers cannot fork the chain. **Never rewrites, never truncates.**
- **Rödd** (`bin/rodd-operational-input.sh`): the structured wire between the primary and workers. Form `U+2063 RODD_OP: v1 <kind>: <body>`; kinds `session-start watcher turn-end-guard away-supervisor launch-brief branch-outcome` plus the `from-brokk` carrier. CLI `encode|kind|classify|body`; the `.pi` and `.opencode` adapters call it rather than re-parsing the wire. This file is the **single owner** of the protocol; callers must never re-parse it.

## 10. Restart semantics

Restart is a non-event: **durable `data/` + `state/` + live backend inventory are authoritative.** No memory is carried in-process.

| On restart | Behavior |
|---|---|
| A new harness opens | Sága runs; Gleipnir reclaims a dead-pid lock; stages re-emit |
| Session process replaced (`/new`, `/resume`, `/fork`, reload) | Pi binds a new live generation so monitoring re-arms without restarting Pi; stale callbacks no-op |
| Cron loop died / host rebooted | Sága stage 7 restarts it; `state/.cron-fired` date guards prevent a double-run that day |
| Worker pane gone | `Vör` reports `unknown/none` with `backend target gone`; the meta/worktree persist |
| Supervision was armed and the watcher is stale | Turn-end guard exits 2 and re-prompts; recovery is to re-arm via the extension |
| Digest already taken this lock (`clear`/`compact`) | runner emits the context re-emit rather than re-running the full digest |

## 11. Environment reference

| Variable | Used by | Default / meaning |
|---|---|---|
| `BROKK_HOME` | all | private home; defaults to `BROKK_ROOT_OVERRIDE` |
| `BROKK_ROOT_OVERRIDE` | all | tracked code root |
| `BROKK_DATA_OVERRIDE` | Sága, Erindi, Einherjar, jobs | `$BROKK_HOME/data` |
| `BROKK_STATE_OVERRIDE` | all | `hoard_state_dir` (`$YMIR_STATE_DIR` → `$YMIR_HOME/state`) |
| `BROKK_CONFIG_OVERRIDE` | Hamr, Nornir, Einherjar | `$BROKK_HOME/config` |
| `BROKK_SESSION_PID` | Gleipnir, adapters | live harness pid bound into `state/.lock` |
| `BROKK_REALM` | Sága, jobs | realm; else `data/realm.md`; else `way-of` |
| `BROKK_PROC_ROOT_OVERRIDE` | Hamr | `/proc` override (tests) |
| `BROKK_PI_HARNESS` | Hamr | `pi-signed` distinguishes signed Pi |
| `BROKK_SESSIONSTART_INELIGIBLE` | runner | `1` ⇒ Pi prerequisite stand-down (exit 3) |
| `BROKK_BACKEND` | Einherjar | `tmux`/`herdr`; else `config/backend`, `TMUX`, `HERDR_ENV` |
| `BROKK_TMUX_SESSION` | Einherjar | tmux session name (default `brokk`) |
| `BROKK_PAUSED_VERB` | Erindi, Vör | status verb for deliberate idling (default `paused`) |
| `BROKK_WATCH_POLL_SECONDS` | Sýn | watcher poll interval (default 5) |
| `BROKK_WATCH_HEARTBEAT_STALE_SECONDS` | Sýn | staleness threshold (default 60) |
| `BROKK_WATCH_PREDECESSOR_ARM_PID` | Sýn/Gná | watch generation identity |
| `BROKK_WATCH_ARM_SCRIPT` | Gná | arm script path override |
| `BROKK_PI_ARM_READY_TIMEOUT_MS`, `BROKK_OPENCODE_ARM_READY_TIMEOUT_MS` | adapters | arm readiness timeout |
| `BROKK_WATCH_ARM_RETIRE_TIMEOUT_MS`, `BROKK_WATCH_REARM_RETRY_{BASE,MAX}_MS`, `BROKK_WATCH_REARM_RETRY_LIMIT` | OpenCode Sýn | re-arm retry tuning |
| `BROKK_CRON_LOG_MAX_BYTES` | Nornir | log rotation (default 1048576) |
| `BROKK_RUNES_FILE` / `_DIR` / `_LOCK` | Runes | ledger/lock overrides |
| `BROKK_BRIEF_DIR`, `_MAX_ORDERS`, `_MAX_RUNES` | Sága briefing | output dir and bounds |
| `BROKK_GIT_SYNC_MODE` / `_REMOTE` / `_TARGETS` | Yggdrasil job | `fetch`/`push`, remote, repo list |
| `BROKK_BACKUP_DIR`, `BROKK_MEMORY_ROOTS`, `BROKK_MIMIR_DB`, `BROKK_MEMORY_PRUNE`, `BROKK_MEMORY_PRUNE_DAYS` | Muninn | backup and prune controls |
| `BROKK_YGGDRASIL_ROOT` | Huginn | external, read-only worktree root (`~/.Yggdrasil`) |
| `VORDR_SESSIONSTART_SUPERVISOR_PID` | Vörðr | supervisor identity passed to the child |

## 12. Production acceptance criteria

From plan 29 §8, restated as the runtime's testable contract:

1. Launching a verified harness in `BROKK_HOME` makes the agent respond **as Brokk** and address the operator as **Allfather**, before any tool call.
2. The digest is injected **before the model's first turn** on a run-tier harness, and a nudge appears on a nudge-tier harness.
3. The digest contains all eight stages; a truncated startup names exactly which stage never ran.
4. Context sources appear delimited, with explicit `ABSENT` markers.
5. **Cron jobs are running after session start**; `bin/nornir-cron-start.sh` is idempotent and reports why if it fails.
6. A lock-refused session is read-only: no spawn, steer, merge, drain, or repair.
7. Brokk can spawn an Eindri through `bin/einherjar-spawn.sh` into a Yggdrasil worktree sealed by Utgard, supervise it, and deliver a PR/local merge through the Glitnir human gate.
8. Restart is a non-event: durable `data/` + `state/` + live backend inventory are authoritative.
9. No platform backend order was started before the frontend gate (plan 29 §4) went green.

Additional runtime invariants that must hold:

- Every script is `bash -n` clean and smoke-tested; every failure reports a plain reason, never a silent fallback.
- The lock binds to the live session pid via `BROKK_SESSION_PID`.
- The turn-end guard is inert until the first successful arm writes `state/.supervision-armed`.
- `rodd-operational-input.sh` is the single owner of the wire; callers never re-parse it.
- `runes-append.sh` never rewrites or truncates; the chain stays unbroken.
- A scout spawn never carries `--mode`; a relaunch re-derives kind/mode from `state/<id>.meta`.
- Dispatch on an unverified adapter is fail-closed.
- **No mocks, no examples, no placeholders** in the shipped runtime.

## 13. Operations cheat-sheet

```bash
# Seat Brokk (once per session; the harness usually injects this already)
bash bin/saga-session-start.sh

# Route/emit a digest for a specific open source
bash bin/saga-sessionstart-run.sh --source compact

# Harness detection
bash bin/hamr-harness.sh                 # own harness
bash bin/hamr-harness.sh eindri          # configured Eindri harness
bash bin/hamr-harness.sh eindri-model    # optional model token

# Cron spine
bash bin/nornir-cron-start.sh --status
bash bin/nornir-cron-start.sh
bash bin/nornir-cron-start.sh --stop

# Worker lifecycle
bash bin/erindi-brief.sh T42 my-repo --mode direct-PR
# edit data/T42/brief.md, replace {TASK}
bash bin/einherjar-spawn.sh T42 projects/my-repo --mode direct-PR --isolation auto
bash bin/vor-crew-state.sh T42

# Audit
bash bin/runes-append.sh brokk order.completed --order W0031 --realm way-of --message "…"
```

## Maintaining this

- **Owner:** Brokk. **Sources of truth:** the script headers under `bin/` (exact interfaces), `docs/plans/29-brokk-distro-runtime.md` (the plan), `AGENTS.md:6` (the mandate).
- **When a script's interface changes, update this doc in the same change.** The header is the interface; this doc is the map.
- **When the digest gains or loses a stage**, update §3 and the acceptance criteria count in §12, and reconcile plan 29 §6 (which lists a 9th `NETWORK CHECKS` stage not yet implemented).
- **When a new Nornir job ships**, add a row to §6 and to `config/cron.yaml`.
- **Verification loop:** `for f in bin/*.sh; do bash -n "$f" || echo "FAIL $f"; done` for syntax; `jq . config/eindri-dispatch.json` and `jq .` on each adapter JSON for parse; then a live session start to confirm stage 7 reports the cron running.
- **Cross-check:** `norse-naming.md` §3.2 must list exactly the runtime figures this doc describes.

**rename sweep (2026-09-12).** The `galdr` -> `galdr-ymirsystem` rename corrected a stale compliance path inside `bin/saga-session-start.sh`; behaviour unchanged.

### The rename sweep broke governed paths, not just prose (2026-09-12)

`bin/saga-session-start.sh` prints the governed-path map, and it carried
`smidja-factory-factory` — a rename artifact. The same wrong token sat in
`AGENTS.md`'s `governed[]` table and in the pretool guard's own `asset_for`
pattern, so the smidja rule stopped matching and protected nothing, silently.

Corrected here and in six other files. A `governed` check now resolves every
path in the table (`compliance-check.sh`), because a governed path that does not
exist fails open — the worst shape a guard can fail in.

### The realm default is `wayof` (2026-09-12)

`bin/saga-session-start.sh` derived the realm from `data/realm.md` and then fell
back to `way-of` — a retired multi-tenant name. It now falls back to `wayof`, the
company container this platform actually has, so the digest reads
`svartalfaheim/wayof/.env.realm` for the realm's environment rather than a
directory that no longer exists.

The digest reports the realm env as either present or `ABSENT`; it never prints
the values. Where those values come from and how to set them:
`svartalfaheim/wayof/SECRETS.md`.

## Where the runtime looks (after migration 0004)

The home is split in two, and every resolver follows it:

```
$YMIR_HOME/
├── hodd/            secrets · identity · docs · data · memory (the ledger) · AGENTS.md
└── svartalfaheim/   <realm>/{workspace/{personal,company/…},memory,runs}
```

- `bin/hoard-lib.sh` → `hoard_root` = `$YMIR_HOARD`, else `$YMIR_HOME/hodd`.
- `bin/realm-lib.sh` → root `$YMIR_HOME`; the realm marker is read from
  `hodd/data/realm.md`, and the realms live under `svartalfaheim/`.
- **One resolver, every script** — `ymir_home_root` (env → the recorded choice in
  `~/.config/ymir/home` → the ONE documented default). A script must **not** carry
  its own default path: a literal `$HOME/Documents/…` both drifts from the recorded
  home and, in `bin/smidja-board.sh`'s case, *won over* the resolver because it set
  `YMIR_HOME` before the call, pinning the machine to a dead path. `bin/runes-append.sh`
  (the ledger), `bin/ymir-validate.sh`, `bin/smidja-bootstrap.sh`, `bin/ymir-style.sh`,
  `bin/saga-session-start.sh`, `bin/mimir-bridge.py`, `bin/bootstrap-macos.sh` and
  `.agents/skills/lifecycle/smoke_test.sh` now resolve through the lib (2026-09-20).
- `bin/gjallarhorn-expose.sh` — the tunnel **domain and suffix are the operator's**,
  read from `$YMIR_HOME/config/tunnel.env` (env wins); the public tree carries no
  operator domain as a default.
- The Sága digest reads the realm env and the realm's HOOD file from
  `$YMIR_HOME/svartalfaheim/<realm>/`, never from the checkout.
- The daily briefing writes into the realm's `workspace/memory/daily/`; memory
  housekeeping walks `.agents/memory`, the hoard's `memory`, and the realm's.

Why it matters: an installed runtime (npm) may live in a read-only package
directory, so **nothing private or writable may be resolved relative to the
scripts**. Both resolvers are home-based for exactly that reason.

# Nornir Jobs — the scheduled-jobs and Runes-ledger reference

Purpose: the complete reference for Ymir's **Nornir** scheduler (the fates who govern time),
each scheduled job, the append-only **Runes** ledger, and the read-only observer law.

> Jobs are declared in `config/cron.yaml`, started idempotently at every session start by
> `bin/nornir-cron-start.sh`, and run statelessly: start → read inputs → write outputs →
> carve a Rune → exit. A job never owns mutable source trees.
>
> Nornir is a Ymir extension. Upstream Brokk has only a watcher
> (`bin/fm-watch-arm.sh`); plan 29 §6 explicitly adds the scheduled spine on top of it.

---

## 1. The scheduler — `bin/nornir-cron-start.sh`

### 1.1 Interface

```
nornir-cron-start.sh            # start if stopped (idempotent); report otherwise
nornir-cron-start.sh --status   # cron: running pid=<pid> jobs=<n> | cron: stopped jobs=<n>
nornir-cron-start.sh --stop     # stop the loop, remove state/cron.pid
```

- Exactly **one** lightweight scheduler loop is kept alive, tracked by `state/cron.pid`.
- **Session-scoped retirement (2026-09-23).** Nornir is started BY a session
  (`saga-session-start.sh`), never before one, so the loop retires the moment
  that session is gone: each cycle it reads the machine's session lock
  (`$BROKK_MACHINE_STATE_DIR/brokk.lock`, default `${XDG_STATE_HOME:-$HOME/.local/state}/ymir/brokk.lock`)
  and exits — logging `cron retired - no live session lock` — when the lock is
  absent or its holder is dead or a zombie. This ends the **8-orphan-loop leak**
  left by ended seats; a seat never leaves its scheduler behind. `--stop` still
  stops a loop by hand.
- Liveness is verified by PID **and** the command line carrying the identity mark
  `cron run:` (`/proc/<pid>/cmdline`), so PID reuse after reboot cannot fake a running loop.
- Log rotation: `state/cron.log` rotates to `state/cron.log.1` above
  `BROKK_CRON_LOG_MAX_BYTES` (default 1 MiB).
- No jobs configured → `cron: no jobs configured (...)` and exit 0.

### 1.2 State files

| Path | Purpose |
|---|---|
| `state/cron.pid` | PID of the live scheduler loop. |
| `state/cron.log` | Timestamped run/skip/last-output log (rotated to `cron.log.1`). |
| `state/.cron-fired/<job-key>` | Once-per-day date guard; holds `YYYY-MM-DD`. |
| `state/.cron-locks/<job-key>.lock` | Per-job `flock` so a slow job never overlaps itself. |

`<job-key>` is the command string with every character outside `[A-Za-z0-9._-]` replaced by
`_` (`bin/nornir-cron-start.sh:88`).

### 1.3 Loop mechanics (`bin/nornir-cron-start.sh:69-106`)

1. Every 45 seconds, compute `now=HH:MM` and `today=YYYY-MM-DD`.
2. For each non-comment line: split `at=${line%% *}` / `cmd=${line#* }`.
3. Skip unless `at == now`.
4. Skip if the date guard stamp already equals `today`.
5. Write the stamp **before** dispatch, then log `cron run: <cmd>`.
6. Run under `flock -n`; if busy, log `cron skip (busy)`.
7. Run from `$BROKK_HOME` via `bash -lc "$cmd"`, output appended to `state/cron.log`.
8. Export `BROKK_HOME`, `BROKK_STATE_OVERRIDE`, `BROKK_CONFIG_OVERRIDE`,
   `BROKK_ROOT_OVERRIDE`, and `BROKK_REALM` to every job.

Because the stamp is written before the run, a job that crashes mid-run does **not** retry the
same day. That is deliberate: cron is idempotent-by-date, not retrying-by-failure.

### 1.4 Environment (`bin/nornir-cron-start.sh:18-20`)

| Variable | Default | Effect |
|---|---|---|
| `BROKK_ROOT_OVERRIDE` | script's parent | Root when `BROKK_HOME` unset. |
| `BROKK_HOME` | `$ROOT` | Home owning the jobs and state. |
| `BROKK_STATE_OVERRIDE` | `$YMIR_STATE_DIR` (`<home>/state`, via `bin/hoard-lib.sh`) | Scheduler state directory — in the home the operator chose, never in the code tree. |
| `BROKK_CONFIG_OVERRIDE` | — (see §2) | Where `cron.yaml` lives — an explicit override always wins. |
| `BROKK_CRON_LOG_MAX_BYTES` | `1048576` | Rotation threshold. |
| `BROKK_REALM` | `""` | Realm exported to jobs (jobs also fall back to `data/realm.md`). |

---

## 2. The schedule is the user's — `$YMIR_HOME/config/cron.yaml`

**The tracked tree ships a template, never the live job list.** The scheduler
resolves the schedule in this order:

1. `BROKK_CONFIG_OVERRIDE` (explicit, unmistakeable);
2. the **home's own** `$YMIR_HOME/config/cron.yaml` — where an operator edits
   their real jobs (`$YMIR_HOME` resolves through `bin/hoard-lib.sh`, the one
   answer the whole runtime shares);
3. the repo's `config/cron.yaml.example` — a template a fresh install copies,
   **never** a live schedule. A tracked `config/cron.yaml` is not consulted.

To take charge of your schedule:

```bash
cp ~/ymir/config/cron.yaml.example ~/Documents/Ymir/config/cron.yaml
# edit ~/Documents/Ymir/config/cron.yaml, then:
bin/nornir-cron-start.sh --status   # jobs=<n> from YOUR schedule
bin/nornir-cron-start.sh            # resolve + start (idempotent)
```

### The format

```
# Nornir cron schedule — the user's own jobs
# Format: HH:MM <command>. Started idempotently by bin/nornir-cron-start.sh.
07:00 bin/nornir-job-daily-briefing.sh
06:00 bin/nornir-job-observer.sh
00:30 bin/nornir-job-memory-housekeeping.sh
00:00 bin/nornir-job-git-sync.sh
05:30 bin/nornir-job-bragi-scrape.sh
```

- One job per line: `HH:MM <command>` (24-hour, zero-padded).
- Blank lines and lines starting with `#` are ignored.
- Commands are run with `bash -lc` from `$BROKK_HOME`, so relative `bin/...` paths resolve.
- The example template lives at `config/cron.yaml.example` in the tracked tree;
  an operator's real schedule is private in their home (`$YMIR_HOME/config/`).

---

## 3. The jobs

### 3.0 Bragi — the scrape round (`bin/nornir-job-bragi-scrape.sh`, 05:30)

- **Reads**: the operator's source list — `$YMIR_HOME/config/scrape-sources.yaml`
  (beside `agents.yaml` and `cron.yaml`, NOT under `hodd/config/`, which does not
  exist). Each entry: `name`, `url`, `kind` (scrape | search), `note`.
- **Writes**: one markdown file per source, `YYYY-MM-DD-<name>.md`, into
  `$YMIR_HOME/hodd/workspaces/marketing/scraped/`, plus a Rune
  (`bragi / scrape.round`).
- **The engine is Firecrawl, and it may be SELF-HOSTED.** A self-hosted engine
  needs a **URL**, not a key: `FIRECRAWL_API_URL` (env → the home's local env →
  the documented default `http://localhost:3002`). The fleet runs it on its own
  iron (heimdall and whynot), keyless (`USE_DB_AUTHENTICATION=false`). A cloud
  `FIRECRAWL_API_KEY` is still honoured, but it is no longer the only road.
- **No SDK.** The job calls the REST API with `curl` (`POST /v2/scrape` for a
  URL, `POST /v2/search` for a query — a query sent to `/scrape` is rejected
  with *Invalid URL*), so `firecrawl-py` is not a dependency.
- **Honest failure:** with no engine reachable it says so and scrapes nothing —
  it never invents a page.

### 3.1 Sága — daily briefing (`bin/nornir-job-daily-briefing.sh`, 07:00)

Deterministic, **no model call**. Reads four grounded inputs and writes one file.

| Reads | Writes |
|---|---|
| `docs/masterplan.md` (open forge orders + Active Queue) | `$YMIR_HOME/svartalfaheim/<realm>/workspace/memory/daily/YYYY-MM-DD.md` (atomic `mv`) |
| `state/` (cron status, `.lock`, `*.meta`, `*.status`) | Rune `nornir / briefing.written` |
| `docs/plans/*.md` (active plan status) | |
| `$YMIR_HOME/hodd/memory/runes_audit.md` (today's tail) | |

- Realm resolution: `BROKK_REALM` → first line of `data/realm.md` → `way-of`.
- Safe to re-run within a day: the file is rebuilt atomically from the same inputs.
- Bounds: `BROKK_BRIEF_MAX_ORDERS` (default 15), `BROKK_BRIEF_MAX_RUNES` (default 12).
- `docs/masterplan.md` status parsing strips the trailing period (`[.[:space:]]`), so
  `- Status: ADDED.` is counted as `ADDED`.
- Output override: `BROKK_BRIEF_DIR`.

```bash
BROKK_REALM=way-of bin/nornir-job-daily-briefing.sh
```

### 3.2 Huginn — observer (`bin/nornir-job-observer.sh`, 06:00)

The raven of observation. Read-only, and **self-contained**: every source lives inside Ymir
(the only external read is the worktree root).

| Source | Signals read |
|---|---|
| `docs/masterplan.md` | open / working forge orders |
| `.agents/agents/*.md` | the agent roster |
| `.agents/memory/well/` | the well (episodes) |
| `$YMIR_HOME/hodd/memory/runes_audit.md` | the ledger — it lives with the hoard, never beside the scripts |
| `apps/smidja/smidja_data/smidja.db` (or `$YMIR_HOME/smidja/smidja.db`) | Smíðja runs (read-only SQLite URI) |
| `~/.treehouse` | worktree dirs + `treehouse-state.json` |

- Writes `state/observer.log` (timestamped lines), `state/observer.last`, and one Rune per
  observation (`huginn / observer.<source>`).
- An absent source carves an explicit `ABSENT` line — silence is never mistaken for health.
- SQLite is opened `file:<db>?mode=ro` with a 3s timeout; the observer never mutates it.
- Overrides: `BROKK_YGGDRASIL_ROOT`.

### 3.3 Muninn — memory housekeeping (`bin/nornir-job-memory-housekeeping.sh`, 00:30)

The raven of memory. Reports, snapshots, then (only if enabled) prunes.

1. Report the engram/vector store state; if no engine is wired, say so — never fake decay.
2. **Backup first**: `state/backups/memory-YYYY-MM-DD.tar.gz` (atomic `mv` from `.tmp.$$`),
   archiving home-relative paths so a restore is home-relative.
3. Prune **only** when `BROKK_MEMORY_PRUNE=1` **and** the backup succeeded; only ephemeral
   `state/` temp files older than `BROKK_MEMORY_PRUNE_DAYS` (default 7).
4. Rune `muninn / memory.housekeeping`.

Safety law: never destructive without a backup; if the backup cannot be written, nothing is
removed and the failure is reported plainly.

| Variable | Default |
|---|---|
| `BROKK_BACKUP_DIR` | `$BROKK_HOME/state/backups` |
| `BROKK_MEMORY_ROOTS` | `.agents/memory:workspace/memory:svartalfaheim/<realm>/workspace/memory` |
| `BROKK_MIMIR_DB` | `.agents/memory/mimirsbrunn.db` |
| `BROKK_MEMORY_PRUNE` | `0` (disabled) |
| `BROKK_MEMORY_PRUNE_DAYS` | `7` |

### 3.5 Óðrerir — Live Hall snapshot (`bin/nornir-job-hall-snapshot.sh`, 08:00)

The Live Hall is a glass: it reads `apps/odrerir/public/livehall.json`
(same-origin, `cache: no-store`). This job writes that snapshot from real state
via `bin/hall-snapshot.sh` — runes, the project registry, the cron gauge, the
wake queue, standing smiths, armed `when-` sources, and the landed errands —
then carves Rune `odrerir / hall.snapshot`. Scheduled at 08:00 so it follows
the 06:00 observer and the 07:00 briefing: the morning board carries the day's
fresh runes.

| Reads | Writes |
|---|---|
| runes ledger · `hodd/identity/projects.yaml` · `config/cron.yaml` · `state/.wake-queue` · herdr agent list · armed when-sources · `state/eindri-reports/archive/` | `apps/odrerir/public/livehall.json` (gitignored runtime) · Rune `odrerir / hall.snapshot` |

- The snapshot is **runtime, never repo**: `apps/odrerir/public/livehall.json`
  is gitignored, so the job never dirties a branch.
- Absent `livehall.json` on the Hall is *not* a build failure — the page paints
  the saga's own count and says so. This job is what makes the board true.
- Idempotent by nature: each run rewrites the same snapshot from the same
  inputs; the cron date-guard suppresses repeat dispatch within a day.

### 3.6 Tyr — NSR compliance round (`bin/nornir-job-nsr-compliance.sh`, 02:30)

The NorthStar deterministic gate, run nightly in the quiet hours so sunrise
finds the doors mended or the Rune already says which broke. Runs every
`.compliance/gates/check_*.sh` (danger · env · paths · platform · wiring)
and carves one Rune with the verdict — `nornir / nsr.compliance` on a clean
round, `nornir / nsr.compliance.failed` (exit 1) naming the failed gates.

| Reads | Writes |
|---|---|
| `.compliance/gates/check_*.sh` (deterministic, no network) | Rune `nornir / nsr.compliance[.failed]` · `state/last` line |

- The morning briefing reads the ledger, so a FAIL is seen at 07:00, not
  found by accident.

### 3.7 Forgejo — the local git round (`bin/nornir-job-forgejo-git.sh`, 02:45)

The issue-to-PR loop, read each night: lists the local forge's open issues and
carves one Rune with the tally, so a growing queue (or a dead tunnel) is seen
at sunrise. The forge address is the user's, from the home — never the tree:
`$YMIR_HOME/config/forge.env` (`FORGEJO_URL`, optional `FORGEJO_TOKEN`).

| Reads | Writes |
|---|---|
| `$YMIR_HOME/config/forge.env` · `GET {forge}/api/v1/repos/issues/search?state=open` | digest `$_HOME/memory/daily/forgejo-YYYY-MM-DD.md` · Rune `forgejo / git.issues` |

- No `FORGEJO_URL` configured → clean exit (the loop is not armed); a closed
  door (tunnel down) → exit 1 and Rune `forgejo / git.door-down`.
- The forge may be the server's (`forgejo.zerwiz.org` → :3030) or a locally
  provisioned one (`bin/ymir-marketing-stack.sh --with-forgejo`).

### 3.8 The marketing stack (`bin/ymir-marketing-stack.sh`)

Not a cron job — a **provisioner**: stands Mautic + Postiz + Activepieces
(+ optional Forgejo) on ANY computer, the same OSS engines the server runs.
Env-driven (ports virtualized), secrets generated once into the home, never
inline. Agents (Bragi for marketing, Sindri for git) run it for any user.

```
bin/ymir-marketing-stack.sh up|status|down|doors
# doors: Mautic :8001 · Postiz :8003 · Activepieces :8005 · Forgejo :8007 (defaults)
```

- Rune `marketing / stack.<action>` carved on each provision action.
- The Allfather's live stack is the server's (`zerwizserver`); its public
  doors are tunnel-driven (`cloudflared`) — see the registry's
  `marketing_doors[]` table.
- Idempotent: gates are pure checks; the cron date-guard suppresses repeat
  dispatch within a day; safe to invoke by hand (`bash bin/nornir-job-nsr-compliance.sh`).

### 3.4 Yggdrasil — git sync (`bin/nornir-job-git-sync.sh`, 00:00)

The world-tree kept in order. Two modes, both non-destructive:

| Mode | Behavior |
|---|---|
| `fetch` (default, safe) | `fetch --prune`, then `merge --ff-only` only. No upstream → fetched, no merge. Diverged → refused, left untouched. |
| `push` (opt-in) | Commit a dirty tree (never stash/discard), then `push` (never force). |

- Target discovery: `BROKK_GIT_SYNC_TARGETS` (colon-separated) or auto-discovery of
  `$BROKK_HOME`, `workspace/`, `midgard/`, each `svartalfaheim/*`, its `workspace/`, and
  `projects/*`.
- Laws: never `--force`, never `reset`, never `checkout`, never `clean`; a non-repo, no-remote,
  or diverged target is reported and skipped.
- Prints a summary `targets=<n> ok=<n> skipped=<n> failed=<n> mode=<m>` and carves one Rune
  `yggdrasil / git.sync` (plus per-target Runes on skip/failure).

| Variable | Default |
|---|---|
| `BROKK_GIT_SYNC_MODE` | `fetch` |
| `BROKK_GIT_SYNC_REMOTE` | `origin` |
| `BROKK_GIT_SYNC_TARGETS` | auto-discover |

> In this checkout, `git-sync` reports `no git targets found under $YMIR_ROOT` because
> the platform root is not itself a git repository. That is a correct, reported outcome.

---

## 4. Runes — the append-only audit ledger

`bin/runes-append.sh` is both a CLI and a **source-safe shell library**. It never rewrites or
truncates existing entries.

### 4.1 Ledger

- Default: `workspace/memory/runes_audit.md` — JSONL lines appended under a Markdown head.
- Each entry chains to the previous by folding the previous `checksum` into its own:
  `checksum = sha256(prev + "\n" + base)`, where `base` contains `timestamp, actor, order,
  realm, event, message, prev`. Altering or removing a line breaks every later line.
- Append is done under **one** exclusive `flock` (`state/runes.lock`) so concurrent writers
  can never fork the chain.

### 4.2 CLI

```
runes-append.sh <actor> <event> [--order Wxxxx] [--realm R] --message "..."
```

Prints:

```
runes: appended actor=<actor> event=<event> order=<order|none> checksum=<hex>
```

### 4.3 Library

```bash
. bin/runes-append.sh
runes_append "nornir" "briefing.written" --realm way-of --message "daily briefing written"
# RUNES_LAST_CHECKSUM holds the new checksum
```

### 4.4 Environment

| Variable | Default | Effect |
|---|---|---|
| `BROKK_HOME` | repo root | Home owning the ledger. |
| `BROKK_RUNES_FILE` | `${BROKK_RUNES_DIR:-$BROKK_HOME/workspace/memory}/runes_audit.md` | Explicit ledger path. |
| `BROKK_RUNES_DIR` | `$BROKK_HOME/workspace/memory` | Ledger directory. |
| `BROKK_RUNES_LOCK` | `$BROKK_HOME/state/runes.lock` | Append lock. |

### 4.5 Entry shape

```json
{"timestamp":"2026-09-11T13:47:00Z","actor":"yggdrasil","order":"","realm":"way-of","event":"git.sync","message":"no git targets found under $YMIR_ROOT (mode=fetch)","prev":"","checksum":"3fe78c…"}
```

Every significant runtime action is carved: job runs, spawns, observer observations, git sync,
memory housekeeping, briefings. The canonical stub `.agents/memory/runes_audit.md` carries only
the Markdown head; the live ledger is `workspace/memory/runes_audit.md`.

### 4.6 Verify the chain

```bash
# Recompute the chain from the ledger and compare.
python3 - <<'PY'
import json, re, hashlib
lines = [l for l in open("workspace/memory/runes_audit.md") if l.startswith("{")]
prev = ""
for l in lines:
    e = json.loads(l)
    base = ('{"timestamp":"%s","actor":"%s","order":"%s","realm":"%s","event":"%s","message":"%s","prev":"%s"'
            % (e["timestamp"], e["actor"], e["order"], e["realm"], e["event"], e["message"], e["prev"]))
    calc = hashlib.sha256((prev + "\n" + base).encode()).hexdigest()
    ok = (e["prev"] == prev and e["checksum"] == calc)
    print(("OK   " if ok else "BAD  "), e["event"], e["checksum"][:12])
    prev = e["checksum"]
PY
```

> **Whitespace exactness.** The checksum folds the raw `base` string produced by the shell,
> which JSON-escapes message characters (e.g. `\n` → `\\n`). Recompute using the decoded JSON
> field values exactly as the script wrote them; a naive re-serialization with different key
> ordering or spacing will not match.

---

## 5. The read-only observer law

Plan 23 is a hard contract:

- **Never write outside `state/` and the Runes ledger.** The observer only reads manifests and
  SQLite in read-only mode; Ymir is self-observing.
- Every observation is carved as a Rune line (`huginn / observer.<source>`); the well is
  watered by the memory jobs, not here.
- Realm boundaries are sacred; the external worktree root stays read-only and Ymir owns only
  its own tree.

Violations are a runtime-compliance failure (see `runtime-compliance.md`).

---

## 6. Add a new job

1. **Write the runner** at `bin/nornir-job-<name>.sh`:
   - `#!/usr/bin/env bash` + `set -u`, header comment naming the Norse figure and purpose.
   - Source the ledger: `. "$SCRIPT_DIR/runes-append.sh"`.
   - Resolve `ROOT`, `BROKK_HOME`, `STATE`, `DATA` from `BROKK_*_OVERRIDE`.
   - Read only inputs; write outputs atomically (`.tmp.$$` then `mv`).
   - End with one `runes_append "<actor>" "<event>" [--realm R] --message "..."`.
   - `bash -n` clean; fail loudly with `error:` + `help:` on stdout.
2. **Register it** in `config/cron.yaml` as `HH:MM bin/nornir-job-<name>.sh`.
3. **(Re)start** the scheduler: `bin/nornir-cron-start.sh`.
4. **Prove idempotence**: run the job twice; the date guard must suppress a second dispatch the
   same day, and the job itself must be safe to re-run.

```bash
chmod +x bin/nornir-job-example.sh
bash -n bin/nornir-job-example.sh
printf '05:00 bin/nornir-job-example.sh\n' >> config/cron.yaml
bin/nornir-cron-start.sh --status
bin/nornir-cron-start.sh
```

---

## 7. Verification and smoke commands

```bash
# 1. Scheduler is running with the expected job count
bin/nornir-cron-start.sh --status          # cron: running pid=… jobs=4

# 2. All job scripts and the ledger parse
for f in bin/nornir-job-*.sh bin/nornir-cron-start.sh bin/runes-append.sh; do
  bash -n "$f" && echo "OK $f"
done

# 3. Idempotent start: a second start must not spawn a second loop
bin/nornir-cron-start.sh; bin/nornir-cron-start.sh --status

# 4. Each job runs standalone (fresh processes, exit 0)
bin/nornir-job-daily-briefing.sh
bin/nornir-job-observer.sh
bin/nornir-job-memory-housekeeping.sh
bin/nornir-job-git-sync.sh

# 5. Ledger append + chain
bin/runes-append.sh smoke ledger.append --realm way-of --message "nornir smoke"
tail -n 3 workspace/memory/runes_audit.md

# 6. Cron log carries run records
tail -n 20 state/cron.log

# 7. Observer left no writes in the external trees (read-only proof)
git -C $BROKK_UPSTREAM status --porcelain    # must not contain observer edits
```

---

## 8. Gotchas

- **Stamps are written before the run.** A job that fails mid-run will not retry until the next
  day. Make jobs safe to invoke by hand (`bash bin/nornir-job-*.sh`) for recovery.
- **PID reuse guard.** A stale `state/cron.pid` whose process is alive but whose cmdline lacks
  `cron run:` is treated as stopped; `--stop` removes it.
- **`bash -lc` means login shell.** A job that depends on a non-login shell environment
  (PATH, aliases) may differ from interactive runs; put explicit env in the script.
- **Two ledgers exist.** The live one is `workspace/memory/runes_audit.md`; the stub under
  `.agents/memory/` is not written by the default path.
- **The chain is order-dependent.** Never hand-edit, reorder, or delete ledger lines; append
  only through `runes-append.sh`.
- **Observer never writes outward.** The observer is self-contained: it reads only Ymir's own
  tree (plus the read-only external worktree root) and writes only `state/` and Runes.
- **`git-sync` is safe by default.** It will not force, reset, or discard; a diverged branch is
  reported, not fixed.
- **Prune is opt-in and backup-gated.** `BROKK_MEMORY_PRUNE=0` is the default; a failed backup
  skips pruning entirely.

## 9. Maintaining this

- Add or change a job → update §3, `config/cron.yaml`, and the four-inputs table in §3.1 if the
  briefing's sources change.
- Change the ledger format or chaining → update §4 and the verify snippet in §4.6 in lockstep;
  the chain must remain reproducible.
- Change scheduler state file names → update §1.2 and the smoke commands in §7.
- Keep the observer's source list in §3.2 aligned with `bin/nornir-job-observer.sh`; the plan-23
  read-only law is non-negotiable.

### The realm default is `wayof` again, and the realm's secrets live with it (2026-09-12)

The stale multi-tenant name `way-of` was still the hardcoded fallback in the
Nornir jobs (`REALM="${REALM:-way-of}"`), so a job whose realm was not supplied
looked in a directory the platform had already retired — and the operator's real
`svartalfaheim/way-of/.env.realm` lived there, so it worked by accident while the
directory was the wrong one. Both now say `wayof`, the company container named in
`svartalfaheim/README.md`.

Realm secrets are read from `svartalfaheim/<realm>/.env.realm` (active realm, or
`BROKK_REALM`). The tracked file is `.env.realm.example`; the real one is ignored
(`.gitignore`: `svartalfaheim/*/.env*`, with `!*.example` so templates stay
tracked). The full how-to for a company's secrets — realm-level and per-venture —
is `svartalfaheim/wayof/SECRETS.md`.

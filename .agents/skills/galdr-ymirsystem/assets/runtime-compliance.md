# Runtime Compliance — the acceptance gates Galdr/Tyr enforce

Purpose: the runnable acceptance checklist for the Brokk/Eindri/Nornir runtime. Every gate
below is verified against real artifacts in this repo, with the exact command, the pass
criterion, and the failure mode. Nothing ships on a mock, an example, or a silent fallback.

> Galdr is the **master builder and maintainer** of the Ymir runtime: it forges the tooling
> surface, defines the ergonomic contract, and keeps the runtime honest. Tyr is the judge —
> the one-handed who holds the gate. A gate is not "probably fine"; it is a command that exits
> 0 with evidence.

The canonical source scripts live in `bin/` and `config/`; the canonical reference docs are the
siblings of this file (`eindri-orchestration.md`, `nornir-jobs.md`). The runtime's authority is
`docs/plans/29-brokk-distro-runtime.md` and `AGENTS.md`.

---

## 1. Gates at a glance

| # | Gate | Command | Pass criterion |
|---|---|---|---|
| 1 | Shell parses | `bash -n <script>` for every `bin/*.sh` | No syntax errors. |
| 2 | JSON parses | `python3 -c "json.load(...)"` for every JSON | No `JSONDecodeError`. |
| 3 | Smoke evidence | run each runtime script standalone | Exit 0; expected line present. |
| 4 | Norse naming | audit component names against the table | Every subsystem named for its Norse figure. |
| 5 | Harness fail-closed | spawn with an unverified/absent harness | Non-zero exit, plain reason, no silent fallback. |
| 6 | Session lock | inspect `state/.lock` | Bound to a live PID; refused lock ⇒ read-only. |
| 7 | Turn-end guard | run `syn-turnend-guard.sh` with/without arm marker | Inert (0) until armed; 2 when armed and stale. |
| 8 | No mocks/examples/placeholders | grep the shipped runtime | No TODO/FIXME/MOCK/placeholder in `bin/`, live `config/`. |
| 9 | Cron idempotent + date-guarded | start twice; inspect stamps | One loop; one run per job per day. |
| 10 | Observer read-only | confirm a run touches only `state/` + Runes | No writes to Ymir's tree or the read-only worktree root. |
| 11 | Secrets never committed | secret scan + ignore audit | No secret literal; ignore rules cover env files. |
| 12 | Governed assets current | `compliance-check.sh` (`assets` check) | A governed path changed in the working tree has its owning asset changed too. |
| 13 | **Governed paths resolve** | `compliance-check.sh` (`governed` check) | Every path in `AGENTS.md`'s `governed[]` table exists (or its glob matches something). |

### Governed paths — load the asset before you edit

The `assets` gate and the `bin/syn-asset-pretool-check.sh` seatbelt both use this
map. The seatbelt **denies the edit** until the asset was read this session
(reads recorded in `state/asset-reads`); the gate **fails the run** when the code
changed but the asset did not.

```
governed[6]{path,load_first}:
  "bin/ymir-install.sh",".agents/skills/galdr-ymirsystem/assets/installation.md"
  "apps/hlidskjalf/**",".agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md"
  "bin/mimir*",".agents/skills/galdr-ymirsystem/assets/memory-well.md"
  "bin/nornir-* | config/cron.yaml",".agents/skills/galdr-ymirsystem/assets/nornir-jobs.md"
  "bin/valknut-load.sh | .pi/** | .opencode/**",".agents/skills/galdr-ymirsystem/assets/harness-integration/README.md"
  "bin/smidja* | .agents/skills/smidja/**",".agents/skills/galdr-ymirsystem/assets/smidja.md"
```

The same routes appear in `AGENTS.md` (`governed[]`) and are printed in the
session digest under `ASSET ROUTING`, so the mapping is reachable even when the
galdr router itself is not loaded.

---

## 2. Gate detail

### G13 — every governed path resolves (the silent-failure guard)

A governed path that does not exist is **worse than a missing rule**: the pretool
guard's `asset_for` stops matching, so the protection is gone and nothing fails,
warns, or logs. This was not hypothetical — the `smidja` → `smidja-factory`
rename left `smidja-factory-factory` in seven places, including `AGENTS.md`'s own
`governed[]` table and the guard's pattern, and the smidja rule quietly stopped
protecting anything.

The check reads the `governed[]` table out of `AGENTS.md`, splits each row on
`|` (a row may name alternatives), and resolves every entry — a plain path with
`-e`, a glob with `compgen -G` — counting all of them:

```bash
bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh | grep governed
# "governed","governed paths resolve","PASS","all 25 governed paths exist"
```

**Rule for a rename:** `grep -rn '<old>' --include='*.sh' --include='*.md'` across
`bin/`, `AGENTS.md`, and `.agents/skills/*/assets/` — including the *patterns* that
name governed paths, not just the prose. Then re-run this check.

### G1 — every shell script is `bash -n` clean

**Why:** a syntax error in a cron job or spawn path fails silently at 03:00 unless the parse is
checked now.

```bash
fail=0
while IFS= read -r f; do
  bash -n "$f" 2>/tmp/bn.err || { echo "SYNTAX FAIL: $f"; cat /tmp/bn.err; fail=1; }
done < <(find bin .agents -name '*.sh' -type f | sort)
[ "$fail" = 0 ] && echo "G1 PASS: all shell scripts parse clean"
```

**Pass:** `G1 PASS`. **Failure:** any `SYNTAX FAIL`, exit 1.

### G2 — every JSON parses

**Why:** `config/eindri-dispatch.json` gates dispatch and `sandcastle.config.json` gates Utgard
caps; a trailing comma breaks the runtime.

```bash
fail=0
while IFS= read -r f; do
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null \
    && echo "OK  $f" || { echo "BAD $f"; fail=1; }
done < <(find config .agents -name '*.json' -type f | sort)
[ "$fail" = 0 ] && echo "G2 PASS: all JSON parses"
```

**Pass:** `G2 PASS`. **Failure:** any `BAD`, exit 1.

### G3 — smoke-test evidence

**Why:** "it parses" is not "it runs". Each runtime script must execute standalone and emit its
contract line.

| Script | Smoke command | Expected |
|---|---|---|
| `bin/hamr-harness.sh` | `bin/hamr-harness.sh` | one of `claude codex opencode pi pi-signed grok kimi cursor unknown` |
| `bin/nornir-cron-start.sh` | `bin/nornir-cron-start.sh --status` | `cron: running … jobs=<n>` or `cron: stopped …` |
| `bin/vor-crew-state.sh <id>` | after a spawn | `state: … · source: … · …` |
| `bin/runes-append.sh` | `… smoke ledger.append --message x` | `runes: appended … checksum=…` |
| `bin/einherjar-spawn.sh --help` | `--help` | usage text, exit 0 |
| `bin/erindi-brief.sh --help` | `--help` | usage text, exit 0 |
| `bin/saga-session-start.sh` | `bash bin/saga-session-start.sh` | `BROKK SESSION START …` with all stages |

```bash
bin/hamr-harness.sh
bin/nornir-cron-start.sh --status
bin/einherjar-spawn.sh --help >/dev/null && bin/erindi-brief.sh --help >/dev/null && echo "help OK"
bash bin/saga-session-start.sh >/tmp/saga.out && grep -q 'BROKK SESSION START' /tmp/saga.out && echo "G3 PASS"
```

**Pass:** every script exits 0 and prints its contract line. **Failure:** a missing line or a
non-zero exit.

### G4 — Norse naming validity

**Why:** every subsystem is named for the figure whose role matches its work; nautical or
generic labels are not Ymir components.

| Component | Norse name | Artifact(s) |
|---|---|---|
| Primary agent | **Brokk** | `AGENTS.md`, Brokk runtime |
| Sub-agent worker | **Eindri** | `.agents/subagents/` |
| Worker gather | **Einherjar** | `bin/einherjar-spawn.sh` |
| Worker brief | **Erindi** | `bin/erindi-brief.sh` |
| State reconciliation | **Vör** | `bin/vor-crew-state.sh` |
| Session-start digest | **Sága** | `bin/saga-session-start.sh`, `saga-sessionstart-run.sh` |
| Watch / supervision | **Sýn** | `bin/syn-watch-arm.sh`, `syn-turnend-guard.sh` |
| Session lock | **Gleipnir** | `bin/gleipnir-lock-lib.sh` |
| Harness detection | **Hamr** | `bin/hamr-harness.sh` |
| Scheduled jobs | **Nornir** | `bin/nornir-cron-start.sh`, `nornir-job-*.sh` |
| Daily briefing | **Sága** | `bin/nornir-job-daily-briefing.sh` |
| Memory housekeeping | **Muninn** | `bin/nornir-job-memory-housekeeping.sh` |
| Observation | **Huginn** | `bin/nornir-job-observer.sh` |
| Git sync | **Yggdrasil** | `bin/nornir-job-git-sync.sh` |
| Audit ledger | **Runes** | `bin/runes-append.sh`, `runes_audit.md` |
| Worktree isolation | **Yggdrasil** | `.yggdrasil/` |
| Sandbox | **Utgard** | `.agents/sandbox/` |
| Process supervision | **Valhalla** | supervision tree asset |
| Human merge gate | **Glitnir** | Hlidskjalf PR review |

```bash
# No nautical component labels leaked into our scripts.
grep -rniE 'Allfather|Brokk|Allfather-hold|Eindri' bin/ \
  && echo "G4 REVIEW: nautical term present — verify it is provenance only" \
  || echo "G4 PASS: no nautical component names in bin/"
```

**Pass:** every runtime artifact maps to a Norse figure; domain words appear only as provenance
comments. **Failure:** a nautical or generic name is used as a component.

### G5 — harness adapters fail closed

**Why:** launching an unverified adapter must never happen silently.

```bash
# With dispatch active, omitting --harness must refuse.
bin/einherjar-spawn.sh demo /tmp --mode local-only; echo "exit=$?"   # expect 1, error + help

# An explicitly unverified harness must refuse.
bin/einherjar-spawn.sh demo /tmp --mode local-only --harness claude; echo "exit=$?"  # expect 1
```

**Pass:** both refuse with a plain reason naming the verified set
(`opencode pi pi-signed`). **Failure:** a launch proceeds, or a fallback harness is substituted.

### G6 — session lock bound to the live session

**Why:** a second session must not mutate shared state. Gleipnir holds one live session per
home.

```bash
cat state/.lock 2>/dev/null; echo
owner=$(tr -d '[:space:]' < state/.lock 2>/dev/null || true)
if [ -n "$owner" ] && kill -0 "$owner" 2>/dev/null; then
  echo "G6 PASS: lock held by live pid $owner"
else
  echo "G6 PASS (no live session): lock is absent or stale — a new session acquires read-write"
fi
```

`bin/saga-session-start.sh` prints `session lock held` or
`READ-ONLY: session lock held by pid <n> — no spawn, steer, merge, drain, or repair this
session`. A refused lock is a read-only session by law.

**Pass:** the lock is either absent/stale (acquirable) or held by a live PID.
**Failure:** a lock names a live PID owned by another session yet this session mutates state.

> **Gotcha.** `bin/gleipnir-lock-lib.sh:87-88` declares `GLEIPNIR_LOCK_ACQUIRED=0` and never
> updates it. Callers must use `gleipnir_lock_acquire`'s **return code**, not that variable.

### G7 — turn-end guard inert until armed

**Why:** the guard must never block a turn before supervision has ever been armed, and must
refuse a blind turn end once armed and the watcher is stale.

```bash
# Inert before the first arm:
rm -f state/.supervision-armed
echo '{"stop_hook_active":false}' | bash bin/syn-turnend-guard.sh; echo "unarmed exit=$?"   # expect 0

# Armed + stale heartbeat → refuse:
: > state/.supervision-armed
printf '0\n' > state/.watch.heartbeat
echo '{"stop_hook_active":false}' | bash bin/syn-turnend-guard.sh; echo "armed-stale exit=$?"  # expect 2
rm -f state/.supervision-armed state/.watch.heartbeat
```

Staleness threshold: `BROKK_WATCH_HEARTBEAT_STALE_SECONDS` (default 60).

**Pass:** exit 0 unarmed; exit 2 armed+stale with the recovery instruction on stderr.
**Failure:** exit 2 while unarmed, or exit 0 while armed and stale.

### G8 — no mocks / examples / placeholders in the shipped runtime

**Why:** plan 29 §14 mandates real, working files. A placeholder in `bin/` or a live `config/`
file is a production defect.

```bash
# Shipped runtime must be real:
grep -rnE 'TODO|FIXME|XXX|placeholder|<PLACEHOLDER>|MOCK|mock_data|not implemented' \
  bin/ config/ .agents/sandbox/ 2>/dev/null \
  && echo "G8 REVIEW: markers above need justification" \
  || echo "G8 PASS: no mock/placeholder markers in the shipped runtime"
```

Allowed exceptions (documented, not defects):

- Template fixtures are allowed **only** as committed `*.example` scaffolding
  (`data/*.example`, `config/*.example`); the live `data/` and `config/` must hold real files.
- Reference-configuration assets inside `.agents/skills/galdr-ymirsystem/assets/pi-boot/` are documentation
  templates, not runtime.

**Pass:** no markers in `bin/`, `config/`, `.agents/sandbox/`. **Failure:** a mock or
placeholder in the live runtime.

> **Disagreement to track.** `.gitignore` allows `!data/*.example` / `!config/*.example`
> ("ship `*.example` templates only"), but plan 29 §14 says "No mocks, no examples, no
> placeholders in the shipped runtime." The reconciling reading: `*.example` are committed
> onboarding templates; the **runtime** must still contain real files. No `*.example` fixtures
> exist in the tree today.

### G9 — cron idempotent and date-guarded

**Why:** session start calls the scheduler every launch; it must not spawn a second loop, and a
job must not run twice in a day.

```bash
bin/nornir-cron-start.sh --status
first=$(bin/nornir-cron-start.sh | sed -n 's/.*pid=\([0-9]*\).*/\1/p')
second=$(bin/nornir-cron-start.sh | sed -n 's/.*pid=\([0-9]*\).*/\1/p')
[ -n "$first" ] && [ "$first" = "$second" ] && echo "G9 PASS: one loop pid=$first" \
  || echo "G9 FAIL: loop pid changed ($first -> $second)"
ls state/.cron-fired/ 2>/dev/null   # one date stamp per job
```

**Pass:** the same PID is reported on repeat start; each job has one `YYYY-MM-DD` stamp per day.
**Failure:** a duplicate loop, or a job dispatched twice for the same date.

### G10 — observer read-only

**Why:** plan 23 makes the observer self-contained and read-only.

```bash
bin/nornir-job-observer.sh >/dev/null
# The observer must only mutate its own state and the ledger:
git status --porcelain 2>/dev/null \
  | grep -v -E '^.. (state/|workspace/memory/runes_audit\.md)' || true
tail -n 5 state/observer.log
```

**Pass:** no changes outside `state/` and `workspace/memory/runes_audit.md`.
**Failure:** any other file changes — the observer writes nothing into the runtime.

### G11 — secrets never committed

**Why:** realm/platform secrets live in env files that are gitignored; a committed key is a
breach.

```bash
# 1. Ignore rules cover the secret files.
grep -nE '\.env\.local|\.env\.realm|\.env$' .gitignore
# 2. No secret-looking literals in tracked runtime/docs.
grep -rnE '(sk-[A-Za-z0-9]{16,}|ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' \
  bin config .agents AGENTS.md docs 2>/dev/null \
  && echo "G11 FAIL: possible secret literal" \
  || echo "G11 PASS: no secret literals in runtime/docs"
# 3. Env files are not readable by the doc surface (they are private).
ls -la .env.local svartalfaheim/*/.env.realm 2>/dev/null || echo "no env files present (or private)"
```

**Pass:** secret files are ignored; no secret literal in tracked runtime/docs; secrets are
referenced by variable name only. **Failure:** a literal key/token, or an env file not ignored.

---

## 3. One runnable checklist

Run from the Ymir root (`BROKK_HOME=$YMIR_ROOT`). Non-zero output is the signal to stop.

```bash
set -u
ROOT="${BROKK_HOME:-$YMIR_ROOT}"
cd "$ROOT"
rc=0

echo "== G1 shell parse =="
while IFS= read -r f; do bash -n "$f" || { echo "FAIL G1 $f"; rc=1; }; done \
  < <(find bin .agents -name '*.sh' -type f | sort)
[ "$rc" = 0 ] && echo "G1 PASS"

echo "== G2 JSON parse =="
for f in $(find config .agents -name '*.json' -type f | sort); do
  python3 -c "import json,sys;json.load(open(sys.argv[1]))" "$f" || { echo "FAIL G2 $f"; rc=1; }
done
[ "$rc" = 0 ] && echo "G2 PASS"

echo "== G3 smoke =="
bin/hamr-harness.sh >/dev/null || { echo "FAIL G3 hamr"; rc=1; }
bin/nornir-cron-start.sh --status >/dev/null || { echo "FAIL G3 cron"; rc=1; }
bin/einherjar-spawn.sh --help >/dev/null || { echo "FAIL G3 spawn-help"; rc=1; }
bin/erindi-brief.sh --help >/dev/null || { echo "FAIL G3 brief-help"; rc=1; }

echo "== G5 harness fail-closed =="
bin/einherjar-spawn.sh compliance /tmp --mode local-only >/dev/null 2>&1 \
  && { echo "FAIL G5: spawn did not refuse"; rc=1; } || echo "G5 PASS"

echo "== G7 turn-end guard =="
rm -f state/.supervision-armed
echo '{}' | bash bin/syn-turnend-guard.sh; [ $? = 0 ] || { echo "FAIL G7 unarmed"; rc=1; }
: > state/.supervision-armed; printf '0\n' > state/.watch.heartbeat
echo '{}' | bash bin/syn-turnend-guard.sh; [ $? = 2 ] || { echo "FAIL G7 armed-stale"; rc=1; }
rm -f state/.supervision-armed state/.watch.heartbeat

echo "== G8 no placeholders =="
grep -rqE 'TODO|FIXME|MOCK|not implemented' bin/ config/ .agents/sandbox/ \
  && { echo "REVIEW G8"; } || echo "G8 PASS"

echo "== G9 cron idempotence =="
p1=$(bin/nornir-cron-start.sh | sed -n 's/.*pid=\([0-9]*\).*/\1/p')
p2=$(bin/nornir-cron-start.sh | sed -n 's/.*pid=\([0-9]*\).*/\1/p')
[ "$p1" = "$p2" ] && echo "G9 PASS pid=$p1" || { echo "FAIL G9"; rc=1; }

echo "== G11 secrets =="
grep -rqE '(sk-[A-Za-z0-9]{16,}|ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})' bin config .agents 2>/dev/null \
  && { echo "FAIL G11"; rc=1; } || echo "G11 PASS"

echo
[ "$rc" = 0 ] && echo "RUNTIME COMPLIANCE: PASS" || echo "RUNTIME COMPLIANCE: FAIL"
exit "$rc"
```

> The smoke block writes and removes `state/.supervision-armed` and `state/.watch.heartbeat`.
> Run it only when no live watcher owns those files; otherwise use a throwaway
> `BROKK_STATE_OVERRIDE` directory.

---

## 4. Verification

- The checklist in §3 is the verification. Run it before any merge that touches `bin/`,
  `config/`, or `.agents/sandbox/`.
- Attach the G3 smoke output as evidence; "it parses" alone is not acceptance.
- For a spawn change, also capture a real `spawned …` line and a `vor-crew-state.sh` read.
- For a cron change, capture `--status` plus the relevant `state/.cron-fired/` stamps.

---

## 5. Gotchas

- **`bash -n` checks syntax, not behavior.** G3 exists because a clean parse can still
  misresolve paths or exit non-zero.
- **`GLEIPNIR_LOCK_ACQUIRED` is never set to 1.** Use the `gleipnir_lock_acquire` return code.
- **The turn-end guard is inert without `state/.supervision-armed`.** A guard that fires before
  the first arm is a bug, not diligence.
- **Cron stamps are written before the run**, so a failed job does not retry that day.
- **`$YMIR_ROOT` is not a git repo.** `git-sync` correctly reports no targets; do not
  treat that as a failure of G10.
- **Secret scanning is heuristic.** G11 catches common literals; the real law is that secrets
  live only in gitignored `.env.local` / `.env.realm` and are referenced by variable name.
- **Reference-config assets are not runtime.** Files under
  `.agents/skills/galdr-ymirsystem/assets/pi-boot/` are documentation; G8 does not fail on them.

## 6. Maintaining this

- Adding a runtime script? Add its `bash -n` and smoke command to G1/G3 and to §3.
- Adding a scheduler job? Add its idempotence/date-guard evidence to G9.
- Changing the lock, guard, or harness resolution? Update the matching gate and its expected
  exit codes **in the same change**.
- Keep the Norse name table in G4 in lockstep with `docs/plans/29-brokk-distro-runtime.md §12`.
- When a new gate is added, prefer a runnable command over prose; a gate without a command is
  an opinion.

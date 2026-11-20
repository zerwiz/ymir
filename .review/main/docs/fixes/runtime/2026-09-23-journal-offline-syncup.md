## runtime · unversioned · 2026-09-23 — the offline journal and reconciler (plan 51 Phase 2b)

### Why
- **Problem:** a machine with the heart down — or **no network at all** — had no
  way to keep working *and* deliver what it did. Plan 51's law 6 requires a
  machine to stay fully usable offline and **sync up** on reconnect, and law 7
  requires the heart to be the only writer of the canonical record so a chain can
  never fork (which it once did).
- **Fix:** a durable, local-first outbox.
  - **`bin/journal-append.sh`** — appends one **idempotent** entry
    (`{"key":"<host>:<seq>:<uuid>","ts","actor","op","data"}`) to
    `$STATE/journal/<host>.jsonl`. It never touches the network, so a write
    commits and the machine keeps working with the heart down or fully offline.
  - **`bin/journal-reconcile.sh`** — runs on a heartbeat. If the heart is not
    `attached` (per `bin/topology.sh`), the journal **stays queued and exit 0** —
    being offline is fine, never a failure. If the heart answers, each pending
    journal is pushed, then moved to `journal/sent/`, so a machine offline for
    days reconciles in one pass with no double-send. The push is pluggable
    (`YMIR_JOURNAL_PUSH`, used by the tests); the default ssh's the file to the
    heart's `~/.ymir-inbox/<host>.jsonl`.
  - Journals are **namespaced by hostname**, so the heart folds many machines'
    journals into one record without a fork (Law 7).

### Verified
- `.agents/tests/journal.test.sh` — **ALL PASS**: two entries appended with no
  network; distinct idempotency keys; each line valid JSON; detached → queued and
  preserved; attached → pushed, heart receives it, journal moves to `sent/`;
  empty queue reports clean.
- `bash -n` clean on both scripts.

### Files
- `bin/journal-append.sh`
- `bin/journal-reconcile.sh`
- `.agents/tests/journal.test.sh`

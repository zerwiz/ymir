## runtime · unversioned · 2026-09-27 — the cron resolves the helm through the pointer

### Why

The local installation's validate (2026-09-27) caught a real merged-code defect:
`bin/nornir-cron-start.sh` probed the session lock at the RAW legacy default
(`${XDG_STATE_HOME:-$HOME/.local/state}/ymir/brokk.lock`) and ignored
`state/.lock-path` — the Phase-0 pointer that is the ONE fact of where the helm
sits. When the primary session's lock was re-stood elsewhere (or the pointer
governed), the cron read the old empty path, retired itself every cycle
("cron retired - no live session lock"), and validate reported red. The law the
ward teaches, restated by the cron's own comment: one resolver, never restate.

### The fix

- The lock probe now resolves through `state/.lock-path` when present (the
  pointer's directory), with `BROKK_MACHINE_STATE_DIR` still the authority when
  set and the legacy default as the last fallback. The retire-on-no-live-lock
  law is unchanged.
- The primary session's own lock (which the flaps had deleted — the same
  Phase-0c wind) was re-stood by the seated primary during the installation;
  with the probe pointer-true, a re-stood host is read correctly without code
  changes.

galdr-reread: `nornir-jobs.md` (the session-bound retirement row).

### Files

- `bin/nornir-cron-start.sh`
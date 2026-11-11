# Rödd holds the arm — one helm, any harness

**Date:** 2026-11-11 · **Component:** voice / arm (`src/ymir_runtime/watch.py`, `bin/pi/syn-watch-arm.sh`, `bin/voice/rodd-arm.sh`, `bin/voice/rodd-helm.sh`, `bin/seat/lock-ask.sh`, `bin/agents/eir-doctor.sh`)

## What was wrong

1. **The lease could not say whose helm it was.** `src/ymir_runtime/watch.py` wrote
   `pid= starttime= gen= mode= session= heartbeat= state=` — `mode=` was the service shape
   (`systemd|daemon`), so nothing on disk named the holder. Every reader (`rodd-arm.sh who`,
   `lock-ask.sh`, `syn-watch.sh status`) could report a holder pid but not a holder role.
2. **Rödd's session could win a vacant helm and answer nothing.** Her pi session was eligible for
   the lock, but her spawn ran no arm client and no duty loop — a silent inheritance: she would hold
   the helm and drain nothing.
3. **No handover.** The helm could only move when a holder died or a session was closed; there was no
   `hold` / `release`, and no room line naming both pids of a handover.

## The fix

- **`role=` beside `mode=`.** `write_lease` gains `role=`; `mode=` keeps its meaning and is never
  overloaded. `resolve_role` reads `BROKK_ARM_ROLE` (the daemon's own env) → the client's sidecar
  (`state/.arm.role`, keyed to the session) → the session's harness comm (`pi` → `counsellor`, the
  rest keep their name). No holder, no declaration, no readable harness is `role=unknown` — never a
  guess. The four readers report it: `rodd-arm.sh who|--check`, `lock-ask.sh who`,
  `syn-watch.sh status`, and the module's own `status --detail`.
- **One client, extended — never a second.** `bin/pi/syn-watch-arm.sh` gains `--holder <role>`
  (default derived from the comm) and honours `BROKK_ARM_ROLE`. The claim is allowed only when three
  clauses hold — a vacant helm, a live harness in `HARNESS_COMMS`, and a declared role it can work
  (`rodd`, `counsellor`, or a harness name) — and anything else is refused loudly with the failing
  clause named, never silently inherited.
- **Nanna carries the duties.** `bin/voice/rodd-helm.sh` is the thin duty loop: drain
  (`bin/time/saga-wake-drain.sh`), answer the room (append-only `<lease state>/rodd/room.jsonl`),
  alarm (`ymir-say.sh --mark-alarm`), dispatch (`einherjar-spawn.sh`, `direct-PR`/`no-mistakes` only),
  and refuse-and-release (`rodd-arm.sh release`). A refused wake is spoken, never dropped.
- **`hold` / `release`.** `bin/voice/rodd-arm.sh` gains both, announced in the room with both pids;
  a `hold` while another live seat holds the helm is refused with the holder's name — never a forced
  steal, which the lock already refuses.
- **The guard.** `bin/agents/eir-doctor.sh` gains the `roddhelm` surface (`rodd-helm.sh --check`),
  and the harness-integration Galdr asset carries the "one helm, any harness" paragraph.

## Proven

- `bash bin/voice/tests/test_rodd_arm.sh` — 42 passed, 0 failed (who/--check role reading · hold ·
  release · refuse with the holder named).
- `bash bin/voice/tests/test_rodd_helm.sh` — 16 passed, 0 failed (a queued wake answered and acked once ·
  a merge wake refused and the helm released · `--check` · `--holder rodd` sidecar · clause 2/3 refusals).
- `bash bin/seat/tests/test_lock_ask.sh` — 10 passed, 0 failed (role in the lease line; the lock now
  resolves hermetically via `BROKK_MACHINE_STATE_DIR`).
- `PYTHONPATH=src python3 -m unittest discover -s src/ymir_runtime/tests -t src -p test_watch.py` —
  54 tests OK (`role=` written and read; `mode=` not overloaded; the sidecar names the holder only for
  its own session).
- `bin/records/weave-features.sh --check` — the fragments weave (217 entries).

## CHANGE LOG

- **2026-11-11** — carved. The lease gains `role=` (identity, never overloaded onto `mode=`) and four readers
  report it; the one arm client gains `--holder` with the three-clause claim; Nanna's duty loop lands in
  `bin/voice/rodd-helm.sh`; `rodd-arm.sh` gains `hold`/`release`; the `roddhelm` Eir surface, the harness-integration
  paragraph, the woven catalogue and this fix note follow (plan 254).

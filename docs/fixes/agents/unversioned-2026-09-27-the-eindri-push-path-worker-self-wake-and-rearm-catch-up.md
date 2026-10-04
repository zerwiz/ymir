## agents · unversioned · 2026-09-27 — the Eindri push path: worker self-wake, re-arm catch-up, one ledger

### Why

The 2026-09-27 missed handoff (audited in plan 58, Phase 3) was only half cured. PR
#218 taught the spawn brief's terminal act to write the report shelf the failsafe
sweeps, and scheduled the 06:45 sweep. Three decrees of the audit were still open,
and the hole was plain: the wake still depended on something else being alive — the
poller, the sweep, or the arm. A worker that finished cleanly could still be silent
if all three were down.

Measured facts this closes:

1. The worker had no way to write its OWN wake. `bin/agents/eindri-acclaim.sh` was the
   poller's action half only, so a dead poller meant a dead handoff.
2. The poller's `eindri-acclaim.sh` and the failsafe `eindri-handoff.sh` kept
   **separate** delivery markers (`state/eindri-done/` vs `state/eindri-handoff/`),
   so one finished errand could be queued twice — two roads, two ledgers, not one
   contract.
3. A watcher re-arm after a flap did not reconcile the dead window before it began
   its own poll loop (and a read-only arm never reconciled at all).

### The fix

1. **The worker's own terminal act is one command, and it writes the wake.**
   `bin/agents/eindri-acclaim.sh <id> --terminal done --line "<what shipped>"` appends the
   status line, files the report shelf (`state/eindri-reports/<id>.md`; a
   `needs-decision` files `state/eindri-questions/<id>.md`), appends the durable
   wake to `state/.wake-queue`, marks the ledger, and sounds the note. The spawn
   brief (`bin/agents/erindi-brief.sh`) teaches it as the terminal act in every mode
   (direct-PR, local-only, no-mistakes, scout), with a gate that proves the wake is
   in the queue. A well-behaved worker now needs **no arm, no poller, and no
   sweep** to be heard.
2. **One shelf, one contract — one ledger.** New `bin/agents/eindri-wake-lib.sh` owns the
   shared delivery ledger `state/eindri-delivered/<id>.<kind>`, the durable queue
   append, and the desktop note. Both `eindri-acclaim.sh` and `eindri-handoff.sh`
   read and write it, so exactly one wake is written per (id, kind) whichever road
   arrives first. Legacy markers (`state/eindri-handoff/<id>.report`,
   `state/eindri-done/<id>.md`) are honoured as already-delivered, so an existing
   home never re-fires old news. `acclaim` also heals the report shelf from a
   terminal status line when a worker wrote only the wrong shelf.
3. **Catch-up on re-arm.** `bin/syn-watch-arm.sh` runs the handoff sweep *before*
   the session lock and the poll loop and prints `watcher: catch-up sweep
   delivered=<n>`, so recovery reconciles what the dead window missed even when the
   arm is refused read-only. The Pi extension (`gna-pi-watch.ts`, Gná) calls the
   same sweep the moment it re-arms, before the arm child is spawned. The arm
   ABI/grammar the extension parses is **unchanged** (`watcher: started pid=…
   recovery-generation=…`, `--handling-delivered <gen> --watcher-pid <pid>`); the
   catch-up line and the pre-existing per-cycle sweep are purely additional.

### Proof (run, not asserted)

Scratch `/tmp` states, no arm running:

- `acclaim <id> --terminal done --line …` → wake in `.wake-queue`, status line and
  shelf written, `bin/time/saga-wake-drain.sh` prints `WAKE eindri <id> reported`.
- A shelf written with no acclaim (a session that died mid-errand) → `handoff sweep`
  exits 3, drain finds it; a second sweep exits 0 (idempotent).
- acclaim after the sweep does not double the wake; the shared ledger is named.
- A legacy `eindri-done/<id>.md` marker suppresses re-delivery.
- `syn-watch-arm.sh --restart` prints `watcher: catch-up sweep delivered=1`, fills
  the queue, and the arm grammar still matches.
- `tsc --noEmit --strict` types the extension clean (exit 0).

### Deployment note

The Pi extension source lives at `.pi/shared/extensions/gna-pi-watch.ts`; the
running harness reads the deployed copy under `~/.pi/agent/extensions/`. This PR
covers the **source**; the deployed copy refreshes with `bin/seat/valknut-load.sh --pi`
(seated as the post-merge hook). Until that deploy, the in-repo arm script's own
catch-up sweep already reconciles on every re-arm — the extension call is the
belt to the arm's braces.

galdr-reread: `harness-integration/README.md`, `nornir-jobs.md`, `registry.md`.

### Files

- `bin/agents/eindri-wake-lib.sh` (new)
- `bin/agents/eindri-acclaim.sh`
- `bin/agents/eindri-handoff.sh`
- `bin/agents/erindi-brief.sh`
- `bin/syn-watch-arm.sh`
- `.pi/shared/extensions/gna-pi-watch.ts`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`
- `.agents/skills/galdr-ymirsystem/assets/nornir-jobs.md`
- `.agents/skills/galdr-ymirsystem/assets/registry.md`
- `.agents/assets/agents/registry.md`

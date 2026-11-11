## agents · unversioned · 2026-11-10 — the seat sweep keeps the grace, and its fixture is declared

### Why

Forseti's review of PR #639 found six faults and held the seal. Five were the kind a
review exists to catch, and one was honest bookkeeping: a fixture the mocks scan did not
know about, a woven catalogue one commit stale, bin indexes one generation behind, a
local commit never published, and a comment that said 120 where the code ships 60.

The sixth is the one that mattered. `bin/seat/seat-reap.sh` closed a workspace whose
errand had **no record at all** — and that is exactly what a seat looks like while it is
booting: `einherjar-spawn.sh` raises the herdr workspace at `launch_herdr` and writes the
first status only AFTER the seat is proved, up to the whole settle wait later. So a sweep
run at a session start could close a seat that was still coming up. The house already
knows this law — `tests/test_eindri_liveness_grace.sh`, written 2026-11-06 after an
errand was judged dead 3m59s in because herdr reported its agent `done` (which means
*idle between turns*, not *finished*): **inside the settling grace a quiet seat reads
SETTLING, and SETTLING corrects nothing.**

### What it does

- **`bin/agents/einherjar-spawn.sh`** writes the launch stamp `state/.<id>.launched`
  beside the workspace id at `launch_herdr`, so the age of a seat is a fact rather than a
  guess. Its comment now says the truth: the wait is 60 seconds, and the number lives in
  `bin/seat/seat-prove.sh`.
- **`bin/seat/seat-reap.sh`** measures a recordless workspace against that stamp (then
  the meta's `launched`, then the worktree's mtime) and:
  - younger than `YMIR_SEAT_SETTLE` (60 s) → row `SETTLING — <n>s old, inside the 60s
    grace`, nothing closed;
  - older → closed, as before;
  - **no timestamp at all → kept**, and said so: an unmeasurable seat is assumed live,
    because assuming dead is the irreversible direction.
- **`bin/seat/tests/test_seat_reap.sh`** gains the ward for all three (`59` cases): a
  freshly stamped recordless seat is SETTLING and survives; the same seat an hour later
  IS closed; an unstamped one is kept and the reason printed.
- **`.agents/skills/galdr-ymirsystem/scripts/mocks-scan.sh`** declares ONE fixture —
  `bin/seat/tests/test_seat_reap.sh`, which stands a `herdr` on PATH so the seat CLOSER can
  be proved without closing, or refusing to close, a live workspace belonging to somebody
  else's errand. `.agents/tests/mocks-scan.test.sh` gains two probes: the declared fixture
  is excused, and a `stub` in the directory BESIDE it is still caught.
- **`compliance-check.sh`'s mocks row now DELEGATES to `mocks-scan.sh`** instead of
  carrying its own copy of the pipeline. Two implementations of one gate is how an excuse
  added to one drifted from the other; the file's own header already calls `mocks-scan.sh`
  *"the mocks gate's one implementation"*, and now it is.
- **The migration is renumbered `0019`** — `0018-the-home-pulls-first.sh` already held that
  number on `origin/main`, and two migrations at one id is a silent no-op for whoever
  applies second.
- `FEATURES.md` re-woven (205 entries) and the bin indexes regenerated (35 files).

### Files

- `bin/agents/einherjar-spawn.sh` · `bin/seat/seat-reap.sh` · `bin/seat/tests/test_seat_reap.sh`
- `.agents/skills/galdr-ymirsystem/scripts/mocks-scan.sh` · `.agents/tests/mocks-scan.test.sh`
- `.agents/skills/galdr-ymirsystem/scripts/compliance-check.sh`
- `.agents/migrations/0019-a-worktree-is-not-a-root.sh` (was `0018-…`)
- `FEATURES.md` · `bin/**/INDEX.md` · `.agents/backend/README.md`

### Verified

- `bash bin/seat/tests/test_seat_reap.sh` → **59 ok / 0 fail**, still against a stubbed
  `herdr` and a throwaway `HOME`.
- `bash .agents/tests/mocks-scan.test.sh` → all probes ok, including the two new ones and
  *"the shipped tree passes its own scan"*.
- `bash bin/records/weave-features.sh --check` → `current (205 entries)`.
- `bash bin/gates/inventory.sh --check` → `current — 35 index file(s), 910 bin doors`.
- `bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh` → every row PASS
  except the `config` row naming hardcoded paths in `bin/gates/tests/test_broken.sh`,
  `test_finding_tally.sh` and `test_pr_identity.sh` — red on `origin/main`, not from this
  branch.

### The correction to the PR body

The first body claimed *"mocks PASS"*. At the published tip that was **false**: the
`mocks` row of `compliance-check.sh` passed only because that row carried its own
pipeline, while `.agents/tests/mocks-scan.test.sh` — the gate's real probe — failed.
Both now run the same scan, and both pass because the fixture is declared rather than
because a second copy of the gate was blind to it.

## ward · 2026-10-21 — the canary: the one attack the bite cannot answer

### Why
The Allfather asked the honest question: *"how can he now actually defend against a hacker that tries
to plant a virus, copy my data, or delete my data?"* Planting and copying have a bite behind them —
quarantine, kill, block egress. **Deletion has none**: a hound cannot bite a file back into
existence. If someone with the operator's own privileges removes the record, the house has lost its
memory and every answer it would give afterwards is a guess.

### Fix
`bin/ward/garmr-canary.sh` — a tripwire, deliberately small:
- `seed` writes a manifest of files that must never vanish, from the guardian config's `canary:` list
  (defaults: the runes ledger, the operator card, the company cards).
- `check` verifies each one. **Append-only records are checked for PRESENCE, not for a hash** — a
  ledger that grows by design must not scream every time it is written to. Identity files are hashed.
- A miss is **CRITICAL**, not a warning, and it goes out through Hófvarpnir to the Gná arm: a deletion
  is a recovery, and the session that has to answer is woken.

### Verified
Three canaries seeded; `check` → `"3",0,0`. A simulated deletion (`mv companies.yaml` aside) →
`"MISSING"`, CRITICAL, exit 1, arm notified; restored → clean again.

### What it is not
A canary is not a backup. It **detects** a deletion; it cannot **undo** one. The undo is snapshots and
an off-box copy — btrfs snapshots, or restic/borg to a machine that is not this one — and that is the
next plan, not this one.

### Files
- `bin/ward/garmr-canary.sh` (new)

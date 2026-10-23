# The registers the rebase left stale

**Date:** 2026-10-23 · **Component:** gates · **PR:** #410

## What was wrong

PR #410 could not merge for two reasons, and only one of them was in its code:

```
blockers[2]{blocker,cause}:
  "FEATURES.md conflicted","both branches appended rows to the same table — #409's Gná row and #410's two Skírnir rows"
  "The gates failed on capability + inventory","both are GENERATED registers and had not been re-rendered since the door count moved 557 → 574"
```

## What this does

1. **The conflict is resolved by keeping every row** — append-only: Gná's row, the audience-law row and
   the voice row all stand. One inaccuracy in the Gná row is corrected while it is in hand: it named
   `hodd/bin/gna-agent/…`, and the tooling shipped to `bin/mail/` in #409.
2. **The registers are regenerated twice and verified stable** — the first regeneration raced the
   rebase and read a tree mid-write, so `learn-home.sh` was recorded as `uncalled` while the settled
   tree says `tested`. Two clean passes now agree with `--check` (rc 0 for capability and inventory).
3. **The queue register is the home's derived view** and was refreshed in place (`queue.sh --check` rc 0).

## Verified

```
bin/gates/ci-verify.sh    0 FAIL rows
capabilities.sh --check   rc 0   (twice, consecutively)
inventory.sh --check      rc 0
queue.sh --check          rc 0
adapter-test.sh           the mouth holds (6/6)
```

Two advisories remain and are named rather than buried: `learn-home.sh` and `mail-scan.sh` are doors
with no feature row of their own. Naming them is a follow-up, not a red gate.

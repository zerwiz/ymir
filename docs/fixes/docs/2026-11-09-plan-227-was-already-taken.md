# Plan 227 was already taken: the near-loop plan is 229, and every door now says so

**2026-11-09 · component: docs · plan 229 · `bin/model/catalog.sh` · `bin/seat/*` · `apps/hlidskjalf` · `apps/odrerir` · the galdr assets**

## What happened

The near-loop plan (`227-near-loop-fleet-wide.md`) was created with `ymir_plan`, which numbers
after the **local** index's highest — and the home had not been pulled. Origin already carried
**227** (Skírnir the delegate) and **228** (the fix order). The home push therefore collided on
the plans `README.md`, two rows appended at the same place under two different plans.

Rule (elder · ledger): a plan number is never reused, and a door must never cite a plan that
belongs to another hand.

## What was done

- The record was renamed to **229-near-loop-fleet-wide.md**, its heading corrected, and a
  dated **Correction** section appended to it naming the collision — appended, never rewritten
  over, exactly as Rule 06 asks.
- The ledger `README.md` carries the row in number order: 225 · 226 · 227 · 228 · **229**.
- Every citation was renumbered with it: `bin/model/catalog.sh`, `bin/seat/core-four.sh`,
  `bin/seat/tests/test_doors_fleet_path.sh`, `bin/seat/INDEX.md`,
  `apps/hlidskjalf/server/index.ts`, `apps/odrerir/src/components/NearBoard.tsx`,
  `docs/features/near-loop.md`, the three fix notes of this change, and the galdr assets
  (`hlidskjalf-ui.md`, `odrerir-hall.md`, the seat capability register).

Nothing behavioural changed: the test still runs, and the doors behave as the fix notes say.

## The lesson this earns

`ymir_plan` numbers from the **local** ledger. A seat that has not pulled will take a number
that belongs to another hand, and the collision only appears at push time — after the number
has been written into code comments, tests and notes. Pull the home **before** taking a number;
the tool cannot know what this seat has not fetched.

## Proved

- `grep -rn "plan 227\|Plan 227" bin apps docs .agents` → only historical records that
  legitimately belong to plan 227 itself; nothing of this change cites it.
- `bin/seat/tests/test_doors_fleet_path.sh` → **9 ok / 0 fail** after the renumber.
- The ledger index reads 225 · 226 · 227 · 228 · 229 in order, one row per plan.

## CHANGE LOG

- **2026-11-09** — plan renumbered 227 → 229 after the home pull exposed the collision; row
  reordered in the ledger index; all citations renumbered.

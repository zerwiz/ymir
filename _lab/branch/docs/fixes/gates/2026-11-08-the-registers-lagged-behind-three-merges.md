# gates · 2026-11-08 — three registers lagged behind three merges, and main was red

## What was wrong

`bin/gates/inventory.sh --check` on `origin/main` at `a25128bb` reported three folder indexes stale:

```
inventory --check: bin/forge/INDEX.md is STALE — run bin/gates/inventory.sh
inventory --check: bin/mail/INDEX.md is STALE — run bin/gates/inventory.sh
inventory --check: bin/vault/INDEX.md is STALE — run bin/gates/inventory.sh
```

The rows that had moved were other hands' work, merged the same evening: `bin/mail/ledger.sh`
243 → 279 lines and `bin/mail/connect.sh` newly named (PR #594, the connect door), a vault door whose
`--stdin` / `--set-del` verbs changed its count (`bin/vault/INDEX.md`), and a forge door whose caller count
moved (PR #592). Every one of those branches had regenerated its own folder's index; none of them could see
the others, and each merged inside a few minutes of the last.

## Why it happens, and it is structural

A folder index is **generated from the whole folder** by `bin/gates/inventory.sh`, and a branch regenerates it
against the tree it can see. So:

- a branch that changes `bin/mail/` but not `bin/vault/` still writes `bin/mail/INDEX.md` from a tree where
  another hand's vault change is invisible;
- a **merge of main into a branch** brings that hand's files in without re-running the generator, so the
  index that was current at push time is stale at merge time;
- `inventory --check` is a whole-tree comparison, so the drift lands on `main` and turns the gate red for
  everyone behind it.

Measured the same evening, three times: this branch regenerated its registers after the first rebase, after
the second, and after the merge of `main` — and each time a *different* folder was the stale one. The drift is
not anyone's carelessness; it is the cost of a whole-tree generator behind a per-branch gate.

## The mend, and the rule it leaves

- Regenerated all three with `bin/gates/inventory.sh`; `--check` is current (35 index files, 854 doors).
- **The rule:** a generated register is regenerated **again after every merge of `main` into a branch**, not
  only after the change that made it necessary — because the merge is what makes the neighbour's rows land.
  The push ward already refuses a branch that is behind `main`; this note adds that the refusal is the
  moment to re-run the generator, in the same breath as the rebase.
- The gate itself is unchanged. Widening it (regenerating inside the guard) would hide a merge from the
  person making it, which is the fault the ward exists to expose.

## Files

- `bin/forge/INDEX.md` · `bin/mail/INDEX.md` · `bin/vault/INDEX.md` — regenerated, never hand-edited.

## CHANGE LOG

- **2026-11-08** — First note: the measured staleness on `main` at `a25128bb`, the structural cause (a
  whole-tree generator behind a per-branch gate, and a merge that brings a neighbour's rows in without
  re-running it), the regeneration, and the rule that goes with it.

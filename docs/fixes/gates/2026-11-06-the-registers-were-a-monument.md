# The registers were a monument, and the driver pointed at a worktree that was gone

**Date:** 2026-11-06 · **Component:** gates · **Doors:** `bin/gates/inventory.sh`, `bin/gates/capabilities.sh`,
`bin/gates/seat-woven-driver.sh` (new), `bin/engine/ymir-install.sh`

## What was wrong

Two registers were one file each, rewritten whole on every change anywhere in `bin/`: `bin/README.md` (786 lines) and
`.agents/assets/agents/capabilities.md` (732 lines). Every branch that added one script rewrote the same lines in the
same sorted position, so **five of the six open PRs were `CONFLICTING` with `main` at the same moment** — measured:

```
#556 CONFLICTING | #552 CONFLICTING | #557 CONFLICTING
#560 MERGEABLE   | #558 CONFLICTING | #562 CONFLICTING
```

The intended cure was already declared and already written, and never ran. `.gitattributes` marks four documents
`merge=regenerate`; `bin/records/regenerate-on-merge.sh` implements the reweave; and the value git actually had was:

```
merge.regenerate.driver = bash "~/ymir/.yggdrasil/merge-534/bin/records/regenerate-on-merge.sh" %O %A %B %L %P
```

**It pointed into a worktree that no longer exists.** A merged errand took the driver's own path with it, so from that
day every reweave was a missing file and every conflict was a plain text conflict over a 786-line document.

## The mend

1. **The registers are a tree.** `inventory.sh` writes `bin/INDEX.md` plus `bin/<folder>/INDEX.md` for every folder,
   and `bin/README.md` is a front door of **folders only** (name, count, purpose, link). `capabilities.sh` writes
   `.agents/assets/agents/capabilities/<folder>.md` and a front door that keeps the five sections. Measured after:
   `bin/README.md` **786 → 66 lines** with 34 indexes; `capabilities.md` **732 → 137 lines** with 31 fragments; the
   capability verdict counts are unchanged (`tested` 353 → 352, `tested+named` 306 → 306 — one door moved because the
   inventory row it reads was itself edited in this change).
2. **The folder purposes live in one file** — `bin/gates/registers/folders.tsv`, one line each — never in generated
   text, so a purpose is edited once and a missing folder renders `(no purpose recorded)` rather than inventing one.
3. **The driver is seated, and proved.** `bin/gates/seat-woven-driver.sh` seats `merge.regenerate.driver` to *this*
   checkout and `--prove` builds a scratch repo, marks a file `merge=regenerate`, makes two branches change it and
   asserts the merge ends with the driver's own mark:
   `proved: the driver ran on a real conflict and rewrote the document`. The install step `gates` seats it and Eir
   reports `woven-driver`.
4. **Every consumer learned the tree:** `capabilities.sh`'s verdict map now reads `bin/INDEX.md bin/*/INDEX.md` (it
   would otherwise read a front door with no rows and call every door untested); `usage-ratchet.sh` counts across the
   fragment directory; `fixes-guard.sh` and `secret-guard.sh` name the fragments; `regenerate-on-merge.sh` reweaves
   the tree; `.gitattributes` keeps the front doors on the driver and lets a **fragment** take an ordinary merge,
   because a conflict inside one folder is two hands in the same folder and worth resolving by hand.

## Verified

```
bin/gates/inventory.sh --check     → current — 34 index file(s), 801 bin doors
bin/gates/capabilities.sh --check  → current (51 door rows)
bin/gates/seat-woven-driver.sh --prove → proved: the driver ran on a real conflict
bin/gates/checks/usage-ratchet.sh  → the pile is unchanged (no new unused doors)
```

## Owed

- The fifteen colliding plan numbers, disambiguated in the ledger index (plan 211 §8).
- The six PRs are still open; they must be rebased on this once it lands, because they were built against the
  monolith.

## CHANGE LOG

- **2026-11-06** — Written with the split. The stale driver path (`merge-534`) is the finding that explains why a
  declared mechanism never healed anything.

# The plan ledger law (assets of the elder skill · Reginn)

## The canonical shelf

The ymir project's plans live in **exactly one ledger**:

```
$YMIR_HOME/svartalfaheim/<realm>/workspace/<project>/plans/
  README.md          # the index — domain map + every plan as a row
  <NN>-<slug>.md     # one file per plan, numbered after the index's last
  <domain>/...       # some plans keep their domain folder (core/, mesh/…)
```

For the operator's own setup (realm `whynotproductions`, project `ymir`):

```
svartalfaheim/whynotproductions/workspace/ymir/plans/    # plans 01–42
```

## Retired shelves — never write here

- `$YMIR_HOME/memory/plans/` — retired 2026-09-22 (the 2026-09-17 layout
  teaching pointed here; it was wrong).
- `hodd/docs/plans/` (any tree) — retired 2026-09-22; the public-tree mirror
  was folded into the ledger and deleted.
- `hodd/plans/` is NOT the ledger — it holds live PERSONAL working plans only
  (omarchy/…), never ymir project plans.
- A plan that exists only in a worktree or a seat copy is not in the ledger.

## Numbering

- A new plan takes the next integer after the ledger index's highest number
  (ymir: 42 → 43). Numbers are never reused; a renumbered plan records the
  move in the README row (e.g., federation 29 → 42) and in the runes.
- The README index gains a row with: number · title · path · status.

## The reconciliation discipline (Part 0)

A new plan that touches ground the elders already hold must open with
**Part 0 — Reconciliation with the elders**:

1. Read the highest relevant plan numbers FIRST (37 fleet-data-sync, 39
   one-well-fold, 36 tailnet, 09/25–27 A2A lineage, 02 well, 14 ingress,
   31 agent-start, 42 federation …).
2. Name in Part 0: which elder is extended, which is consumed as designed,
   which is deliberately superseded — and why (a correction is a new entry
   citing the old, per the append-only law).
3. Mine the elders for ideas before inventing; record what was mined and from
   where (their "done when" and "guards" are the best seams).

## Replacements

A plan is amended by a NEW numbered plan or an appended dated section, never by
rewriting it. Fix notes (`docs/fixes/<component>/`) stay one-file-per-fix and
are never rewritten — corrections supersede, they do not erase.
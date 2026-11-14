# forge · 2026-11-14 — the gather merges a branch's base first

**Component:** forge · **Plan:** 293 part 7 · **Branch:** `eindri/gather-reads-base`

## The fault

`bin/forge/gather.sh` merged the errand branches in the order they were typed. A worker that built on
another worker's unmerged branch — `kaia-to-volundr` on `smidja-header-chat`, `leak-health-view` on
`leak-ledger` — was merged before its base whenever the base was named later, so the base's commits
could land twice or conflict. The packet already carried a `base` field, but nothing read it, and no
field could say "my base is a branch, not `origin/main`".

## What changed

- **`bin/forge/gather.sh`** gained `base_branch_of` and `order_by_base`. For every errand it reads
  `state/handoff/<id>.packet`, takes the `base` cell, and treats it as a base branch only when it
  names a local branch that is not yet reachable from `origin/main`. A stable sort then puts that
  base before the branch cut from it, however the branches were named on the command line. A cycle
  keeps the order given rather than dropping work; a base of `main`, `origin/main` or a bare sha
  needs no reordering.
- **`bin/forge/handoff-packet.py` and `schemas/handoff-packet.toon`** now say that `--base` may name
  a branch (`eindri/<id>`) when the smith was cut from an unmerged branch; the writer already stored
  the argument verbatim, so this is the contract being made explicit.

## Proof

`bin/gates/tests/test_gather_orders_by_base.sh` builds a temp repository whose dependent branch is
named first on the command line and whose packet names its base branch, and proves the dry-run orders
the base before the dependent (and that a base on `origin/main` needs no reordering). Two checks
pass.

## Not done, named

- The gather orders the base only when it is named in the same call (or as another errand). It does
  not silently add a base branch that was never named; the helm still names every errand.

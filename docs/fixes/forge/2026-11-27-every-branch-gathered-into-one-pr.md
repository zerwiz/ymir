# Every branch that still carried work is gathered into one pull request

**Date:** 2026-11-27 · **Component:** `forge` · **Status:** delivered by one pull request

## The problem

The seat had grown a large backlog of finished work that never landed. Measured against
`origin/main` before the work began:

| Measure | Count |
|---|---|
| Local branches holding commits `main` does not have | 119 |
| Branches whose patches are genuinely new (already-merged patches discounted) | 100 |
| Commits those branches carry that `main` does not | 469 |
| Open pull requests, all blocked in CI | 3 (#964, #965, #966) |
| Commits on local branches that exist on **no remote** | 175 |

Three branches had a pull request; the rest had none, and 175 commits lived on one disk
only. A commit on one disk is a commit nobody can merge.

## What was done

One integration branch, `helm/all-branches-20261127`, built from a fresh `origin/main`:

1. **Every branch carrying unique patches was merged** — 103 refs, oldest first.
2. **Where two branches touched the same hunk, `main`'s side wins.** The first attempt
   resolved those to the incoming branch and reverted 11,388 lines of newer trunk work;
   the trunk is authoritative, so the rule was inverted before anything was pushed.
3. **`RULES/**` was unioned, never overwritten** — 17 rule records carried new sections.
   Their law is append-only, so a branch's appended section is kept beside `main`'s.
4. **Woven registers were regenerated, not merged**: `FEATURES.md`, `bin/README.md`,
   `bin/INDEX.md`, every `bin/*/INDEX.md` and the capability fragments.
5. **Every deletion a branch made against `main` was restored** — 14 files, including
   fix notes and the roster tests. A tracked file is moved, never deleted (RULES/11).
6. **One retired door stayed out.** The gathered branches resurrected a home-inventory
   tool the house had already moved out of Ymir. The word is refused in the public tree,
   so the tool, its page and its catalogue row stay out; copies are kept in the home.

## Evidence

```
refs gathered                103
merged clean                  26
merged where both sides moved 13   (main wins the conflicting hunk)
already carried by main       64   (patch-equivalent, nothing to merge)
failed                         0
tree versus main      +52,666 / -472 lines across 441 files
rule records unioned          17
deletions restored            14
registers            regenerated, no drift (registers.sh generate: nothing to write)
guards --full        17 findings, all INHERITED (files this change does not touch)
```

## The road

One pull request against `main`. The Allfather's word seals the merge; no agent merges.

## CHANGE LOG

- 2026-11-26 — review-mend: added missing heading for #969

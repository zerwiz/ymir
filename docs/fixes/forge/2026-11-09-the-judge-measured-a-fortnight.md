# forge · 2026-11-09 · The judge measured a fortnight

## What

`bin/forge/review-seat.sh ask` prompted the judge with "Fetch its head, run the rules floor and the gates
YOURSELF here" — and the judge did exactly that. It fetched the PR's head. **Nothing refreshed the base.**

The judge measures `origin/main...HEAD` in a long-lived clone at `~/review/ymir`. On the night of
2026-11-09 that clone held `origin/main = eb6fe53a` while the remote was `ef684f00`. Every judgement
therefore compared the PR against a fortnight-old base, and the range swallowed every document merged in
between. The verdicts said:

```
RED GATE — rules-compliance-guard.sh (RULES/06 · append-only), 37 findings:
Missing CHANGE LOG section (20 new documents):
  1. bin/collab/kit/docs/notices.md
  2. docs/features/atomic-releases.md
  ... none of them in the PR under review
```

Thirty-three consecutive REFUSEs (#567–#616), each naming work that was already on `main` and nothing
about the branch — and `bin/forge/ship.sh` refuses on a refusal, so nothing merged. The loop was working
exactly as designed against a measurement that was wrong.

## Why

A clone is not a snapshot. It is a checkout that is only as current as its last fetch, and the door that
seats the judge never fetched it. The head was fetched because the prompt said so; the base was assumed
because nobody said otherwise — which is RULES/49's fault in a different costume: an assumption that the
other side is current.

## The fix

`review-seat.sh ask` now fetches the base before it prompts, and refuses if it cannot:

```bash
git -C "$clone" fetch --quiet --prune origin '+refs/heads/*:refs/remotes/origin/*' \
  || refuse "the clone at $clone could not fetch origin — a verdict on a stale base is a wrong verdict"
```

The prompt carries the base sha it fetched, so the verdict's "Base: origin/main" line can be checked against
what was actually measured.

## Proof

Before: `clone origin/main = eb6fe53a`, remote `ef684f00`.
After `review-seat.sh ask 616`: `clone origin/main = ef684f00`, identical to the remote — and the judgement
of #616 runs against the tree the PR will actually merge into.

## CHANGE LOG

- 2026-11-18 — review-mend: added missing heading for #817

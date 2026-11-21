# forge · 2026-11-21 — the judge's second rework: no carried text, the repos variable, the hand-off that ends

## What this answers

The judge reviewed the PR that makes its approval merge at once, at head `be433e6632fd`, and asked for three
fixes. The full account of each is the addendum in
`docs/fixes/forge/2026-11-21-the-judges-rework-kept-repos-one-head-carry-over.md`.

| # | Fault | Fix | File |
|---|---|---|---|
| 1 | An added `## CHANGE LOG` heading, or a new Markdown file, carried the approval to a merge | Only lines below a heading the approved head already had carry; added files and added `## ` lines never do | `bin/forge/judge-carry.py` |
| 2 | With `YMIR_REVIEW_REPOS` set, the keeper exited `no kept repository is left to watch` | The variable is read before the keep filter | `bin/forge/review-watch.sh` |
| 3 | An expired hand-off was re-typed into a seat's pane every hour, forever | The PR's judge comment is read first; a head is re-handed at most twice, then one wake | `bin/forge/review-watch.sh` |

## Proof

`bash bin/forge/tests/test_judge_merge.sh` → `judge-merge: 64 passed, 0 failed`.

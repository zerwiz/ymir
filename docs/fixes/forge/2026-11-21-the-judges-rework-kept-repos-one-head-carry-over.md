# forge · 2026-11-21 — the judge's road, reworked: kept repositories, one head one judge, the approval that carries

## What this answers

The judge returned NEEDS-REWORK on the PR that made the judge's approval merge at once. The helm added three
findings of its own. This note records that rework. The full table of faults and fixes is the addendum in
`docs/fixes/forge/2026-11-21-the-judges-approval-merges-at-once.md`, so it is not repeated here.

## Files

- `bin/forge/warden-policy.py` — `operator-logins`, `kept` and `keeps`: the operator's logins and the kept repositories, read from the home
- `bin/forge/review-watch.sh` — the keeper watches only kept repositories; markers carry the repository; an unacted hand-off expires; the hand-off names the clone
- `bin/forge/judge-merge.sh` — no comment, wake or merge where it may not merge; APPROVE needs `judged-head:`; the house wake format; the approval carries
- `bin/forge/judge-carry.py` — new: may an approval carry from one head to a newer one
- `bin/agents/pr-seal.sh` — the hand is compared with the operator's logins, never the repo slug's owner
- `bin/agents/eindri-review-spawn.sh` — the PR-only id carries the repository; every road shares one per-head marker in the home's state
- `.agents/tests/eindri-review-spine.test.sh` — fenced: `YMIR_NO_INJECT=1`, a fake `herdr`, a temp home
- `bin/forge/tests/test_judge_merge.sh` — 53 cases

## Why

- The keeper commented on an upstream repository the house only tracks.
- Every organisation repository was refused as the wrong identity, with a comment on each head.
- Approvals died when an automation pushed a base merge or a change-log commit after the judge approved.
- A test suite typed four times into the real helm's pane.

## Proof

- `bash bin/forge/tests/test_judge_merge.sh` → `judge-merge: 53 passed, 0 failed`
- `bash .agents/tests/eindri-review-spine.test.sh` → `ALL PASS`

## Addendum — the second rework (judge's review at head `be433e6632fd`)

### 1 · a change log can no longer carry text the judge never read

The judge found that `bin/forge/judge-carry.py` accepted a `## CHANGE LOG` heading added after the approval, and a
whole new Markdown file. Either let unjudged text ride the approval to a merge. The probes were a line asking the
judge to approve, appended under a new heading in `.agents/assets/templates/review-brief.template.md`, and a new
`sub/CLAUDE.md`. Both printed `carries`.

A change-log commit now carries only when every file it touches:

- is modified, never added or deleted;
- already had a `## CHANGE LOG` heading in the approved head's copy;
- loses no non-blank line and gains no `## ` heading line;
- gains non-blank lines only below that heading.

> [!NOTE]
> An automation that adds the first `## CHANGE LOG` section to a file now needs a new judgement. That is the
> intended price: a section the judge never saw cannot be opened after the approval.

Proof: `bash bin/forge/tests/test_judge_merge.sh` adds cases (f) to (i), both probes among them.

### 2 · the keeper reads `YMIR_REVIEW_REPOS` before it filters

With the keeper on and `YMIR_REVIEW_REPOS` set, `bin/forge/review-watch.sh` ran the keep filter while `REPOS` was
still empty. It then exited with `no kept repository is left to watch`, rc 1, even for a kept repository. The list
is now filled from `YMIR_REVIEW_REPOS` before the filter, and a repository that is not kept is still dropped by name.

Proof: `bash bin/forge/tests/test_judge_merge.sh` case 13b, one kept and one upstream repository.

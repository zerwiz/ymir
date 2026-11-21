# forge · 2026-11-21 — the judge's third rework: text from a stranger is never trusted

## What this answers

The judge reviewed the PR that makes its approval merge at once, at head `0d69979660aa`, and asked for one
fix. It was a trust hole. The repository is public, so anyone can open a PR or comment on one. Text written
by someone who is not the operator must never change what the house does.

A search of the rest of the PR found one more place with the same fault. Both are fixed below, each in its
own commit.

| # | Fault | Fix | File |
|---|---|---|---|
| 1 | `judged_on_pr` read every comment body, whoever wrote it. A stranger's comment `The judge approved head <12>` marked the head judged and took it out of review for good | The keeper reads the author with each body. A match counts only from a login that `warden-policy.py operator-logins` prints, the same rule `pr-seal.sh` uses for the merge hand | `bin/forge/review-watch.sh` |
| 2 | `wake_author` took the `Arm: <host>` line from the PR body, whoever wrote it. A stranger's PR could send the judge's rework hand-off to any seat of the fleet | The line counts only when the PR's author is an operator login. Otherwise the rework stays with this machine's arm holder. The branch name in the hand-off line is kept to ref characters | `bin/forge/judge-merge.sh` |

## What was checked and left alone

- `bin/forge/judge-carry.py` judges the commits after an approval by their content (clean base merges and
  change-log lines). It never reads a commit message.
- The squash subject in `pr-seal.sh` uses the PR title. That only happens after the judge has approved the
  head, so the title has been reviewed along with the rest of the PR.
- The `hold` label only stops a merge, and only people with triage access can add labels.

## Proof

`bash bin/forge/tests/test_judge_merge.sh` → `judge-merge: 66 passed, 0 failed`.

Test 15c's fake `gh` now answers only the author-and-body query, and returns the operator's login. Test 15d
shows that the same words from a `stranger` login are ignored and the head is handed on again. A new case
in test 6 shows that a stranger's `Arm:` line does not reach the arm wire. Each new test fails on the code
from before its fix.

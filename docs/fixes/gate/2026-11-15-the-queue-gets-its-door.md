# Fix — the gate listens to the merge queue

**What was wrong.** Nothing merged on 2026-11-15 with nine pull requests open, and the cause was arithmetic, not
laziness. Branch protection requires `whole-tree` **and** that a branch be up to date with `main`. The gate takes about
nine minutes. `main` moves every time anything merges. So a pull request is stale before its own gate has finished, and
must be rebased — which re-runs the nine minutes — which makes it stale again. The Allfather's own words:
*"why dont you have this fucking under controll"*. He was right, and no amount of hand-merging fixes arithmetic.

**What was done here.** One thing: the gate now listens to `merge_group`, which is the event a merge queue sends.

```yaml
on:
  pull_request:
  merge_group:
    types: [checks_requested]
```

Without it a queue waits forever for a required check that never arrives — the documented configuration fault — so this
had to land **before** the queue is switched on, never after.

**And the concurrency key already handled the second trap**: a queue run carries no pull-request number, so the group
falls back to `github.ref`, which is the entry's own `gh-readonly-queue/...` ref. Keying only on the (empty) PR number
would put every entry in one group and cancel the entry ahead of it — the other documented way to make a queue useless.

**What happens next (not this change).** Switch `main` to a ruleset with a merge queue instead of "require branches to be
up to date". Then one run per pull request, on the base it will land on, and the serialised hand-rebase stops. The
numbers from the practice of this year are consistent: a queue costs one CI run per pull request and removes the O(N²)
rebase cascade that strict mode creates on a busy base.

**Proof this is the door and not a guess.** `bin/gates/ci-verify.sh` is unchanged — the queue runs the same one command;
only the event that triggers it is new. The next queue entry will show its run against a `gh-readonly-queue/...` ref.

## CHANGE LOG

- 2026-11-18 — review-mend: added missing heading for #817

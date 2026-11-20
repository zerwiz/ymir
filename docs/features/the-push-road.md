# The push road — what a push costs, and how to keep work safe

A push from this repository runs the pre-push hook (`.githooks/pre-push`). This page explains what it
judges, how long it should take, what to do when it refuses, and the survival push that keeps work
off a single disk. The fix note is
`docs/fixes/gates/2026-11-20-the-push-road-costs-seconds-not-a-quarter-hour.md`.

## What it is

The hook is the fast filter in front of CI. It judges what the push **adds**, and nothing else:

- the commits since the branch left `main` (the fork point), not what `main` changed since;
- commits only: untracked and uncommitted files are not in a push, so they are not judged;
- the cheap refusals first, so a stale base or a protected branch is said in a tenth of a second;
- the tree wards in parallel, inside a budget that is a wall: a ward still running when it ends is
  `DEFERRED` to CI, never passed;
- one judgement per commit: a sha the hook already passed is stamped and not judged twice.

CI still runs every ward over the whole tree (`bin/gates/guards.sh --full`) on every pull request.

## What a push should cost

| Push | Expected |
|---|---|
| an ordinary branch, wards pass | about 10 seconds |
| the same sha again (a retry, or a gathered head pushed after `--no-pr`) | under a second |
| a stale base | refused in under a second |

The hook prints a timing table, slowest stage first, and the total against the push budget. A push
over the budget names its slowest stage.

## The commands

| Command | What it does |
|---|---|
| `bash bin/gates/guards.sh --profile` | every ward's time, slowest first (the working tree, as a person runs it) |
| `YMIR_GUARD_PUSH=1 bash bin/gates/guards.sh --profile` | the same, judging commits only, as the hook does |
| `YMIR_PREPUSH_REJUDGE=1 git push` | judges a stamped sha again |
| `python3 bin/gates/guards/public-guard.py --mask <path>:<line>` | masks the refused mailbox on that line as `<a personal address>` |
| `bash bin/forge/exec-bits.sh --fix` | sets the executable bit on every new door, in the index |
| `bash bin/forge/park.sh <errand>` | the survival push (off until configured, see below) |

## The settings

| Variable | Default | Meaning |
|---|---|---|
| `YMIR_PREPUSH_BUDGET` | 60 | seconds the tree wards may spend |
| `YMIR_PUSH_BUDGET` | 180 | seconds the whole push may spend before its slowest stage is named |
| `YMIR_GUARD_JOBS` | 8 | wards run at once |

## When a push is refused

- **The base is stale.** Rebase onto `origin/main` and push again. A batch gathered by
  `bin/forge/gather.sh` catches its base up by itself: a base that moved is merged in, not refused.
- **A mailbox.** The ward names the file and line, and prints the `--mask` command to paste.
- **A new door is not executable.** Run `bash bin/forge/exec-bits.sh --fix` and commit. Every errand
  brief now runs it before the last commit.
- **A finding prints `INHERITED`.** It names a file the push did not touch. It never blocks; CI
  reports it on the pull request.

## The survival push (parking)

`bin/forge/park.sh <errand>` pushes your commits to `refs/parked/<errand>`. That is a ref, not a
branch: no pull request opens from it and nothing merges from it. Only the privacy wards judge it
(secret, public-data and the NDA gate), so it is quick, and what may never be published still is not.

| Command | What it does |
|---|---|
| `park.sh <errand>` | parks `HEAD` |
| `park.sh <errand> --dry-run` | says what it would park |
| `park.sh --list` | the parked refs on the remote |
| `park.sh --restore <errand>` | brings a parked ref back as `eindri/<errand>` |
| `park.sh --drop <errand>` | deletes it once the work has shipped |

> [!IMPORTANT]
> Parking is **off** until the operator names a remote for it: `PARK_REMOTE=<remote>` in
> `$YMIR_HOME/config/park.env`. Until then `park.sh` exits 3 and the hook refuses `refs/parked/*`.

## Limits

- The stamp lives in the local git directory. A push from another clone is judged in full.
- A ward that is cut off by the budget is not a pass. CI runs it.
- Parking keeps commits, not uncommitted changes.

## If it does not work

- Is the hook seated? `git config core.hooksPath` should print `.githooks`. If it prints nothing,
  the checkout runs a copy in `.git/hooks/pre-push`, which may be old.
- Run `bash bin/gates/checks/push-road.test.sh`. It proves each behaviour above in a throwaway clone.

## CHANGE LOG

- 2026-11-20 — added (plan 339.1).

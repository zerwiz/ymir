# gates · 2026-11-20 — the push road costs seconds, not a quarter-hour

Plan 339, phase 339.1. On 2026-11-20 one push took over thirteen minutes and failed on four wards:
a missing executable bit, a stale base, `home-contract-guard`, and an old mailbox in a fix note.
Three finished branches never left the machine. This note records what was measured, what was
wrong, what changed, and the timings before and after.

## What was measured

Every stage of `.githooks/pre-push` was timed on two of that day's errand branches, on the dev
machine, with the ward cache off so the numbers are the real cost:

- a **current** branch: 3 files of its own, 8 commits behind main;
- a **stale** branch: 16 files of its own, 30 commits behind main, in a worktree holding 3,000
  untracked scratch notes (the busiest live worktree on the machine held 4,719).

The exact thirteen minutes could not be reproduced. The four faults below explain it: each failed
attempt cost a full ward run before the cheapest refusal was even reached, and the scope grew with
every untracked file and every commit main gained.

## What was wrong

1. **The scope was main's changes too.** `guards.sh` took the changed set as
   `git diff origin/main..HEAD`, a two-dot diff against main's *tip*. On a branch behind main that
   lists every file main changed since the fork. Measured: 209 paths where the branch touched 16.
   A scoped ward is never `inherited`, so a mailbox main had already masked in a fix note came back
   as the push's own finding. That is the "old mailbox in a fix note" of the day.
   `rules-compliance-guard.sh` had the same two-dot range.
2. **Untracked files were judged.** The scope added `git ls-files --others`, though a push carries
   commits only. 3,000 scratch notes cost `agnostic-audit` 40.7 s and 216 false findings.
3. **The budget was a wish.** It stopped the *launch* of new wards; a ward already running ran to
   its end, and the hook waited.
4. **The cheapest refusal ran last.** `branch-current.sh` (0.05 s) was the final stage, so a stale
   base was refused only after the whole suite had run.
5. **The NDA tree ward read whole files.** A file that already carried a protected word on main
   refused every push that touched it, for a line the push never wrote.

## What changed

| File | Change |
|---|---|
| `bin/gates/guards.sh` | The scope is `merge-base(origin/main, HEAD)..HEAD`. The hook sets `YMIR_GUARD_PUSH=1`, so only commits are judged. Each ward runs under `timeout` with what is left of the budget; one cut off is `DEFERRED` to CI. The fork point travels as `YMIR_GUARD_BASE` and `YMIR_AUDIT_BASE`. `defaults-guard` and `weave-guard` join the declared CI-only list with their measurements. |
| `.githooks/pre-push` | The cheap refusals run first (`branch-guard`, `branch-current`, `fixes-guard`, `no-delete`, `identity`). Every stage is timed and printed, with the push budget (`YMIR_PUSH_BUDGET`, default 180 s); a push over it names its slowest stage. A sha this hook passed is stamped in `<git-common-dir>/ymir-gated/`, keyed on the hook and ward-list text, so a gathered head or a retried push is not judged twice (`YMIR_PREPUSH_REJUDGE=1` judges again). A push to `refs/parked/*` takes the parking posture (below). |
| `bin/forge/gather.sh` | `catch_up` fetches before the gates and again before the push. A base that moved is merged into the batch, not refused at the end; a moved base means a new head, which is gated again, at most twice. A conflict stops exactly like an errand conflict. |
| `bin/gates/guards/public-guard.py` | A refused mailbox still names `path:line`, and the help now offers the mend: `public-guard.py --mask <path>:<line>` rewrites only the refused addresses on that line to `<a personal address>`, leaving allowed ones. The command names a line, never the address. |
| `bin/gates/guards/nda-guard.sh` | Handed a base, the ward judges the lines the change adds (and an untracked file whole). Without a base, as in CI's `--full`, every line is judged as before. |
| `bin/gates/guards/rules-compliance-guard.sh` | The range starts at the fork point. |
| `bin/gates/guards/secret-guard.sh` | `--range <base> <head>` judges what a range adds, read from the pushed commit. |
| `bin/forge/exec-bits.sh` (new) | Names a new door without its executable bit; `--fix` sets it in the index, which is what a push carries. |
| `bin/agents/erindi-brief.sh` | Every errand mode's Definition of done runs `exec-bits.sh --fix` before the last commit. |
| `bin/forge/park.sh` (new) | The survival push, **off by default**. See below. |
| `bin/gates/checks/push-road.test.sh` (new), `checks.d/0165-push-road.sh` | Ten proofs in a throwaway clone. |
| `bin/gates/checks/guards-scope.test.sh` | The `inherited` check runs in the push posture. It was red on main before this change, because its untracked probe page was in the hand-run scope. |

## The parking road (designed, not armed)

`bin/forge/park.sh <errand>` pushes `HEAD` to `refs/parked/<errand>`. That is a ref, not a branch:
no PR opens from it, nothing merges from it, and a plain clone does not fetch it. The hook judges a
parked push with the privacy wards only: secret (`--range`), public-data, and the NDA gate, which
belongs to the same family. A parked push and a delivery push cannot share one `git push`.

> [!IMPORTANT]
> The road is off until the operator names where parked refs may go: `PARK_REMOTE=<remote>` in
> `$YMIR_HOME/config/park.env`, or `YMIR_PARK_REMOTE`. With no remote named, `park.sh` exits 3 and
> the hook refuses `refs/parked/*`. Whether parked refs may go to the public repository is plan 339's
> question 2, filed for the Allfather.

## Timings, before and after

Whole hook, cache off, same machine:

| Push | Before | After |
|---|---|---|
| current branch, wards pass | 30.3 s (20 paths judged for a 3-file branch) | 9.6 s (mean of 10.0, 9.6 and 9.4) |
| the same sha pushed again | 30.3 s | 0.2 s (stamp) |
| stale branch, refused for the stale base | 64.1 s, then refused | 0.1 s, refused first |
| stale branch, stale allowed, 3,000 untracked files | 64.1 s, 3,209 paths, 2 false FAILs | 18.9 s, 16 paths, no FAIL |
| a 3 s ward budget | waits for the slowest ward (25.7 s) | 5.5 s, overrunners `DEFERRED` |

### The slowest five wards

Before, on the current branch: `defaults-guard` 25.7 s · `weave-guard` 18.9 s ·
`unit-writer-guard` 8.6 s · `model-rows-guard` 7.2 s · `features-guard` 6.5 s.

Before, on the stale branch with untracked files: `agnostic-audit` 40.7 s · `public-data-guard`
23.2 s · `defaults-guard` 15.1 s · `weave-guard` 12.1 s · `unit-writer-guard` 5.2 s.

After: `unit-writer-guard` 6.1 s · `model-rows-guard` 5.1 s · `features-guard` 4.6 s ·
`subsystem-docs-guard` 4.4 s · `path-ledger-guard` 4.3 s. No ward is over the 10 s line.

## Still owed

- The main checkout on the dev machine has no `core.hooksPath`, so its `.git/hooks/pre-push` (shared
  by every worktree there) is a copy from 2026-11-03. It lacks the NDA, maker and identity stages and
  every change above. Seating `git config core.hooksPath .githooks` there, which is what the install
  step does, is the helm's act, not an errand's.
- The accept line of 339.1 (a parked ref survives a reboot) waits on the answer to question 2.

## Proof

```text
bash bin/gates/checks/push-road.test.sh   → push-road-test: 10 pass, 0 fail
bash bin/gates/checks/guards-scope.test.sh → guards-scope-test: 7 pass, 0 fail
bash bin/gates/checks/public-data-ward.test.sh → public-data-ward: all cases behaved
```

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #853

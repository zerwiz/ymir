# Fix — the session digest sees the work that finished and never landed

**What was wrong.** The session-start digest said nothing about branches that were pushed and never
became a pull request, and nothing about commits that exist on no remote. On 2026-11-14 an audit of
36 agent panes found 22 worker branches pushed, clean, with fix notes — and only four merged, because
nothing gathered them. The same audit found 19 commits on one machine's local `main` that existed on
no remote at all: one disk away from being lost. Both facts were invisible at every session start,
so the house repeated the loss instead of seeing it.

**What was done.** A new door, `bin/time/saga-land-warnings.sh`, answers two questions and prints
them as one `landing[]` block:

- **no-pr** — a worker branch (`eindri/*`, `agent/*`, `claude/*`) that is pushed, older than four
  hours, and carries no pull request, or a pull request that was closed without a merge. Each is
  named with its age and with the command that would gather it.
- **unpushed** — commits that exist on no remote, counted once, with the local branches that hold
  them and how many each holds.

`bin/time/saga-session-start.sh` runs it in a new `LANDING` section.

**How it stays honest and cheap.** It is read-only: nothing is fetched, pushed or written. It
measures `refs/remotes/origin` as they stand, filters by the tip commit's date before any other work,
takes the set of already-merged branches in one `for-each-ref --merged` read, and asks `gh` once — with
a deadline — for the PR state of every branch. A branch already merged into `origin/main` is never
warned about. Offline it prints `PR state unread` and never claims a branch has no PR: a question
nobody answered is not evidence. The whole door is under four seconds here, and it says so when a
checkout has no `origin` or no base branch rather than claiming a clean hall.

**How it is proved.** `bin/time/tests/test_saga_land_warnings.sh` builds a planted repository — a bare
origin and a clone — with a branch pushed nine hours ago and no PR, a branch pushed now, a branch
carrying an open PR, a branch already merged, and a local branch with two commits on no remote. It
asserts each warning appears and each silence holds, that the offline path says `PR state unread`
inside its bound, and that the digest actually calls the door. It runs in CI as the `landing` gate.

**Files.** `bin/time/saga-land-warnings.sh` (new), `bin/time/saga-session-start.sh`,
`bin/time/tests/test_saga_land_warnings.sh` (new), `bin/gates/ci-verify.sh`,
`docs/features/saga-the-session-start.md`.

## Change log

- **2026-11-14** — written with plan 293 part 3.

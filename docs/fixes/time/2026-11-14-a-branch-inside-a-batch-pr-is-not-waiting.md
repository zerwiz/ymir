# Fix — a branch carried inside an open batch PR is not waiting

**What was wrong.** The new LANDING warning (same day, `2026-11-14-the-digest-sees-what-never-landed.md`)
called a pushed branch with no pull request of its own "pushed, no PR, not merged". But a **gathered
batch** works exactly that way: `bin/forge/gather.sh` merges each errand's branch into ONE batch branch
and opens ONE pull request for all of them. So the errand's own head has no PR, and the digest named
four branches as lost work while they were riding inside open batch PRs — measured live by the helm on
the first run, across `#750`, `#755` and `#757`.

A warning that cries wolf on the ordinary batch road is worse than no warning: the helm learns to
ignore the section.

**What was done.** The door now distinguishes the two cases:

- it keeps the pull-request state it already asks `gh` for once, and takes the heads of every **open**
  PR from that same answer;
- it computes the set of commits those heads can reach **once** — a single `git rev-list` over their
  tips — so a candidate branch costs one lookup rather than a process;
- for a candidate with no PR of its own it asks which open head contains it with one
  `git for-each-ref --contains` read (asked only of the few that are carried);
- such a branch is printed as its own kind, `in-pr`, naming the PR that carries it:
  `eindri/x — 5h: in batch PR #750, not merged yet`, with the action *nothing to gather*.

It stays offline-safe and bounded: with no `gh` answer nothing is claimed and the rows say the PR
state was unread; every git call is still inside the door's deadline.

**Cost.** The first version asked `git for-each-ref --merged` once per open PR and took 12 s on this
tree. The single `rev-list` reachability pass brings the whole door back to **3.9 s** here, and it
prints 28 waiting branches, 4 carried in `#750`, and 181 commits on no remote.

**How it is proved.** `bin/time/tests/test_saga_land_warnings.sh` gained a fixture that plants a
branch, a gathered batch branch containing it, and a `gh` that reports the batch PR open. It asserts
the carried branch is named with `#750` and is **not** also printed as having no PR, that a branch
inside nothing is still reported while a batch PR is open, and that with no open PR at all the carried
branch is (correctly) called waiting. The suite is now 18/18 and runs in CI as the `landing` gate.

**Files.** `bin/time/saga-land-warnings.sh`, `bin/time/tests/test_saga_land_warnings.sh`,
`docs/features/saga-the-session-start.md`.

## Change log

- **2026-11-14** — written after the helm's audit of the first run (plan 293 part 3).

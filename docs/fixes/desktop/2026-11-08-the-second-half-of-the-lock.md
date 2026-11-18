# The second half of the lock: the runtime, not only the launcher

**2026-11-08 · component: desktop**

The Allfather's law — *"the apps run time must be locked to main. otherwise they might break if the user are
swithing threes"* — needed more than the entries. `scripts/{start,raise,electron}.sh` and
`bin/desktop/sessrumnir-launch.sh` now resolve the canonical tree and **re-execute from it** when run inside a
worktree, so Electron, the assets and every service they raise come from main. `bin/desktop/main-tree.sh` is
the resolver (`--check` exits 1 inside a worktree), the ward refuses an installed entry that points into one,
and the Exec writer rewrites such a path and says so.

Verified: `start.sh` run inside the worktree prints *"running from a WORKTREE — the app runtime is locked to
main (/home/zerwizomar/ymir), re-executing there"* and raises the stack from main; the guard reports
*"5 launcher(s), every one seated from a real tree"*.

## CHANGE LOG

- **2026-11-08** — Opened for the runtime half of the lock.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: the heart's user. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).

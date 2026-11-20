# A worktree someone is standing in is not reclaimable — and two wards that blocked every push

**Date:** 2026-10-20 · **Component:** `guard` · **Rules:** 24 (the ward), 07 (nothing guessed)

## 1 · `keep:in-use` — the Allfather's warning, made a law

*"I have one agent working in a worktree also."* The first version of the audit would have
called such a tree `reclaimable:merged` — its commits are on `main`, so nothing would be *lost*,
but the agent's shell would be standing in a directory that no longer exists.

`housekeeping.sh` now asks the kernel before it judges: every live process's `/proc/<pid>/cwd`
is compared with the worktree. A tree someone stands in is `keep:in-use` and is never a
candidate for `clean`, however merged its commits are.

(Measured on this box: the probe finds the shell immediately — `/proc/2247410 → …/thradr/apps/hlidskjalf`.)

## 2 · Two pre-existing ward failures that blocked every push

The pre-push gate refused this branch on faults that arrived from `main` with the Snotra merge —
none of them mine, all of them real:

| ward | finding | mend |
|---|---|---|
| `dead-code-guard` | `now_id()` and `json_get()` in `bin/time/snotra/snotra-store.sh` were defined and never called (Rule 17) | removed |
| `defaults-guard` | `bin/time/snotra/calendar-auth.sh:23` guessed `$HOME/Documents/ymirhome` **one line before** the resolver answered the same question | the guess is gone; an unresolved home now says so and exits |
| `defaults-guard` | `bin/time/snotra/snotra-render-email.sh` guessed the same path inside its Python | asks `bin/vault/hodd.sh path` instead, with a clean failure |

Both wards are green again (dead-code: 308 scanned, 0 findings; defaults: 0 guessed homes).

## 3 · Also in this pass

- `clean --merged-only` — reclaim only work already in `origin/main`; a pushed branch with an
  open PR is kept, because you may still be working in it.
- Two bugs the first REAL run exposed (the fixture could not, since there script and repo are
  the same directory): the act path used the display index instead of the absolute path, so
  nothing was ever removed; and `git branch -d` judges "merged" against the *current* checkout
  (here `feat/snotra-letter`), so branches merged into `main` were refused — `-D` is now used
  only under the ancestor proof the verdict already made.

## Verified

```
.agents/tests/housekeeping.test.sh · 12/12 (fixture repo: merged · pushed · dirty · unpushed)
first real pass: 8 merged worktrees + 8 merged branches reclaimed (5.9 G → 5.5 G)
report: 49 worktrees · 125 branches · 100 reclaimable · 10 unpushed · 5 dirty · in-use honoured
```

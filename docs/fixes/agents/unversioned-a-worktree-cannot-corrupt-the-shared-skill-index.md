## agents · unversioned · 2026-10-18 — a worktree cannot corrupt the shared skill index

### Why

The skill index is **one file in the home** (`$YMIR_HOME/.agents/skills/skills.yaml`),
shared by every checkout on the machine. But `skill-index.sh` and `skill-find.sh`
resolved the `ships`/`local` shelves from `$ROOT` — whichever checkout was
running. Run from a Yggdrasil worktree, that is *the worktree's* shipped skills,
so:

- `--check` reported the canonical index **stale and every canonical skill
  INCOMPLETE** (demonstrated: 31 false "absent" rows from `origin/main` in a
  scratch worktree), and
- two worktrees would each rewrite the one shared file with their own shelf, so
  the index flip-flopped under concurrent agents.

The index's own author found this by running `--check` from a worktree minutes
after the index shipped.

### Now

Both tools resolve the `ships`/`local` shelves from the **canonical checkout**,
via `git rev-parse --git-common-dir` → its parent. A worktree shares the canonical
index instead of fighting it. The home shelves and `~/.pi/agent/skills` are
unchanged (they are machine-scoped, not checkout-scoped).

### Verified

- `.agents/tests/skill-index.test.sh` → **6 passed, 0 failed**; the new assertion
  builds a git repo, adds a worktree, and proves `--check` from the worktree no
  longer calls the canonical index stale (it failed before the mend).
- Live: `skill-index.sh --check` from the worktree of `origin/main` →
  `index fresh: 192 skills` (before the mend: STALE + 31 INCOMPLETE rows).

### Files

- `bin/agents/skill-index.sh`
- `bin/agents/skill-find.sh`
- `.agents/tests/skill-index.test.sh`

# Rule 08 — Delivery Gate & Worktree Engine

## 08.1 Every Change Leaves by Pull Request

**No direct pushes to `main` or any protected branch.** Every change — code,
config, docs, scripts — must:

1. Be done in a Yggdrasil worktree on a feature branch
2. Pass all local gates (lint, typecheck, tests)
3. Be pushed as a branch
4. Opened as a Pull Request via `gh pr create`
5. Reviewed in Glitnir (human review)
6. Approved by the Allfather
7. Merged via the PR interface — **never locally**

A local merge on a verbal "word" is a decision, not a delivery. It leaves
Glitnir with nothing to review. The gate is only fed by a PR.

**Exception:** None. If work is already on local `main`, ship it as a PR (a
branch at that commit) before doing anything else.

## 08.2 Yggdrasil Worktrees Use treehouse

**All worktree operations go through `treehouse`** (github.com/kunchenguid/treehouse).
Never use raw `git worktree` commands directly.

| Operation | Command |
|-----------|---------|
| Create worktree | `bin/yggdrasil.sh create <branch>` |
| List worktrees | `bin/yggdrasil.sh list` |
| Remove worktree | `bin/yggdrasil.sh remove <branch>` |
| Sync worktree | `bin/yggdrasil.sh sync <branch>` |

The `bin/yggdrasil.sh` script is the Norse shell over the treehouse engine.
It handles:
- Branch creation from correct base
- Worktree path management under `.yggdrasil/<agent-id>/`
- Remote tracking setup
- Cleanup on completion

## 08.3 Utgard Sandboxes Use sandcastle

**All untrusted code, dynamic skills, and sub-agent tasks run inside Utgard**
via `sandcastle` (github.com/mattpocock/sandcastle, @ai-hero/sandcastle).
Never run untrusted code on the host.

| Operation | Command |
|-----------|---------|
| Spawn sandbox | `bin/utgard.sh spawn <profile>` |
| Run in sandbox | `bin/utgard.sh run <profile> <cmd>` |
| Destroy sandbox | `bin/utgard.sh destroy <id>` |

Utgard enforces: CPU/RAM/timeout caps, no host root, no network by default.
A failed Utgard execution never touches main.

## 08.4 Enforcement

- **Pre-push hook** (installed by `bin/ymir-install.sh`) rejects direct pushes
  to protected branches
- **CI gate** (`.no-mistakes.yaml` + `no-mistakes` skill) validates PRs before
  merge
- **Mjollnir pipeline** (`bin/mjollnir.sh`) automates issue → worktree → PR

## 08.5 References

- `bin/yggdrasil.sh` — treehouse wrapper
- `bin/utgard.sh` — sandcastle wrapper
- `bin/mjollnir.sh` — issue→PR pipeline
- `.no-mistakes.yaml` — clean-PR gate config
- `RULES/02-agents.md` — agents are canonical, harness dirs are symlinks
- `RULES/05-platforms.md` — core portable, per-OS layers updated together

---

*Append-only. A correction is a new entry citing the old one.*
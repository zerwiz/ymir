# Git Workflow — __PROJECT__

## Branching
- Feature branches named `feat/<feature>-<short-desc>` or `fix/<ticket>`.
- Branches created via `.agents/skills/git_ops/create_branch.sh` (naming + ticket link enforced).

## Commits
- Use `.agents/skills/git_ops/safe_commit.sh` — runs pre-commit gates + formats message.
- Conventional style: `feat:`, `fix:`, `docs:`, `chore:`.
- No bare `git commit -m ...` — always via skill script.

## Merge / PR
- Push via `sync_upstream.sh` (rebase + conflict check).
- PR must pass all gates (`.compliance/gates/*`) and reviewer approval.

## Enforced By
- `.agents/skills/git_ops/` scripts.
- `.compliance/gates/check_platform.sh` (no `pkill`/`taskkill`/raw kill).
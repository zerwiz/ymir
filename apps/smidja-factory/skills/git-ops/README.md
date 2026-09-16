# git-ops/ — WayOf Command

Deterministic Git workflow. All source-control operations run through these scripts to protect repo history and enforce conventions.

## What Goes Here

- `SKILL.md` — Skill guidelines for Git operations.
- `create_branch.sh` — Branch creation with proper naming & ticket linking.
- `safe_commit.sh` — Pre-commit gates + commit message formatting.
- `sync_upstream.sh` — Rebase & conflict checks.

## File Pattern

```
git-ops/
├── SKILL.md
├── create_branch.sh
├── safe_commit.sh
└── sync_upstream.sh
```

## Rules

- Git actions (branching, committing, rebasing) MUST go through these scripts — no bare `git commit -m ...`.
- Pre-commit gates (lint, tests) run inside `safe_commit.sh` before anything is committed.
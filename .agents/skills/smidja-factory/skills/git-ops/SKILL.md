---
name: git-ops
description: Routing for Git operations — create branches, safe commits with gates, and sync upstream. Use when the user needs to create a feature/fix branch, commit with gate validation, or rebase and push. All git operations go through these scripts; never run bare git commands.
---

# SKILL.md — git-ops

Routing for Git operations.

## Scripts
| Command | Script | Usage |
|---------|--------|-------|
| create_branch | `create_branch.sh` | Create `feat/<feature>` / `fix/<ticket>` branch |
| safe_commit | `safe_commit.sh` | Run gates, format message, commit |
| sync_upstream | `sync_upstream.sh` | Rebase + conflict check + push |

## Rules
- Never run bare git commands outside these scripts.
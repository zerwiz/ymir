# SKILL.md — git_ops

Routing for Git operations.

## Scripts
| Command | Script | Usage |
|---------|--------|-------|
| create_branch | `create_branch.sh` | Create `feat/<feature>` / `fix/<ticket>` branch |
| safe_commit | `safe_commit.sh` | Run gates, format message, commit |
| sync_upstream | `sync_upstream.sh` | Rebase + conflict check + push |

## Rules
- Never run bare git commands outside these scripts.
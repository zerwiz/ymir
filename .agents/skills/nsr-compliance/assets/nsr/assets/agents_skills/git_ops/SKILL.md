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

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.

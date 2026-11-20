#!/usr/bin/env bash
# worktree.sh — one task, one worktree, and nothing left behind when it is finished (RULES/17, RULES/24).
#
#   bash scripts/worktree.sh new <id> [--purpose "…"] [--owner who] [--base branch]
#   bash scripts/worktree.sh list [--sizes]
#   bash scripts/worktree.sh done <id> [--salvage]     # after the merge; --salvage saves unfinished work first
#   bash scripts/worktree.sh gc [--apply]              # close every worktree whose work is safe
#   bash scripts/worktree.sh salvage [--apply] [id]    # save a dead worker's work to the remote
#
# The folder and branch names come from project.yaml (names.worktrees, names.branch_prefix).
set -euo pipefail
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kit.py" worktree "$@"

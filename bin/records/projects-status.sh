#!/usr/bin/env bash
# projects-status.sh — every project the user works on: worktrees, PRs, CI, kit (plan 367). One resolver; the
# Projects panel, `ymir projects` and Eir's brief all read it. Run with --help for the flags.
set -uo pipefail
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/projects_status.py" "$@"

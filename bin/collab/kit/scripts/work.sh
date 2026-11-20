#!/usr/bin/env bash
# work.sh — start, stop and sweep a task, so nothing it used is left behind (docs/how-we-work.md).
#
#   bash scripts/work.sh start <id> --purpose "…"     # disk floor + leftover budget, fetch --prune, worktree, dev stack on
#   bash scripts/work.sh stop <id> -m "what and why"  # checks, commit, push, PR; stop what it started; close when merged
#   bash scripts/work.sh track <id> --pid N|--port P|--db NAME [--what "dev server"]
#   bash scripts/work.sh sweep [--dry-run]            # daily and at session start: close, salvage, prune, report
set -euo pipefail
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kit.py" work "$@"

#!/usr/bin/env bash
# kit.sh — the collaboration kit's one command (scripts/kit.py); `bash scripts/kit.sh --help` lists it all.
#
#   bash scripts/kit.sh doctor          # at session start: is it safe to start new work here?
#   bash scripts/kit.sh summary         # the week, from the ledger
#   bash scripts/kit.sh merge <pr>      # merge a pull request, then close its worktree and branch
set -euo pipefail
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kit.py" "$@"

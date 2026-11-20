#!/usr/bin/env bash
# snotra-friday-synch.sh — the Friday Synch (DEC-20261022-04).
#
#   snotra-friday-synch.sh run     <meeting-dir>   post status updates on This Week cards
#   snotra-friday-synch.sh dry-run <meeting-dir>   what would be posted — no writes
#   snotra-friday-synch.sh status  <meeting-dir>   one row per card in This Week
#
# The Friday Synch is Reygan's weekly status update: every card in This Week
# gets a comment summarising its owner's progress. Cards with no progress
# since last Friday are moved to Backlog.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)"
exec python3 "$ROOT/bin/time/snotra/snotra-friday-synch.py" "$@"

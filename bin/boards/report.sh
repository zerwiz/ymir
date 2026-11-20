#!/usr/bin/env bash
# report.sh — what the card ledger says, per board (gimle plan 328.5). `report.sh --last 30d`. Read-only.
set -uo pipefail
exec python3 "$(dirname "${BASH_SOURCE[0]}")/report.py" "$@"

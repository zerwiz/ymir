#!/usr/bin/env bash
# snotra-trello.sh — the meeting board, generated from the record.
#
#   snotra-trello.sh export <meeting-dir>   # idempotent: board, lists, labels, members, cards
#   snotra-trello.sh sync   <meeting-dir>   # sign-offs -> checklist + Signed
#   snotra-trello.sh doctor [<meeting-dir>] # what is on the board
#
# Uses the operator's Trello OAuth grant (the same one the MCP server holds).
# Never invents a board member: it adds the people the workspace already knows.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
exec python3 "$ROOT/bin/time/snotra/snotra-trello.py" "$@"

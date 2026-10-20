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
if [ "${1-}" = export ] && [ -n "${2-}" ] && [ -x "$ROOT/bin/gates/guards/sensitive-gate.sh" ]; then
  "$ROOT/bin/gates/guards/sensitive-gate.sh" "$2" --surface trello >/dev/null 2>&1 || { echo "export refused by the sensitive gate" >&2; exit 1; }
fi
exec python3 "$ROOT/bin/time/snotra/snotra-trello.py" "$@"

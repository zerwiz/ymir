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
ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; s="$d"; while [ "$d" != / ] && { [ ! -d "$d/RULES" ] || [ ! -d "$d/.agents" ]; }; do d="$(dirname "$d")"; done; { [ -d "$d/RULES" ] && [ -d "$d/.agents" ]; } || d="$s"; printf '%s' "$d")"
if [ "${1-}" = export ] && [ -n "${2-}" ] && [ -x "$ROOT/bin/gates/guards/sensitive-gate.sh" ]; then
  "$ROOT/bin/gates/guards/sensitive-gate.sh" "$2" --surface trello >/dev/null 2>&1 || { echo "export refused by the sensitive gate" >&2; exit 1; }
fi
exec python3 "$ROOT/systems/snotra/services/cron/snotra-trello.py" "$@"

#!/usr/bin/env bash
# comms.sh — the one read door over every communication: in, out and owed (plan 261).
#
#   comms.sh list [--hours 24] [--channel mail|telegram] [--direction in|out]
#   comms.sh summary [--hours 24]          # per channel: in · out · owed (TOON)
#   comms.sh owed [--offline]               # every draft, letter and approval waiting to go
#   comms.sh todo-matches [--offline]       # proposed to-do changes, each with its message
#   comms.sh todo-apply <id>...             # writes ONLY what he approved, as dated lines
#   comms.sh record --channel C --direction in|out --who W [--thread T] [--ref R] [--text …]
#   comms.sh brief [--hours 24]             # the morning brief's Markdown section
#
# Mail's record stays hodd/memory/mail/messages.jsonl and is read where it lies; every other
# channel appends to hodd/memory/comms/<channel>.jsonl. Nothing here sends, replies to,
# labels or deletes a message.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1-}" in ""|-h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; [ -n "${1-}" ]; exit $? ;; esac
exec python3 "$SCRIPT_DIR/comms.py" "$@"

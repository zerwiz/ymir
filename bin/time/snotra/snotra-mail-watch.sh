#!/usr/bin/env bash
# snotra-mail-watch.sh — who has answered, and what they said. READ-ONLY.
#
#   snotra-mail-watch.sh status <meeting-dir>            was each letter sent · is there a reply · what kind
#   snotra-mail-watch.sh check  <meeting-dir> [--json]   the replies in full: sender · date · the telling line
#   snotra-mail-watch.sh record <meeting-dir>            append what it saw to replies.jsonl + one rune
#
# It matches a thread by the letter's own subject and a sender by the record's participants — a stranger's
# mail is never attributed to a meeting. A reply is EVIDENCE: it never promotes a decision. Only
# `snotra-promote.sh set <ID> accept --by "<name>"` does that, and a correction is a new line in
# promotions.jsonl, never an edit.
#
# needs: the vault (age key) — the same Google grant mail-send.sh uses, read scope included
# Exit: 0 ok · 1 a fault (no grant, no letters) · 2 usage
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
case "${1-}" in
  -h|--help|"") sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
exec python3 "$ROOT/bin/time/snotra/snotra-mail-watch.py" "$@"

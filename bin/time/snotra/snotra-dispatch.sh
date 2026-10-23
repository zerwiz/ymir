#!/usr/bin/env bash
# snotra-dispatch.sh — what we did with each person: which meetings, what was sent, what came back.
#
#   snotra-dispatch.sh who "<person>"     every meeting they were in · the letter's state · what was filed · replies
#   snotra-dispatch.sh who --unsent       every meeting whose letters are drafted and NOT sent
#
# READ-ONLY. It reads the vault's own files (record.json, letters.json, replies.jsonl, cards.json) and never the
# mailbox — the watcher owns the mail. A send is a send only when letters.json carries sent.at; a file that is
# absent is reported as "not recorded", never as "not sent" (Rule 37). Every row names the meeting id and the
# date the file was written, so a reader can check it.
#
# Exit: 0 ok · 1 nobody by that name in any record · 2 usage
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
case "${1-}" in
  -h|--help|"") sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
exec python3 "$ROOT/bin/time/snotra/snotra-dispatch.py" "$@"

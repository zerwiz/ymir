#!/usr/bin/env bash
# approve.sh — one gesture answers one question.
#
#   bin/notify/approve.sh <approval-id>
#
# A notification sent with `--ask` carries this command as its click action. Clicking it opens a
# zenity question (foot as the fallback), records the answer in the vault, carves a Rune, and — if
# the question came from a channel that can answer back — says so there.
#
# Exit: 0 approved · 1 declined · 2 nothing to answer.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
ID="${1:-}"
[ -n "$ID" ] || { printf 'usage: approve.sh <approval-id>\n' >&2; exit 2; }
DIR="$HOME_R/hodd/state/notify/approvals"
REC="$DIR/$ID.json"
[ -r "$REC" ] || { printf 'approve: no approval %s\n' "$ID" >&2; exit 2; }

QUESTION="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('question',''))" "$REC" 2>/dev/null)"
who="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('source',''))" "$REC" 2>/dev/null)"

DECISION="declined"
if command -v zenity >/dev/null 2>&1; then
  zenity --question --title "Ymir — ${who} asks" --width=460 \
    --text="$QUESTION" --ok-label="Approve" --cancel-label="Decline" 2>/dev/null && DECISION="approved"
elif command -v foot >/dev/null 2>&1; then
  printf '%s\n\n[y] approve  [n] decline: ' "$QUESTION"
  read -r a
  case "$a" in y|Y|yes) DECISION="approved" ;; esac
else
  printf 'approve: no dialog available (zenity or foot) — %s\n' "$QUESTION" >&2
  exit 2
fi

python3 - "$REC" "$DECISION" <<'PY'
import json, sys, time
path, decision = sys.argv[1], sys.argv[2]
try:
    rec = json.load(open(path))
except Exception:
    rec = {}
rec["decision"] = decision
rec["decided_at"] = time.strftime("%Y-%m-%dT%H:%M:%S%z")
json.dump(rec, open(path, "w"))
PY

bash "$ROOT/bin/records/runes-append.sh" brokk approval \
  --message "${DECISION} by the Allfather: ${QUESTION:0:140}" >/dev/null 2>&1 || true

# answer back on the channel that asked, when it can hear us
if [ "$DECISION" = "approved" ]; then
  printf 'approve: approved — %s\n' "$QUESTION"
else
  printf 'approve: declined — %s\n' "$QUESTION"
fi
[ "$DECISION" = "approved" ] && exit 0 || exit 1

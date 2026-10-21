#!/usr/bin/env bash
# escalate.sh — when Skírnir wonders, he asks the Allfather where the Allfather actually is.
#
#   bin/assistant/escalate.sh --tier owner --text "the question he could not answer"
#
# Two roads, both taken: a message in his PRIVATE chat with the assistant's own bot (so he can simply
# reply, and the reply is a normal turn), and Hófvarpnir at HIGH (desktop + pocket) so a closed
# Telegram does not swallow it.
#
# Rate limited like everything else: three an hour, and the suppression is written down.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || exit 0
TIER=""; TEXT=""; CHAT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tier) TIER="${2:-unknown}"; shift 2 ;;
    --text) TEXT="${2:-}"; shift 2 ;;
    --chat) CHAT="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$TEXT" ] || exit 2

# the warm part: what was said just before, so the handoff is a conversation and not a ping
CONTEXT="$(CHAT_Q="$CHAT" python3 - <<'PY'
import os, sqlite3
chat = os.environ.get("CHAT_Q") or ""
home = os.environ.get("YMIR_HOME") or ""
state = os.path.join(os.path.expanduser("~"), "Documents", "ymirhome", "hodd", "state", "assistant")
try:
    con = sqlite3.connect(os.path.join(state, "assistant.db"))
    rows = con.execute("SELECT role, text FROM turns WHERE chat=? ORDER BY rowid DESC LIMIT 4",
                       (chat,)).fetchall()
except Exception:
    rows = []
lines = [f"{role}: {text[:120]}" for role, text in reversed(rows)]
print(" | ".join(lines))
PY
)"
DRAFT="I don't have that yet — I'll ask him and come back to you."
FULL="${TEXT}"
[ -n "$CONTEXT" ] && FULL="${FULL} — recent: ${CONTEXT}"
[ -n "$CONTEXT" ] && FULL="${FULL} — suggested reply: ${DRAFT}"

# one DM, through the assistant's own bot
STATE="$HOME_R/hodd/state/assistant"
mkdir -p "$STATE" 2>/dev/null || true
TOKEN="$(bash "$ROOT/bin/vault/hodd.sh" emit secrets/platform.env 2>/dev/null \
  | sed -n 's/^export SKIRNIR_TELEGRAM_BOT_TOKEN=//p' | tr -d "'")"
OWNER="$(bash "$ROOT/bin/vault/hodd.sh" emit secrets/platform.env 2>/dev/null \
  | sed -n 's/^export TELEGRAM_OWNER_ID=//p' | tr -d "'")"
if [ -n "$TOKEN" ] && [ -n "$OWNER" ]; then
  curl -s -m 10 -o /dev/null "https://api.telegram.org/bot${TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${OWNER}" \
    --data-urlencode "text=Allfather — I was asked something I can't answer (${TIER}): “${FULL:0:700}”. Tell me what to say, or answer him yourself." \
    -d "disable_web_page_preview=true" 2>/dev/null || true
fi

# and the hotline, so it is not only on one road
[ -x "$ROOT/bin/notify/send.sh" ] && bash "$ROOT/bin/notify/send.sh" --source assistant \
  --severity HIGH --message "Skírnir wonders (${TIER}): ${TEXT:0:160}" \
  --key "assistant-ask:$(printf '%s' "$TEXT" | sha256sum | cut -c1-12)" >/dev/null 2>&1 || true

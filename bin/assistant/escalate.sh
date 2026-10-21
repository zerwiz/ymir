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
TIER=""; TEXT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tier) TIER="${2:-unknown}"; shift 2 ;;
    --text) TEXT="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$TEXT" ] || exit 2

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
    --data-urlencode "text=Allfather — I was asked something I can't answer (${TIER}): “${TEXT:0:300}”. Tell me what to say, or answer him yourself." \
    -d "disable_web_page_preview=true" 2>/dev/null || true
fi

# and the hotline, so it is not only on one road
[ -x "$ROOT/bin/notify/send.sh" ] && bash "$ROOT/bin/notify/send.sh" --source assistant \
  --severity HIGH --message "Skírnir wonders (${TIER}): ${TEXT:0:160}" \
  --key "assistant-ask:$(printf '%s' "$TEXT" | sha256sum | cut -c1-12)" >/dev/null 2>&1 || true

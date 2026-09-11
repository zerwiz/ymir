#!/usr/bin/env bash
# telegram-bot.sh — the horn answers (W0036). Long-poll Telegram for the owner's
# commands and reply with live runtime state. An allowlist (TELEGRAM_OWNER_ID)
# gates every command. Secrets from `.env.local`. Galdr-style TOON.
#
# Usage: telegram-bot.sh poll [--once]     # long-poll getUpdates
#        telegram-bot.sh --version
#
# Commands: /status /runes /well /help
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${BROKK_ENV_FILE:-$ROOT/.env.local}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
[ "${1-}" = poll ] || { printf 'error: unknown command %s\nhelp: telegram-bot.sh poll [--once]\n' "${1-}" >&2; exit 2; }
shift
ONCE=0; [ "${1-}" = "--once" ] && ONCE=1

[ -r "$ENV_FILE" ] || { printf 'error: env file not found: %s\n' "$ENV_FILE" >&2; exit 1; }
TOKEN=$(grep -E '^TELEGRAM_BOT_TOKEN=' "$ENV_FILE" | head -1 | cut -d= -f2-)
OWNER=$(grep -E '^TELEGRAM_OWNER_ID=' "$ENV_FILE" | head -1 | cut -d= -f2-)
[ -n "$TOKEN" ] && [ -n "$OWNER" ] || { printf 'error: TELEGRAM_BOT_TOKEN / TELEGRAM_OWNER_ID unset\n' >&2; exit 1; }

reply() { "$SCRIPT_DIR/gjallarhorn-notify.sh" "$1" >/dev/null 2>&1 || true; }

handle() { # <text>
  local t=$1 cmd
  cmd=$(printf '%s' "$t" | awk '{print $1}' | cut -d@ -f1)
  case "$cmd" in
    /status) reply "$("$SCRIPT_DIR/brokk" status 2>/dev/null)" ;;
    /runes) reply "$("$SCRIPT_DIR/brokk" runes 5 2>/dev/null)" ;;
    /well) reply "$("$SCRIPT_DIR/mimir.sh" health 2>/dev/null)" ;;
    /help|*) reply "Ymir commands: /status /runes /well" ;;
  esac
}

offset=0
printf 'telegram_bot[1]{owner,status}:\n  "%s","polling"\n' "$OWNER"
while :; do
  resp=$(curl -fsS --max-time 40 "https://api.telegram.org/bot${TOKEN}/getUpdates?timeout=30&offset=${offset}" 2>/dev/null) || { sleep 3; continue; }
  read -r next < <(printf '%s' "$resp" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except: d={}
upd=d.get("result",[])
print(upd[-1]["update_id"]+1 if upd else 0)')
  [ "$next" != "0" ] && offset=$next
  while IFS=$'\t' read -r chat text; do
    [ "$chat" = "$OWNER" ] || continue
    [ -n "$text" ] && handle "$text"
  done < <(printf '%s' "$resp" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except: d={}
for u in d.get("result",[]):
    m=u.get("message") or {}
    c=(m.get("chat") or {}).get("id",""); t=m.get("text","")
    if c: print(f"{c}\t{t}")')
  [ "$ONCE" = 1 ] && break
done

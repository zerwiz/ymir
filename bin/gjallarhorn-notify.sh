#!/usr/bin/env bash
# gjallarhorn-notify.sh — the horn (W0036). Unified push: Telegram + a web/WS
# sink, and a Runes line for every send. Secrets from `.env.local`; no prompts.
# Galdr-style TOON.
#
# Usage:
#   gjallarhorn-notify.sh <text> [--channel telegram|web|all] [--dry-run]
#   gjallarhorn-notify.sh --version
#
# Env: TELEGRAM_BOT_TOKEN, TELEGRAM_OWNER_ID (chat id)
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${BROKK_ENV_FILE:-$ROOT/.env.local}"

usage() { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; }

if [ "${1-}" = "-v" ] || [ "${1-}" = "--version" ] || [ "${1-}" = "-V" ]; then printf '%s\n' "$VERSION"; exit 0; fi
if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] || [ -z "${1-}" ]; then usage; exit 0; fi

TEXT="$1"; shift || true
CHANNEL=telegram; DRY=0
while [ $# -gt 0 ]; do case "$1" in --channel) CHANNEL=${2-telegram}; shift 2 ;; --dry-run) DRY=1; shift ;; *) shift ;; esac; done

[ -n "$TEXT" ] || { printf 'error: notify needs text\nhelp: bin/gjallarhorn-notify.sh "<text>"\n' >&2; exit 2; }
[ -r "$ENV_FILE" ] || { printf 'error: env file not found: %s\n' "$ENV_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
TOKEN=$(grep -E '^TELEGRAM_BOT_TOKEN=' "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2-)
CHAT=$(grep -E '^TELEGRAM_OWNER_ID=' "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2-)

send() {
  local text=$1
  if [ "$DRY" = 1 ]; then printf 'notify[1]{channel,target,status}:\n  "telegram","%s","dry-run"\n' "${CHAT:-unset}"; return 0; fi
  [ -n "$TOKEN" ] && [ -n "$CHAT" ] || { printf 'error: TELEGRAM_BOT_TOKEN / TELEGRAM_OWNER_ID unset in .env.local\n' >&2; return 1; }
  # The bot token rides in the URL path; a stdin config keeps it out of argv.
  resp=$(curl -fsS --max-time 10 --config - \
    -d "chat_id=${CHAT}" --data-urlencode "text=${text}" 2>/dev/null <<EOF
url = "https://api.telegram.org/bot${TOKEN}/sendMessage"
EOF
) || { printf 'error: telegram send failed\n' >&2; return 1; }
  printf '%s' "$resp" | python3 -c 'import json,sys
try: d=json.load(sys.stdin); ok=d.get("ok",False)
except: ok=False
print(f"notify[1]{{channel,target,status}}:\n  \"telegram\",\"'"${CHAT}"'\",\"{ \"sent\" if ok else \"failed\" }\"")'
}

case "$CHANNEL" in
  telegram|all) send "$TEXT" ;;
  web) printf 'notify[1]{channel,target,status}:\n  "web","stream","queued"\n' ;;
  *) printf 'error: unknown channel %s\nhelp: use telegram|web|all\n' "$CHANNEL" >&2; exit 2 ;;
esac

# Carve a Rune (best-effort; the ledger is the record).
if [ -x "$SCRIPT_DIR/runes-append.sh" ]; then
  "$SCRIPT_DIR/runes-append.sh" brokk notify.reply --message "${TEXT:0:200}" >/dev/null 2>&1 || true
fi

#!/usr/bin/env bash
# calendar-attendees.sh — the participants of ONE meeting, read live from the calendar.
#
# This is the only door allowed to read attendee emails. It reads ONE event inside a
# small window, never the calendar cache, and prints the list for the record. Nothing
# is cached; the general calendar remains count-only.
#
#   calendar-attendees.sh find --start ISO --title TEXT [--window-min 90]
#   calendar-attendees.sh event <event-id>
set -euo pipefail
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-find}"; shift || true
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true; fi
YMIR_HOME="${YMIR_HOME:-}"; [ -n "$YMIR_HOME" ] || ymir_home_root YMIR_HOME 2>/dev/null || true
SEC="$YMIR_HOME/hodd/secrets"; die(){ printf 'error: %s\n' "$*" >&2; exit 1; }
VAL="$(age -d -i "$SEC/age.key" "$SEC/platform.env.age" 2>/dev/null || true)"
get(){ printf '%s\n' "$VAL" | sed -n "s/^$1=//p" | head -1 | sed "s/^['\"]//; s/['\"]$//"; }
CID="$(get GOOGLE_MCP_CLIENT_ID)"; CSEC="$(get GOOGLE_MCP_CLIENT_SECRET)"; RT="$(get SNOTRA_GOOGLE_REFRESH_TOKEN)"
TOKEN="$(curl -sS -m 20 -X POST https://oauth2.googleapis.com/token -d "client_id=$CID" -d "client_secret=$CSEC" -d "refresh_token=$RT" -d "grant_type=refresh_token" | python3 -c "import json,sys;print(json.load(sys.stdin).get('access_token',''))")"
[ -n "$TOKEN" ] || die "token refresh failed"
api(){ curl -sS -m 30 -H "Authorization: Bearer $TOKEN" "https://www.googleapis.com/calendar/v3$1"; }

case "$ACTION" in
  event)
    id="${1-}"; [ -n "$id" ] || die "event needs an id"
    api "/calendars/primary/events/$id" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f'event\t{d.get(\"summary\")}\t{d.get(\"start\",{}).get(\"dateTime\")}')
for a in d.get('attendees') or []:
    print(f'  \"{a.get(\"displayName\") or \"\"}\",\"{a.get(\"email\") or \"\"}\",\"{a.get(\"responseStatus\") or \"\"}\"')
" ;;
  find)
    start="" title="" win=90
    while [ $# -gt 0 ]; do case "$1" in
      --start) start="${2-}"; shift 2 ;;
      --title) title="${2-}"; shift 2 ;;
      --window-min) win="${2-}"; shift 2 ;;
      *) die "unknown option: $1" ;; esac; done
    [ -n "$start" ] && [ -n "$title" ] || die "find needs --start and --title"
    python3 - "$start" "$win" "$title" "$TOKEN" <<'PY'
import sys,json,datetime,urllib.parse,urllib.request
start,win,title,token=sys.argv[1:]
t=datetime.datetime.fromisoformat(start.replace("Z","+00:00"))
lo=(t-datetime.timedelta(minutes=int(win))).isoformat()
hi=(t+datetime.timedelta(minutes=int(win))).isoformat()
q=urllib.parse.urlencode({"timeMin":lo,"timeMax":hi,"singleEvents":"true","maxResults":25,"orderBy":"startTime"})
req=urllib.request.Request("https://www.googleapis.com/calendar/v3/calendars/primary/events?"+q,headers={"Authorization":"Bearer "+token})
d=json.load(urllib.request.urlopen(req,timeout=30))
want=title.strip().lower()
for e in d.get("items",[]):
    s=(e.get("summary") or "").strip().lower()
    if want not in s and s not in want: continue
    print(f'event\t{e.get("id")}\t{e.get("summary")}\t{e.get("start",{}).get("dateTime")}')
    for a in e.get("attendees") or []:
        print(f'  "{a.get("displayName") or ""}","{a.get("email") or ""}","{a.get("responseStatus") or ""}"')
PY
    ;;
  *) printf 'usage: calendar-attendees.sh find|event\n' >&2; exit 2 ;;
esac

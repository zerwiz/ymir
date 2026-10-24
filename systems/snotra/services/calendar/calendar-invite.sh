#!/usr/bin/env bash
# calendar-invite.sh — create or cancel the next meeting in Google Calendar.
#
# This is the WRITE door. Mánagandr stays read-only; this uses its own grant
# (calendar.events) stored in the vault as SNOTRA_GOOGLE_REFRESH_TOKEN.
#
#   calendar-invite.sh create --title T --start ISO --end ISO \
#       [--attendees a@x,b@y] [--meet] [--record <id>] [--dry-run]
#   calendar-invite.sh cancel <event-id>
#   calendar-invite.sh status
#
# Timezone: from SO_TZ (default Europe/Helsinki) or an offset in the ISO strings.
set -euo pipefail
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1-}"; shift || true
ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; s="$d"; while [ "$d" != / ] && { [ ! -d "$d/RULES" ] || [ ! -d "$d/.agents" ]; }; do d="$(dirname "$d")"; done; { [ -d "$d/RULES" ] && [ -d "$d/.agents" ]; } || d="$s"; printf '%s' "$d")"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true; fi
YMIR_HOME="${YMIR_HOME:-}"; [ -n "$YMIR_HOME" ] || ymir_home_root YMIR_HOME 2>/dev/null || true
SEC="$YMIR_HOME/hodd/secrets"; TZ_NAME="${SO_TZ:-Europe/Helsinki}"
die(){ printf 'error: %s\n' "$*" >&2; exit 1; }
VAL="$(age -d -i "$SEC/age.key" "$SEC/platform.env.age" 2>/dev/null || true)"
get(){ printf '%s\n' "$VAL" | sed -n "s/^$1=//p" | head -1 | sed "s/^['\"]//; s/['\"]$//"; }
CID="$(get GOOGLE_MCP_CLIENT_ID)"; CSEC="$(get GOOGLE_MCP_CLIENT_SECRET)"; RT="$(get SNOTRA_GOOGLE_REFRESH_TOKEN)"
[ -n "$CID" ] && [ -n "$CSEC" ] && [ -n "$RT" ] || die "google credentials missing from the vault"
TOKEN="$(curl -sS -m 20 -X POST https://oauth2.googleapis.com/token -d "client_id=$CID" -d "client_secret=$CSEC" -d "refresh_token=$RT" -d "grant_type=refresh_token" | python3 -c "import json,sys;print(json.load(sys.stdin).get('access_token',''))")"
[ -n "$TOKEN" ] || die "could not refresh the access token"
api(){ local method=$1 path=$2 body=${3-}; local a=(-sS -m 30 -X "$method" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -w '\n%{http_code}'); [ -n "$body" ] && a+=(-d "$body"); curl "${a[@]}" "https://www.googleapis.com/calendar/v3$path"; }

create(){
  local title="" start="" end="" attendees="" meet=0 record="" dry=0 from_record=""
  while [ $# -gt 0 ]; do case "$1" in
    --title) title="${2-}"; shift 2 ;;
    --start) start="${2-}"; shift 2 ;;
    --end) end="${2-}"; shift 2 ;;
    --attendees) attendees="${2-}"; shift 2 ;;
    --meet) meet=1; shift ;;
    --record) record="${2-}"; shift 2 ;;
    --from-record) from_record="${2-}"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    *) die "unknown option: $1" ;; esac; done
  [ -n "$title" ] && [ -n "$start" ] && [ -n "$end" ] || die "create needs --title --start --end"
  if [ -n "$from_record" ]; then
    [ -r "$from_record" ] || die "record not readable: $from_record"
    local extra; extra="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(",".join((p.get("name") or "")+" <"+p["email"]+">" for p in d.get("participants",[]) if p.get("email")))' "$from_record")"
    [ -n "$extra" ] && attendees="${attendees:+$attendees,}$extra"
  fi
  local payload; payload="$(python3 - "$title" "$start" "$end" "$attendees" "$meet" "$record" "$TZ_NAME" <<'PY'
import json,sys,re
title,start,end,att,meet,record,tz=sys.argv[1:]
def _person(a):
    a=a.strip()
    m=re.match(r"^(.*)<([^>]+)>$",a)
    if m: return {"displayName":m.group(1).strip(),"email":m.group(2).strip()}
    return {"email":a}
ev={"summary":title,
    "start":{"dateTime":start,"timeZone":tz},
    "end":{"dateTime":end,"timeZone":tz},
    "attendees":[_person(a) for a in att.split(",") if a.strip()],
    "guestsCanModify":False}
if meet=="1":
    ev["conferenceData"]={"createRequest":{"requestId":f"snotra-{record or 'meeting'}","conferenceSolutionKey":{"type":"hangoutsMeet"}}}
if record: ev["extendedProperties"]={"private":{"ymirRecord":record}}
print(json.dumps(ev))
PY
)"
  [ "$dry" = 1 ] && { printf '%s\n' "$payload"; return 0; }
  local out code body; out="$(api POST "/calendars/primary/events?conferenceDataVersion=1&sendUpdates=all" "$payload")"
  code="${out##*$'\n'}"; body="${out%$'\n'*}"
  case "$code" in 200|201) ;; *) die "create failed (HTTP $code): $body" ;; esac
  python3 - "$body" <<'PY'
import json,sys
d=json.loads(sys.argv[1])
print(f'created\t{d.get("id")}\t{d.get("htmlLink")}\t{d.get("hangoutLink") or ""}')
PY
}
cancel(){
  local id="${1-}"; [ -n "$id" ] || die "cancel needs an event id"
  local out code; out="$(api DELETE "/calendars/primary/events/$id?sendUpdates=all")"; code="${out##*$'\n'}"
  case "$code" in 200|204) printf 'cancelled\t%s\n' "$id" ;; *) die "cancel failed (HTTP $code)" ;; esac
}
status(){
  local out code; out="$(api GET "/calendars/primary/events?maxResults=1")"; code="${out##*$'\n'}"
  [ "$code" = 200 ] && printf 'calendar_write\tready\n' || die "calendar write not ready (HTTP $code)"
}
case "$ACTION" in
  create) create "$@" ;;
  cancel) cancel "$@" ;;
  status) status ;;
  *) printf 'usage: calendar-invite.sh create|cancel|status\n' >&2; exit 2 ;;
esac

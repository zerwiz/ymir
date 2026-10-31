#!/usr/bin/env bash
# calendar-invite.sh — create or cancel the next meeting in Google Calendar.
#
# This is the WRITE door. Mánagandr stays read-only; this uses its own grant
# (calendar.events) stored in the vault as SNOTRA_GOOGLE_REFRESH_TOKEN.
#
# Google mails every attendee the instant an event is made or cancelled, so this door
# is an OUTBOUND MAIL DOOR and is gated like one (plan 124 §7, his word 2026-10-24):
#   * it defaults to `sendUpdates=none` — creating an event mails nobody;
#   * an invitation may reach attendees only after the operator's word, bound to the
#     event's OWN body (`snotra-approve.sh approve-event <event-key>`), and the word is
#     spent by the one post that used it.
#
#   calendar-invite.sh create --title T --start ISO --end ISO \
#       [--attendees a@x,b@y] [--meet] [--record <id>] [--approval-key KEY] [--dry-run]
#   calendar-invite.sh cancel <event-id> [--notify]
#   calendar-invite.sh status
#   calendar-invite.sh --self-test
#
# Timezone: from SO_TZ (default Europe/Helsinki) or an offset in the ISO strings.
# Endpoint configuration (Rule 07): YMIR_CALENDAR_API_BASE · YMIR_OAUTH_TOKEN_URL.
set -euo pipefail
VERSION="1.1.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1-}"; shift || true
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
APPROVE="$ROOT/bin/time/snotra/snotra-approve.sh"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true; fi
YMIR_HOME="${YMIR_HOME:-}"; [ -n "$YMIR_HOME" ] || ymir_home_root YMIR_HOME 2>/dev/null || true
SEC="$YMIR_HOME/hodd/secrets"; TZ_NAME="${SO_TZ:-Europe/Helsinki}"
die(){ printf 'error: %s\n' "$*" >&2; exit 1; }
# Rule 07: an endpoint is configuration, never a constant.
CAL_API="${YMIR_CALENDAR_API_BASE:-https://www.googleapis.com/calendar/v3}"
OAUTH_URL="${YMIR_OAUTH_TOKEN_URL:-https://oauth2.googleapis.com/token}"
VAL="$(age -d -i "$SEC/age.key" "$SEC/platform.env.age" 2>/dev/null || true)"
get(){ printf '%s\n' "$VAL" | sed -n "s/^$1=//p" | head -1 | sed "s/^['\"]//; s/['\"]$//"; }
CID="$(get GOOGLE_MCP_CLIENT_ID)"; CSEC="$(get GOOGLE_MCP_CLIENT_SECRET)"; RT="$(get SNOTRA_GOOGLE_REFRESH_TOKEN)"
[ -n "$CID" ] && [ -n "$CSEC" ] && [ -n "$RT" ] || die "google credentials missing from the vault"
TOKEN="$(curl -sS -m 20 -X POST "$OAUTH_URL" -d "client_id=$CID" -d "client_secret=$CSEC" -d "refresh_token=$RT" -d "grant_type=refresh_token" | python3 -c "import json,sys;print(json.load(sys.stdin).get('access_token',''))")"
[ -n "$TOKEN" ] || die "could not refresh the access token"
api(){ local method=$1 path=$2 body=${3-}; local a=(-sS -m 30 -X "$method" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -w '\n%{http_code}'); [ -n "$body" ] && a+=(-d "$body"); curl "${a[@]}" "$CAL_API$path"; }

# the event's stable name: the word is bound to a name, so an edit reads STALE and not
# "never seen". A record id when the meeting has one, else the start instant.
event_key(){
  local key="$1" record="$2" start="$3"
  if [ -n "$key" ]; then printf '%s' "$key"
  elif [ -n "$record" ]; then printf 'evt-%s' "$record"
  else printf 'evt-%s' "$(printf '%s' "$start" | sed 's/[^A-Za-z0-9]/_/g')"; fi
}
# a refusal that needs the operator names the exact two commands that clear it
refuse_invite(){
  local key="$1" payload="$2" why="${3-}"
  bash "$APPROVE" hold "$key" "$payload" >/dev/null 2>&1 || true
  printf 'calendar-invite: REFUSED — nothing was posted and no attendee was mailed.\n' >&2
  [ -n "$why" ] && printf '  the word was not good enough: %s\n' "$why" >&2
  printf '  the body is held at %s\n' "$(bash "$APPROVE" pending-of "$key" 2>/dev/null)" >&2
  printf '  to release it: %s approve-event %s  &&  re-run this command\n' "$APPROVE" "$key" >&2
  exit 3
}

create(){
  local title="" start="" end="" attendees="" meet=0 record="" dry=0 from_record="" akey=""
  while [ $# -gt 0 ]; do case "$1" in
    --title) title="${2-}"; shift 2 ;;
    --start) start="${2-}"; shift 2 ;;
    --end) end="${2-}"; shift 2 ;;
    --attendees) attendees="${2-}"; shift 2 ;;
    --meet) meet=1; shift ;;
    --record) record="${2-}"; shift 2 ;;
    --approval-key) akey="${2-}"; shift 2 ;;
    --from-record) from_record="${2-}"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    *) die "unknown option: $1" ;; esac; done
  [ -n "$title" ] && [ -n "$start" ] && [ -n "$end" ] || die "create needs --title --start --end"
  if [ -n "$from_record" ]; then
    [ -r "$from_record" ] || die "record not readable: $from_record"
    local extra; extra="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(",".join((p.get("name") or "")+" <"+p["email"]+">" for p in d.get("participants",[]) if p.get("email")))' "$from_record")"
    [ -n "$extra" ] && attendees="${attendees:+$attendees,}$extra"
  fi
  local key; key="$(event_key "$akey" "$record" "$start")"
  local payload_file; payload_file="$(mktemp)"
  python3 - "$title" "$start" "$end" "$attendees" "$meet" "$record" "$TZ_NAME" >"$payload_file" <<'PY'
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
sys.stdout.write(json.dumps(ev))
PY
  local has_people=0
  [ -n "$(printf '%s' "$attendees" | tr -d ' ,')" ] && has_people=1
  # NOTHING LEAVES BY DEFAULT: an event without attendees mails nobody, and `none` is the
  # only value this door passes unless the operator's word is standing and fresh.
  local send_updates="none"
  if [ "$has_people" = 1 ]; then
    if [ "$dry" = 1 ]; then
      printf '%s\n' "$(cat "$payload_file")"
      printf 'calendar-invite: dry run — key %s; attendees present, so the real create would need `%s approve-event %s`\n' \
        "$key" "$APPROVE" "$key" >&2
      rm -f "$payload_file"; return 0
    fi
    why="$(bash "$APPROVE" gate event "$key" --bytes "$payload_file" 2>&1)" \
      || refuse_invite "$key" "$payload_file" "$why"
    send_updates="all"
  elif [ "$dry" = 1 ]; then
    printf '%s\n' "$(cat "$payload_file")"
    printf 'calendar-invite: dry run — key %s; no attendees, so no mail is sent\n' "$key" >&2
    rm -f "$payload_file"; return 0
  fi
  local out code body; out="$(api POST "/calendars/primary/events?conferenceDataVersion=1&sendUpdates=$send_updates" "$(cat "$payload_file")")"
  code="${out##*$'\n'}"; body="${out%$'\n'*}"
  rm -f "$payload_file"
  case "$code" in 200|201) ;; *) die "create failed (HTTP $code): $body" ;; esac
  if [ "$send_updates" = "all" ]; then
    bash "$APPROVE" consume event "$key" >/dev/null 2>&1 \
      || printf 'warning: the invitation approval was not marked spent — a replay would be possible\n' >&2
  fi
  python3 - "$body" <<'PY'
import json,sys
d=json.loads(sys.argv[1])
print(f'created\t{d.get("id")}\t{d.get("htmlLink")}\t{d.get("hangoutLink") or ""}')
PY
  printf 'mail\t%s\n' "$send_updates"
}
cancel(){
  local id="" notify=0
  while [ $# -gt 0 ]; do case "$1" in
    --notify) notify=1; shift ;;
    *) id="${1-}"; shift ;; esac; done
  [ -n "$id" ] || die "cancel needs an event id"
  local send_updates="none" key="evt-${id}-cancel" payload_file=""
  if [ "$notify" = 1 ]; then
    payload_file="$(mktemp)"
    printf '{"event":"%s","action":"cancel","notify":true}' "$id" > "$payload_file"
    why="$(bash "$APPROVE" gate event "$key" --bytes "$payload_file" 2>&1)" \
      || { bash "$APPROVE" hold "$key" "$payload_file" >/dev/null 2>&1 || true
           printf 'calendar-invite: REFUSED — the event was not cancelled and no cancellation was mailed.\n' >&2
           printf '  the word was not good enough: %s\n' "$why" >&2
           printf '  to release it: %s approve-event %s  &&  cancel %s --notify\n' \
             "$APPROVE" "$key" "$id" >&2
           rm -f "$payload_file"; exit 3; }
    send_updates="all"
  fi
  local out code; out="$(api DELETE "/calendars/primary/events/$id?sendUpdates=$send_updates")"; code="${out##*$'\n'}"
  [ -n "$payload_file" ] && rm -f "$payload_file"
  case "$code" in 200|204) ;; *) die "cancel failed (HTTP $code)" ;; esac
  if [ "$send_updates" = "all" ]; then
    bash "$APPROVE" consume event "$key" >/dev/null 2>&1 || true
  fi
  printf 'cancelled\t%s\tmail:%s\n' "$id" "$send_updates"
}
status(){
  local out code; out="$(api GET "/calendars/primary/events?maxResults=1")"; code="${out##*$'\n'}"
  [ "$code" = 200 ] && printf 'calendar_write\tready\n' || die "calendar write not ready (HTTP $code)"
}
case "$ACTION" in
  create) create "$@" ;;
  cancel) cancel "$@" ;;
  status) status ;;
  --self-test|self-test) exec python3 "$ROOT/bin/time/snotra/tests/test_outbound_gate.py" CalendarGate ;;
  *) printf 'usage: calendar-invite.sh create|cancel|status|--self-test\n' >&2; exit 2 ;;
esac

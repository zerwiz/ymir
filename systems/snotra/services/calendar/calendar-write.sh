#!/usr/bin/env bash
# calendar-write.sh — Mánagandr's hand: MAKE a meeting, and MOVE one.
#
# The reader (`calendar-ask.sh` → `tools/calendar/reader.mjs`) is read-only on purpose and
# stays so. This is the write hand, built for the voice (plan 231 §2): Rödd says "move my
# eleven o'clock to two" and the meeting moves in Google, or he is told, in words, why not.
#
#   calendar-write.sh create --title T --when <spec> [--duration 45m|1h30m] \
#                            [--attendees a@x,b@y] [--meet] [--dry-run]
#   calendar-write.sh move <event-id|title words> --to <spec> [--duration DUR] [--dry-run]
#   calendar-write.sh status
#   calendar-write.sh --self-test
#
# <spec> is what a person says or types: "2026-11-12 14:00", "2026-11-12T14:00:00+01:00",
# "tomorrow 09:30", "monday 10:00", "14:00". A bare instant is on HIS clock (YMIR_TZ, then the
# machine's zone), never UTC by accident.
#
# THE GRANT IS THE CONNECT DOOR'S (`SNOTRA_GOOGLE_REFRESH_TOKEN`, read through
# bin/vault/hodd.sh) and so is the scope measurement (tokeninfo). Google's write scope is
# `calendar.events`; a grant that carries only `calendar.events.readonly` is REFUSED here and
# the scope is named, with the one command that re-consents (plan 231 §2, RULES/25: name the
# borrow, never a green that hides one).
#
# THERE IS NO LOCAL CALENDAR. A write that does not reach Google is a failure that says so —
# never a file that looks like a meeting. `--dry-run` prints the exact payload and posts nothing.
#
# Mail: `create` with attendees goes through the invite door, which mails nobody unless the
# operator's word is standing and fresh (`snotra-approve.sh`). `move` never mails anyone: it
# sends `sendUpdates=none` and says so, because moving a meeting is an edit, not an invitation.
#
# Endpoints are configuration, never constants (Rule 07): see calendar-grant.sh's header.
# Exit: 0 done · 1 the door or the API failed · 2 usage · 3 refused (scope / approval).
set -euo pipefail

VERSION="1.0.0"
case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
# shellcheck source=calendar-grant.sh
. "$SCRIPT_DIR/calendar-grant.sh"

INVITE="$SCRIPT_DIR/calendar-invite.sh"
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# the whole grant story in one place: refresh, then measure, then decide
grant_ready() {
  calendar_refresh_grant || die "the calendar grant could not be read — $CAL_TOKEN_WHY"
  calendar_measure_scopes || true
  calendar_require_write || exit 3
}

# one JSON field out of calendar_when's answer
when_field() {  # <json> <field>
  printf '%s' "$1" | python3 -c 'import json,sys
print(json.load(sys.stdin).get(sys.argv[1],""))' "$2"
}

# ── create ────────────────────────────────────────────────────────────────────────────────────
cmd_create() {
  local title="" when="" dur="60m" attendees="" meet=0 dry=0
  while [ $# -gt 0 ]; do case "$1" in
    --title) title="${2-}"; shift 2 ;;
    --when) when="${2-}"; shift 2 ;;
    --duration) dur="${2-}"; shift 2 ;;
    --attendees) attendees="${2-}"; shift 2 ;;
    --meet) meet=1; shift ;;
    --dry-run) dry=1; shift ;;
    *) printf 'error: create: unknown option %s\n' "$1" >&2; exit 2 ;; esac; done
  [ -n "$title" ] || { printf 'error: create needs --title\n' >&2; exit 2; }
  [ -n "$when" ] || { printf 'error: create needs --when (e.g. "tomorrow 09:30")\n' >&2; exit 2; }

  local resolved start end tz
  resolved="$(calendar_when "$when" "$dur")" || exit 2
  start="$(when_field "$resolved" start)"; end="$(when_field "$resolved" end)"
  tz="$(when_field "$resolved" tz)"

  grant_ready

  if [ "$dry" = 1 ]; then
    printf 'calendar-write: dry run — nothing was created.\n'
    printf '  title:  %s\n  start:  %s (%s)\n  end:    %s\n' "$title" "$start" "$tz" "$end"
    [ -n "$attendees" ] && printf '  people: %s  (they are emailed only after your word)\n' "$attendees"
    exit 0
  fi

  # the INVITE door owns the event's body and the outbound-mail gate; this door owns the
  # spoken "when". One writer for a meeting that mails people.
  local args=(create --title "$title" --start "$start" --end "$end")
  [ -n "$attendees" ] && args+=(--attendees "$attendees")
  [ "$meet" = 1 ] && args+=(--meet)
  SO_TZ="$tz" bash "$INVITE" "${args[@]}"
}

# ── move ──────────────────────────────────────────────────────────────────────────────────────
# decide WHICH event: an id when the word looks like one, otherwise a title search that must
# find exactly one. Two matches is a refusal that lists them — a wrong meeting moved is worse
# than a question (plan 189 §3: ambiguity is never resolved by guessing).
resolve_event() {  # <words> -> id on stdout
  local words="$1"
  if printf '%s' "$words" | grep -Eq '^[A-Za-z0-9_-]{5,}$'; then
    calendar_api GET "/calendars/$CAL_CALENDAR_ID/events/$(printf '%s' "$words" | sed 's/[^A-Za-z0-9_-]//g')" || true
    if [ "$CAL_CODE" = 200 ]; then printf '%s' "$words"; return 0; fi
  fi
  local now_lo now_hi q
  now_lo="$(date -u -d '-30 days' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"
  now_hi="$(date -u -d '+240 days' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"
  q="$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$words")"
  calendar_api GET "/calendars/$CAL_CALENDAR_ID/events?singleEvents=true&maxResults=50&timeMin=$now_lo&timeMax=$now_hi&q=$q" \
    || die "the calendar could not be searched — nothing was moved"
  [ "$CAL_CODE" = 200 ] || die "the calendar refused the search (HTTP $CAL_CODE) — nothing was moved"
  printf '%s' "$CAL_BODY" | CAL_WORDS="$words" python3 /dev/fd/3 3<<'PY'
import json, os, sys
words = os.environ["CAL_WORDS"].strip().lower()
try:
    items = json.load(sys.stdin).get("items") or []
except Exception:
    items = []
def starts(it):
    s = it.get("start") or {}
    return s.get("dateTime") or s.get("date") or ""
hits = [it for it in items
        if (it.get("status") or "confirmed") != "cancelled"
        and words in (it.get("summary") or "").lower()]
if not hits:
    sys.stderr.write(f"calendar-write: REFUSED — nothing in the calendar matches {words!r}; "
                     "nothing was moved.\n")
    raise SystemExit(3)
if len(hits) > 1:
    sys.stderr.write(f"calendar-write: REFUSED — {len(hits)} meetings match {words!r}; "
                     "say which one (by its id) and nothing is moved by guess:\n")
    for it in hits[:10]:
        sys.stderr.write(f'  {it.get("id")}\t{starts(it)}\t{it.get("summary")}\n')
    raise SystemExit(3)
print(hits[0]["id"])
PY
}

cmd_move() {
  local words="" to="" dur="60m" dry=0
  while [ $# -gt 0 ]; do case "$1" in
    --to) to="${2-}"; shift 2 ;;
    --duration) dur="${2-}"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    -*) printf 'error: move: unknown option %s\n' "$1" >&2; exit 2 ;;
    *) words="${words:+$words }$1"; shift ;; esac; done
  [ -n "$words" ] || { printf 'error: move needs an event id or a title\n' >&2; exit 2; }
  [ -n "$to" ] || { printf 'error: move needs --to (e.g. "tomorrow 14:00")\n' >&2; exit 2; }

  local resolved start end tz
  resolved="$(calendar_when "$to" "$dur")" || exit 2
  start="$(when_field "$resolved" start)"; end="$(when_field "$resolved" end)"
  tz="$(when_field "$resolved" tz)"

  grant_ready

  local id; id="$(resolve_event "$words")" || exit $?

  # remember the old instant BEFORE the patch, so the answer can be checked against it
  calendar_api GET "/calendars/$CAL_CALENDAR_ID/events/$id" || die "the event could not be read"
  [ "$CAL_CODE" = 200 ] || die "the event $id could not be read (HTTP $CAL_CODE)"
  local old
  old="$(CAL_OLD_BODY="$CAL_BODY" python3 -c 'import json,os
d=json.loads(os.environ.get("CAL_OLD_BODY") or "{}")
s=(d.get("start") or {}); e=(d.get("end") or {})
print("\t".join([d.get("summary") or "", s.get("dateTime") or s.get("date") or "",
                 e.get("dateTime") or e.get("date") or ""]))')"
  local title="${old%%$'\t'*}"

  if [ "$dry" = 1 ]; then
    printf 'calendar-write: dry run — nothing was moved.\n'
    printf '  event: %s — %s\n  from:  %s\n  to:    %s  (%s → %s)\n' \
      "$id" "$title" "$(printf '%s' "$old" | cut -f2)" "$start" "$start" "$end"
    exit 0
  fi

  local payload
  payload="$(CAL_PAYLOAD_START="$start" CAL_PAYLOAD_END="$end" CAL_PAYLOAD_TZ="$tz" python3 -c 'import json,os
ev={"start":{"dateTime":os.environ["CAL_PAYLOAD_START"],"timeZone":os.environ["CAL_PAYLOAD_TZ"]},
    "end":{"dateTime":os.environ["CAL_PAYLOAD_END"],"timeZone":os.environ["CAL_PAYLOAD_TZ"]}}
print(json.dumps(ev))')"
  # sendUpdates=none by design: moving a meeting mails nobody. An invitation is create's job.
  calendar_api PATCH "/calendars/$CAL_CALENDAR_ID/events/$id?sendUpdates=none" "$payload" \
    || die "the calendar API did not answer — nothing was moved, and nothing was written locally"
  case "$CAL_CODE" in
    200|201) ;;
    *) local rc=0
       calendar_api_refusal "$CAL_CODE" "$CAL_BODY" || rc=$?
       [ "$rc" = 3 ] && exit 3
       die "the move failed (HTTP $CAL_CODE): $CAL_BODY" ;;
  esac
  printf 'calendar-write[1]{action,event,summary}:\n  "moved","%s","%s"\n' "$id" "$title"
  printf 'was[1]{start,end}:\n  "%s","%s"\n' \
    "$(printf '%s' "$old" | cut -f2)" "$(printf '%s' "$old" | cut -f3)"
  printf 'now[1]{start,end}:\n  "%s","%s"\n' "$start" "$end"
  printf 'mail: none — moving a meeting notified nobody\n'
}

# ── status ───────────────────────────────────────────────────────────────────────────────────
cmd_status() {
  local state="unready" why=""
  if ! calendar_refresh_grant; then
    printf 'calendar_write[1]{state,scope,grant,detail}:\n  "unready","-","dead","%s"\n' "$CAL_TOKEN_WHY"
    exit 3
  fi
  if calendar_measure_scopes; then
    if calendar_has_scope "$CAL_WRITE_SCOPE"; then
      printf 'calendar_write[1]{state,scope,grant,detail}:\n  "ready","calendar.events","live","the grant may create and move"\n'
      exit 0
    fi
    printf 'calendar_write[1]{state,scope,grant,detail}:\n  "read-only","%s","live","the grant lacks calendar.events — re-consent once"\n' \
      "$(printf '%s' "$CAL_SCOPES" | tr ' ' ',' | sed 's#https://www.googleapis.com/auth/##g')"
    exit 3
  fi
  printf 'calendar_write[1]{state,scope,grant,detail}:\n  "unmeasured","-","live","%s"\n' "$CAL_SCOPES_WHY"
  exit 0
}

case "${1-}" in
  create) shift; cmd_create "$@" ;;
  move) shift; cmd_move "$@" ;;
  status) cmd_status ;;
  --self-test|self-test) exec bash "$SCRIPT_DIR/tests/test_calendar_write.sh" ;;
  *) printf 'usage: calendar-write.sh create|move|status|--self-test\n' >&2; exit 2 ;;
esac

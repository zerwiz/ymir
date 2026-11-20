#!/usr/bin/env bash
# meet.sh — one command: "put a meeting with <person> in the calendar, with a Meet link".
#
#   meet.sh --with craig --at "fri 10:00" --for 30 --title "OptiCat review" [--note "text"] [--dry-run]
#
# WHY: the doors already worked — `calendar-invite.sh create … --meet` and `mail-send.sh draft` — but
# using them means an ISO timestamp, a comma-separated attendee list, and a body FILE. That is a
# developer's interface for a thing a person does with a sentence. This is the sentence.
#
#   --with    a collaborator id or name (the address comes from the registry, never typed twice)
#   --at      "fri 10:00" · "friday 10:00" · "tomorrow 14:00" · "today 16:30" · "2026-10-30 10:00"
#   --for     minutes (default 30)
#   --note    optional text: a DRAFT email is prepared, never sent
#   --dry-run print what would be created, and create nothing
#
# Google sends the invitation itself when an attendee is on the event, so one command is a real invite.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WITH=""; AT=""; FOR=30; TITLE=""; NOTE=""; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --with) WITH="${2:-}"; shift 2 ;;
    --at) AT="${2:-}"; shift 2 ;;
    --for) FOR="${2:-30}"; shift 2 ;;
    --title) TITLE="${2:-}"; shift 2 ;;
    --note) NOTE="${2:-}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) shift ;;
  esac
done
[ -n "$WITH" ] && [ -n "$AT" ] || { printf 'usage: meet.sh --with <person> --at "fri 10:00" [--for 30]\n' >&2; exit 2; }

EMAIL="$(bash "$SCRIPT_DIR/who.sh" email "$WITH" 2>/dev/null)"
if [ -z "$EMAIL" ]; then
  printf 'meet: %s has no email in the registry — that is the only thing missing.\n' "$WITH" >&2
  printf '      set it once:  bin/people/who.sh set-email %s <address>\n' "$WITH" >&2
  exit 3
fi

read -r START END < <(AT_Q="$AT" FOR_Q="$FOR" python3 - <<'PY'
import datetime as dt, os, sys, time
raw = os.environ["AT_Q"].strip().lower()
mins = int(os.environ.get("FOR_Q") or 30)
now = dt.datetime.now()
days = {"mon": 0, "tue": 1, "wed": 2, "thu": 3, "fri": 4, "sat": 5, "sun": 6}
date = None
rest = raw
for word, idx in days.items():
    if word in raw:
        delta = (idx - now.weekday()) % 7
        date = (now + dt.timedelta(days=delta)).date()
        rest = raw.replace(word + "day", "").replace(word, "")
        break
if "tomorrow" in raw:
    date = (now + dt.timedelta(days=1)).date(); rest = raw.replace("tomorrow", "")
elif "today" in raw:
    date = now.date(); rest = raw.replace("today", "")
if date is None:
    import re
    m = re.search(r"(\d{4}-\d{2}-\d{2})", raw)
    if m:
        date = dt.date.fromisoformat(m.group(1)); rest = raw.replace(m.group(1), "")
    else:
        date = now.date()
import re
m = re.search(r"(\d{1,2})[:.](\d{2})", rest)
hour, minute = (int(m.group(1)), int(m.group(2))) if m else (10, 0)
start = dt.datetime.combine(date, dt.time(hour, minute))
print(start.strftime("%Y-%m-%dT%H:%M:00"), (start + dt.timedelta(minutes=mins)).strftime("%Y-%m-%dT%H:%M:00"))
PY
)
[ -n "$START" ] && [ -n "$END" ] || { printf 'meet: could not read the time "%s"\n' "$AT" >&2; exit 4; }
TITLE="${TITLE:-Meeting with $WITH}"

if [ "$DRY" -eq 1 ]; then
  printf 'meet[1]{with,email,start,end,title,meet_link}:\n  "%s","%s","%s","%s","%s","yes"\n' \
    "$WITH" "$EMAIL" "$START" "$END" "$TITLE"
  [ -n "$NOTE" ] && printf 'meet_note: a draft email would be prepared (never sent)\n'
  exit 0
fi

bash "$ROOT/systems/snotra/services/calendar/calendar-invite.sh" create --title "$TITLE" --start "$START" --end "$END" \
  --attendees "$EMAIL" --meet 2>&1 | tail -4
if [ -n "$NOTE" ]; then
  TMP="$(mktemp)"; printf '%s\n' "$NOTE" > "$TMP"
  bash "$ROOT/systems/snotra/services/letters/mail-send.sh" draft --to "$EMAIL" --subject "$TITLE" --body "$TMP" 2>&1 | tail -2
  rm -f "$TMP"
fi

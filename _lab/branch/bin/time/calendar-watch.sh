#!/usr/bin/env bash
# calendar-watch.sh — do not walk into a meeting by accident.
#
# Reads the calendar through Mánagandr (systems/snotra/services/calendar/calendar-ask.sh) and, when an event is
# about to start, says so through the ONE door (bin/notify/send.sh) — which means the reminder
# reaches the session (the arm), the desktop, the phone and Telegram by the same policy as
# everything else.
#
#   bin/time/calendar-watch.sh                 # the 5-minute run (a systemd timer calls this)
#   bin/time/calendar-watch.sh --lead 30       # remind earlier
#   bin/time/calendar-watch.sh --dry-run
#
# Announced once per event per window, keyed `cal:<event-id>:<window>` — the door's dedupe does
# the rest, so a timer every five minutes produces one reminder, not twelve.
#
# Exit: 0 ok (including "nothing soon") · 1 the calendar could not be read · 2 usage.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

LEAD=15; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --lead) LEAD="${2:-15}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --version|-v) printf '%s\n' "$VERSION"; exit 0 ;;
    *) printf 'error: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done

JSON="$(bash "$ROOT/systems/snotra/services/calendar/calendar-ask.sh" what 2>/dev/null)"
[ -n "$JSON" ] || { printf 'calendar-watch[1]{state}: "the calendar did not answer"\n'; exit 1; }

ROOT_DIR="$ROOT" LEAD_Q="$LEAD" DRY_Q="$DRY" JSON_Q="$JSON" python3 - <<'PY'
import datetime, json, os, subprocess, sys

payload = json.loads(os.environ["JSON_Q"])
if payload.get("status") not in ("ok", "stale"):
    print(f'calendar-watch[1]{{state}}: "calendar status {payload.get("status")}"')
    sys.exit(1)

lead = int(os.environ["LEAD_Q"])
dry = os.environ["DRY_Q"] == "1"
now = datetime.datetime.now(datetime.timezone.utc)
sent = 0
soon = []

for event in payload.get("events", []):
    if event.get("all_day") or event.get("status") == "cancelled":
        continue
    start_raw = event.get("start") or ""
    if not start_raw:
        continue
    try:
        start = datetime.datetime.fromisoformat(start_raw.replace("Z", "+00:00"))
    except ValueError:
        continue
    minutes = (start - now).total_seconds() / 60
    if not (0 <= minutes <= lead):
        continue
    summary = (event.get("summary") or "(no title)").strip()
    who = event.get("attendee_count") or 0
    # the two windows are two different reminders, not two of the same one
    window = "5" if minutes <= 5 else "15"
    line = f"in {int(minutes)} min: {summary}" + (f" ({who} people)" if who else "")
    soon.append(line)
    args = [os.path.join(os.environ["ROOT_DIR"], "bin", "notify", "send.sh"),
            "--source", "calendar", "--severity", "HIGH" if window == "5" else "MEDIUM",
            "--message", line, "--key", f"cal:{event.get('id', '')}:{window}"]
    if dry:
        args.append("--dry-run")
    subprocess.run(["bash"] + args, check=False, stdout=subprocess.DEVNULL)
    sent += 1

print(f'calendar-watch[1]{{lead_min,soon,sent}}:"{lead}","{len(soon)}","{sent}"')
for line in soon:
    print(f'  "{line}"')
PY

#!/usr/bin/env bash
# participants-fill.sh — fill participant emails from the meeting's calendar event.
#
# Reads ONE calendar event (calendar-attendees.sh) and writes the addresses into the
# record's participants[].email. Names are matched exactly or as a unique substring;
# anything unresolved is reported, never guessed.
#
#   participants-fill.sh <record.json> --start ISO --title TEXT [--window-min 90]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
REC="${1-}"; shift || true
[ -n "$REC" ] && [ -r "$REC" ] || { echo "usage: participants-fill.sh <record.json> --start ISO --title TEXT" >&2; exit 2; }
START=""; TITLE=""; WIN=90
while [ $# -gt 0 ]; do case "$1" in
  --start) START="${2-}"; shift 2 ;;
  --title) TITLE="${2-}"; shift 2 ;;
  --window-min) WIN="${2-}"; shift 2 ;;
  *) echo "unknown option $1" >&2; exit 2 ;; esac; done
[ -n "$START" ] && [ -n "$TITLE" ] || { echo "need --start and --title" >&2; exit 2; }
OUT="$(bash "$ROOT/bin/time/snotra/calendar-attendees.sh" find --start "$START" --title "$TITLE" --window-min "$WIN")"
OUT_ENV="$OUT" python3 - "$REC" <<'PY'
import json,sys,re,os
rec_path=sys.argv[1]
rows=[]
for line in os.environ.get("OUT_ENV","").splitlines():
    m=re.match(r'\s*"([^"]*)","([^"]*)","([^"]*)"', line)
    if m: rows.append({"name":m.group(1),"email":m.group(2),"status":m.group(3)})
d=json.load(open(rec_path))
unresolved=[]
for p in d.get("participants",[]):
    if p.get("email"): continue
    name=(p.get("name") or "").strip().lower()
    hit=[r for r in rows if name and (name in r["name"].lower() or r["name"].lower() in name)]
    if len(hit)==1 and hit[0]["email"]:
        p["email"]=hit[0]["email"]
    else:
        unresolved.append(p.get("name"))
json.dump(d,open(rec_path,"w"),indent=2)
for p in d.get("participants",[]):
    print(f'participant\t{p.get("name")}\t{p.get("email") or "UNRESOLVED"}')
print(f'unresolved\t{len(unresolved)}')
PY

#!/usr/bin/env bash
# rodd-room.sh — the ARM HOLDER's half of Rödd's room: the one writer of <state>/rodd/room.jsonl.
#
# bin/voice/rodd-arm.sh is Rödd's door (tell · hear): it appends wakes and reads replies, and by
# design never writes the room. Its header says "the arm writes the room" — but until 2026-11-10 no
# door did, so the first Claude arm holder to hear Rödd had to append the reply by hand. This is that
# door, and it refuses anyone who is not the helm, so the room keeps ONE writer.
#
#   rodd-room.sh reply "<text>"      append {"ts","from","text"} — only the lock holder may
#   rodd-room.sh path                where the room is (from the arm lease, never a guess)
#
# The room is resolved exactly as rodd-arm.sh resolves it: from the `state=` the arm lease names.
# Env: RODD_ROOM_FROM (the speaker label; default "<seat> (arm holder)").
# Exit: 0 written · 3 not the helm / no arm held · 2 usage · 1 failed.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
verb="${1:-}"; shift || true
state="$(bash "$SCRIPT_DIR/rodd-arm.sh" who 2>/dev/null | awk -F'","' 'NR==2{print $6}')"
[ -n "$state" ] || { echo "rodd-room: no arm is held — the room has no writer" >&2; exit 3; }
room="$state/rodd/room.jsonl"
case "$verb" in
  path) printf '%s\n' "$room" ;;
  reply)
    text="${*:-}"; [ -n "$text" ] || { echo 'usage: rodd-room.sh reply "<text>"' >&2; exit 2; }
    bash "$ROOT/bin/records/ymir-state.sh" lock owned --shell-pid $$ >/dev/null 2>&1 \
      || { echo "rodd-room: this session does not hold the helm — only the arm holder answers in the room" >&2; exit 3; }
    mkdir -p "$(dirname "$room")" || exit 1
    from="${RODD_ROOM_FROM:-$(hostname -s 2>/dev/null || echo seat) (arm holder)}"
    python3 - "$room" "$from" "$text" <<'PY' || exit 1
import json, sys, time
room, who, text = sys.argv[1:4]
with open(room, "a", encoding="utf-8") as fh:
    fh.write(json.dumps({"ts": int(time.time()), "from": who, "text": " ".join(text.split())}, ensure_ascii=False) + "\n")
PY
    printf 'rodd-room[1]{verb,room,chars}:\n  "reply","%s",%s\n' "$room" "${#text}" ;;
  -h|--help|"") sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; [ -n "$verb" ] ;;
  *) echo "error: unknown verb $verb" >&2; exit 2 ;;
esac

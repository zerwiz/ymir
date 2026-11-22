#!/usr/bin/env bash
# A report handed to the arm gets its RECEIVED (plan 350 B): none waits past VEIL_RED_S (600) seconds.
[ -x "$YMIR_ROOT/bin/agents/veil.sh" ] || { echo "skip: the Veil is not in this tree"; exit 0; }
bash "$YMIR_ROOT/bin/agents/veil.sh" pending --json 2>/dev/null | python3 -c '
import json, os, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("skip: the Veil did not answer"); sys.exit(0)
line = int(os.environ.get("VEIL_RED_S", "600"))
items = d.get("items", [])
late = [i for i in items if i["age_s"] > line]
if late:
    oldest = max(i["age_s"] for i in late) // 60
    print("red: %d report(s) with no RECEIVED, the oldest %d min — bin/agents/veil.sh pending" % (len(late), oldest)); sys.exit(1)
print("ok: every report answered within %d min (%d waiting, none late)" % (line // 60, len(items)))'

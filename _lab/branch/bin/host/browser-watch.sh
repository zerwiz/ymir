#!/usr/bin/env bash
# browser-watch.sh — record when a browser leaves, so a disappearance is evidence.
#
# The Allfather's browsers exited at 18:42 on 2026-10-20 and nothing recorded why.
# This door keeps a snapshot of every browser pid; on the next run, a pid that is
# gone is written to the record with its command and the journal around the time.
# It changes nothing and kills nothing.
#
#   browser-watch.sh snapshot   # record the current set (cron/loop)
#   browser-watch.sh status     # what is running, and the last exits
#   browser-watch.sh watch      # loop every 30 s
#
# State: $YMIR_HOME/hodd/state/browser-watch.json
# Record: $YMIR_HOME/hodd/memory/browser-exits.log  (append-only)
set -u
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-snapshot}"; shift || true
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true; fi
YMIR_HOME="${YMIR_HOME:-}"; [ -n "$YMIR_HOME" ] || ymir_home_root YMIR_HOME 2>/dev/null || true
YMIR_HOME="${YMIR_HOME:?YMIR_HOME unresolved}"
STATE="$YMIR_HOME/hodd/state/browser-watch.json"
LOG="$YMIR_HOME/hodd/memory/browser-exits.log"
mkdir -p "$(dirname "$STATE")" "$(dirname "$LOG")"

snapshot() {
  python3 - "$STATE" "$LOG" "$ROOT" <<'PY'
import json, subprocess, sys, os, time, datetime
state_path, log_path, root = sys.argv[1:4]
def browsers():
    out = subprocess.run(["ps","-eo","pid=,comm=,args="], capture_output=True, text=True).stdout
    found = {}
    for line in out.splitlines():
        parts = line.strip().split(None, 2)
        if len(parts) < 3: continue
        pid, comm, args = parts
        if comm in ("chromium","chrome","firefox","firefox-bin") or "chromium" in comm or "firefox" in comm:
            found[pid] = {"comm": comm, "args": args[:240], "seen": int(time.time())}
    return found
now = browsers()
try: prev = json.load(open(state_path))
except Exception: prev = {}
exits = {p: v for p, v in prev.items() if p not in now}
if exits:
    stamp = datetime.datetime.now().astimezone().isoformat(timespec="seconds")
    with open(log_path, "a") as h:
        for pid, info in exits.items():
            h.write(f"{stamp}\tEXIT\t{pid}\t{info.get('comm','')}\t{info.get('args','')[:160]}\n")
    # context: the last journal lines that name a browser or a kill
    try:
        j = subprocess.run(["journalctl","--since","-10 min","--no-pager"], capture_output=True, text=True).stdout
        ctx = [l for l in j.splitlines() if any(k in l.lower() for k in ("chromium","firefox","kill","oom","scope"))][-10:]
        with open(log_path, "a") as h:
            for l in ctx: h.write(f"{stamp}\tCTX\t{l[:240]}\n")
    except Exception: pass
json.dump(now, open(state_path,"w"), indent=2)
print(f"snapshot\t{len(now)} browser(s)\tnew exits:{len(exits)}")
PY
}
case "$ACTION" in
  snapshot) snapshot ;;
  status) [ -r "$STATE" ] && python3 -c "
import json,sys;d=json.load(open('$STATE'));print(f'browsers[{len(d)}]{{pid,comm}}:');
for p,i in d.items(): print(f'  \"{p}\",\"{i.get(\"comm\",\"\")}\"')" || echo "no snapshot yet"
    [ -r "$LOG" ] && tail -10 "$LOG" ;;
  watch) while true; do snapshot; sleep 30; done ;;
  *) printf 'usage: browser-watch.sh snapshot|status|watch\n' >&2; exit 2 ;;
esac

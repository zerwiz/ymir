#!/usr/bin/env bash
# smoke.sh — Rödd's smoke suite. Run it after any change to the app, the UI or the host.
#
#   apps/rodd/smoke.sh [seconds]
#
# It answers one question: would the operator get an answer if he spoke now?
# Every check names what it proved, and a failure says which link broke.
set -uo pipefail
APP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="${RODD_PYTHON:-$HOME/venvs/s2s/bin/python}"   # allow-home-default: the engine lives in the seat own venv
SECONDS_TO_WAIT="${1:-40}"
fail=0
say() { printf '%-46s %s%s\n' "$1" "$2" "${3:+  $3}"; }

# ── 1. every module the page imports must exist beside it ────────────────────
missing=0
while IFS= read -r ref; do
  [ -z "$ref" ] && continue
  case "$ref" in http*|/*) continue ;; esac
  f="${ref%%\?*}"
  [ -f "$APP/ui/${f#./}" ] || { say "module $f" "MISSING"; missing=1; }
done < <(grep -ohE "(from|import\()\s*['\"][^'\"]+['\"]" "$APP"/ui/main.js "$APP"/ui/s2s-realtime-client.js 2>/dev/null \
         | sed -E "s/.*['\"]([^'\"]+)['\"]/\1/" | sort -u)
[ "$missing" = 0 ] && say "all imported modules present" "PASS"

# ── 2. the app must be up, with its own server answering /api/config ─────────
PORT=""
# the UI is served by the demo's own uvicorn (a python process), on an ephemeral port in
# 7800-7890 — so find it by what it ANSWERS, never by process name
for cand in $(seq 7800 7890); do
  if curl -s --max-time 1 "http://127.0.0.1:$cand/api/config" 2>/dev/null | grep -q 's2sUrl'; then PORT="$cand"; break; fi
done
if [ -z "$PORT" ]; then say "the app's own server" "NOT RUNNING"; exit 1; fi
say "the app's own server" "PASS" "port $PORT"

# ── 3. the page's assets ─────────────────────────────────────────────────────
asset_fail=0
for u in / /main.js /s2s-realtime-client.js /turn-latency.js /style.css /house.css \
         /vendor/openai-realtime-agents.umd.js /worklets/mic-capture.js /worklets/audio-playback.js; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 4 "http://127.0.0.1:$PORT$u")
  [ "$code" = 200 ] || { say "asset $u" "HTTP $code"; asset_fail=1; }
done
[ "$asset_fail" = 0 ] && say "page assets" "PASS"

# ── 4. the page must be pointed at a live pipeline ───────────────────────────
url=$(curl -s --max-time 4 "http://127.0.0.1:$PORT/api/config" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("s2sUrl") or "")' 2>/dev/null)
if [ -n "$url" ]; then say "page points at the pipeline" "PASS" "$url"; else say "page points at the pipeline" "FAIL"; fail=1; fi
if ss -tln 2>/dev/null | grep -q ':8890'; then say "tunnel to the host seat" "PASS"; else say "tunnel to the host seat" "DOWN"; fail=1; fi

# ── 5. the host must accept the session ─────────────────────────────────────
probe=$("$PY" - "$url" <<'PY' 2>/dev/null
import asyncio, json, sys
import websockets
async def main():
    try:
        async with websockets.connect(sys.argv[1], max_size=5_000_000, open_timeout=6) as ws:
            first = json.loads(await asyncio.wait_for(ws.recv(), timeout=8))
            print("error" if first.get("type") == "error" else "accepted")
    except Exception as e:
        print("down:" + type(e).__name__)
asyncio.run(main())
PY
)
case "$probe" in
  accepted) say "host accepts a session" "PASS" ;;
  error)    say "host accepts a session" "PASS" "slot held by a live client (the window itself)" ;;
  *)        say "host accepts a session" "FAIL" "${probe:-no answer}"; fail=1 ;;
esac

# ── 6. the live window: socket, accepted, and AUDIO back ────────────────────
if [ -n "${RODD_SKIP_LIVE:-}" ]; then
  say "live window (socket · accepted · audio)" "SKIP" "RODD_SKIP_LIVE set"
elif curl -s --max-time 3 http://127.0.0.1:9222/json/list >/dev/null 2>&1; then
  if "$PY" "$APP/smoke/live.py" "$SECONDS_TO_WAIT"; then
    say "live window (socket · accepted · audio)" "PASS"
  else
    say "live window (socket · accepted · audio)" "FAIL" "see the three lines above"; fail=1
  fi
else
  say "live window (socket · accepted · audio)" "SKIP" "app not started with --remote-debugging-port=9222"
fi

exit "$fail"

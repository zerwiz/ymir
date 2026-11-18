#!/usr/bin/env bash
# test_voice_idle.sh — the voice engine lets the card go when nobody is on the line.
#
# WHY (plan 275 item 23, measured 2026-11-14 03:16): `speech-to-speech serve` held 2,762 MiB
# of the 16 GiB card forever, so the rail could not load `qwen3.6-35b-a3b` (cudaMalloc of
# 1,184 MiB) or `apodex-1.0-mini`. The engine must idle out — and it must never cut a call.
#
# The claims this test holds:
#   1. an engine that is not raised is left alone (no systemctl stop is ever issued);
#   2. a held session keeps the card (a call is never cut off by a quiet moment);
#   3. a session left `draining` by a client that vanished does not hold the card forever;
#   4. after the quiet window the unit is stopped, and the reason is logged;
#   5. `YMIR_VOICE_IDLE_SECONDS=0` disables the idle-out entirely.
#
# A fake `systemctl` and a fake pool stand in for the engine, so nothing real is stopped.
#
# Usage: test_voice_idle.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
DOOR="$ROOT/bin/voice/voice-idle.sh"

T=$(mktemp -d)
trap '[ -n "${POOL_PID:-}" ] && kill "$POOL_PID" 2>/dev/null; rm -rf "$T"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

mkdir -p "$T/bin" "$T/home/hodd/state/voice"
: > "$T/pool.json"
cat > "$T/bin/systemctl" <<'SH'
#!/usr/bin/env bash
# fake systemctl: `is-active` follows $UNIT_ACTIVE, `stop` leaves a marker
case "$*" in
  *is-active*) [ -f "$UNIT_ACTIVE" ] && exit 0 || exit 3 ;;
  *stop*)      : > "$UNIT_STOPPED"; exit 0 ;;
esac
exit 0
SH
chmod +x "$T/bin/systemctl"
export UNIT_ACTIVE="$T/unit.active" UNIT_STOPPED="$T/unit.stopped"

# a fake engine pool that serves whatever $T/pool.json holds
python3 - "$T/port" "$T/pool.json" <<'PY' &
import json, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
portfile, body = sys.argv[1], sys.argv[2]
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            data = open(body, "rb").read() or b"{}"
        except OSError:
            data = b"{}"
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data)
    def log_message(self, *a):
        pass
srv = ThreadingHTTPServer(("127.0.0.1", 0), H)
open(portfile, "w").write(str(srv.server_address[1]))
srv.serve_forever()
PY
POOL_PID=$!
for _ in $(seq 1 50); do [ -s "$T/port" ] && break; sleep 0.1; done
PORT="$(cat "$T/port" 2>/dev/null || echo 1)"

# run <subcommand> [VAR=value …] — the door's verb first, then any overrides
run() { local cmd="$1"; shift; env -i HOME="$T/home" PATH="$T/bin:/usr/bin:/bin" YMIR_HOME="$T/home" \
        YMIR_VOICE_PORT="$PORT" UNIT_ACTIVE="$UNIT_ACTIVE" UNIT_STOPPED="$UNIT_STOPPED" \
        YMIR_VOICE_HOST_UNIT=ymir-voice-host.service "$@" bash "$DOOR" "$cmd"; }

printf 'voice idle-out — the card is borrowed\n'

# 1 — nothing raised, nothing done
rm -f "$UNIT_ACTIVE" "$UNIT_STOPPED"
out="$(run reap YMIR_VOICE_IDLE_SECONDS=5 2>&1)"
if [ ! -f "$UNIT_STOPPED" ]; then ok "an engine that is not raised is left alone"; else bad "an unraised engine is left alone" "$out"; fi

# 2 — a held session keeps the card
: > "$UNIT_ACTIVE"
printf '{"size":2,"in_use":1,"units":[{"index":0,"state":"in_use","session_id":"s1"},{"index":1,"state":"idle","session_id":null}]}\n' > "$T/pool.json"
out="$(run reap YMIR_VOICE_IDLE_SECONDS=1 2>&1)"
if [ ! -f "$UNIT_STOPPED" ] && printf '%s' "$out" | grep -q 'a call is held'; then
  ok "a held session keeps the card"
else bad "a held session keeps the card" "$out"; fi

# 3 — a session draining for over a minute is a client that vanished, not a call
printf '{"size":2,"in_use":1,"units":[{"index":0,"state":"draining","draining_for_s":300,"session_id":"s2"},{"index":1,"state":"idle","session_id":null}]}\n' > "$T/pool.json"
rm -f "$UNIT_STOPPED"
out="$(run reap YMIR_VOICE_IDLE_SECONDS=5 2>&1)"
if [ -f "$UNIT_STOPPED" ]; then ok "a long-draining session does not hold the card forever"
else bad "a long-draining session lets go" "$out"; fi

# 4 — the quiet window stops the engine, and the log says why
printf '{"size":2,"in_use":0,"units":[{"index":0,"state":"idle","session_id":null}]}\n' > "$T/pool.json"
rm -f "$UNIT_STOPPED"
out="$(run reap YMIR_VOICE_IDLE_SECONDS=5 2>&1)"
if [ -f "$UNIT_STOPPED" ] && grep -q 'idle-out: stopped ymir-voice-host.service' "$T/home/hodd/state/voice/idle.log" 2>/dev/null; then
  ok "after the quiet window the engine is stopped and the reason is logged"
else bad "the quiet window stops the engine" "$out $(cat "$T/home/hodd/state/voice/idle.log" 2>/dev/null | tail -2)"; fi

# 5 — the window can be turned off
rm -f "$UNIT_STOPPED"
out="$(run reap YMIR_VOICE_IDLE_SECONDS=0 2>&1)"
if [ ! -f "$UNIT_STOPPED" ] && printf '%s' "$out" | grep -q 'idle-out disabled'; then
  ok "YMIR_VOICE_IDLE_SECONDS=0 disables the idle-out"
else bad "the idle-out can be disabled" "$out"; fi

# 6 — status tells the truth about what it sees
out="$(run status YMIR_VOICE_IDLE_SECONDS=300 2>&1)"
if printf '%s' "$out" | grep -q '"up","idle'; then ok "status says the engine is up and idle"
else bad "status reports the engine's state" "$out"; fi

printf 'voice idle-out: %s ok / %s fail\n' "$pass" "$fail"
[ "$fail" = 0 ]

#!/usr/bin/env bash
# test_snotra_bot.sh — the Vexa door against Vexa's CURRENT contract (0.12).
#
# What this gate holds the door to:
#   * the request shape the engine actually serves: POST /bots with `platform` and
#     `native_meeting_id`, authenticated with `X-API-Key`
#   * the honest word: an accepted request prints `dispatched`, never "joined"
#   * status reads the RUNNING bots — a stored meeting row with no bot behind it is not
#     a join, and the door exits 4 saying so (the fault of plan 147)
#   * the refusals: plain HTTP off loopback, and a missing key
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
DOOR="$ROOT/bin/time/snotra/snotra-bot.sh"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf 'ok   %s\n' "$1"; }
bad(){ FAIL=$((FAIL+1)); printf 'FAIL %s — %s\n' "$1" "${2-}"; }
check(){ local n=$1; shift; if "$@" >/dev/null 2>&1; then ok "$n"; else bad "$n"; fi; }
refute(){ local n=$1; shift; if "$@" >/dev/null 2>&1; then bad "$n" "expected failure"; else ok "$n"; fi; }

TMP=$(mktemp -d); trap 'kill ${SRV:-} 2>/dev/null; rm -rf "$TMP"' EXIT
cat > "$TMP/srv.py" <<'PY'
import json,sys
from http.server import BaseHTTPRequestHandler,HTTPServer
log=open(sys.argv[2],'a')
# the running list the engine would serve; --empty flips it to prove "registered is not running"
RUNNING=[{"id":7,"platform":"google_meet","native_meeting_id":"abc-defg-hij","status":"active"}]
if len(sys.argv)>3 and sys.argv[3]=="--empty": RUNNING=[]
class H(BaseHTTPRequestHandler):
    def _send(self,code,obj):
        b=json.dumps(obj).encode(); self.send_response(code); self.send_header('Content-Type','application/json'); self.send_header('Content-Length',str(len(b))); self.end_headers(); self.wfile.write(b)
    def _log(self,method):
        n=int(self.headers.get('Content-Length') or 0); body=self.rfile.read(n).decode() if n else ""
        log.write(json.dumps({"method":method,"path":self.path,"key":self.headers.get("X-API-Key"),"body":body})+"\n"); log.flush()
    def do_POST(self):
        self._log("POST")
        self._send(201,{"id":7,"platform":"google_meet","native_meeting_id":"abc-defg-hij","status":"requested"})
    def do_GET(self):
        self._log("GET")
        if self.path == '/health': return self._send(200,{"status":"ok"})
        if self.path.startswith('/bots/status'): return self._send(200,{"running":RUNNING,"running_bots":RUNNING,"count":len(RUNNING)})
        self._send(404,{"detail":"not found"})
    def do_DELETE(self):
        self._log("DELETE")
        self._send(200,{"deleted":True})
    def log_message(self,*a): pass
HTTPServer(('127.0.0.1',int(sys.argv[1])),H).serve_forever()
PY
python3 "$TMP/srv.py" 18099 "$TMP/req.log" & SRV=$!
sleep 1
export VEXA_API_URL="http://127.0.0.1:18099" VEXA_API_KEY="test-key" VEXA_ALLOW_HTTP=1

check "join dispatches" bash -c "'$DOOR' join 'https://meet.google.com/abc-defg-hij' | grep -q '^dispatched'"
check "the door never says joined" bash -c "! '$DOOR' join 'https://meet.google.com/abc-defg-hij' | grep -q '^joined'"
check "posts to /bots" python3 -c "
import json
rows=[json.loads(l) for l in open('$TMP/req.log')]
assert any(r['method']=='POST' and r['path']=='/bots' for r in rows), [r['path'] for r in rows]"
check "request names the bot Snotra" python3 -c "
import json
rows=[json.loads(l) for l in open('$TMP/req.log')]
b=json.loads([r for r in rows if r['method']=='POST'][0]['body']);assert b['bot_name']=='Snotra'"
check "request carries the platform" python3 -c "
import json
rows=[json.loads(l) for l in open('$TMP/req.log')]
b=json.loads([r for r in rows if r['method']=='POST'][0]['body']);assert b['platform']=='google_meet'"
check "request carries the meeting code, not the URL" python3 -c "
import json
rows=[json.loads(l) for l in open('$TMP/req.log')]
b=json.loads([r for r in rows if r['method']=='POST'][0]['body']);assert b['native_meeting_id']=='abc-defg-hij', b"
check "request carries the API key header" python3 -c "
import json
rows=[json.loads(l) for l in open('$TMP/req.log')]
assert any(r.get('key')=='test-key' for r in rows)"
check "zoom link yields the numeric id" bash -c "'$DOOR' join 'https://us02web.zoom.us/j/123456789?pwd=x' >/dev/null && python3 -c \"
import json
rows=[json.loads(l) for l in open('$TMP/req.log')]
b=[json.loads(r['body']) for r in rows if r['method']=='POST'][-1];assert b['platform']=='zoom' and b['native_meeting_id']=='123456789', b\""
check "status reads the running bot" bash -c "'$DOOR' status 'https://meet.google.com/abc-defg-hij' | grep -q 'running=yes'"
kill $SRV 2>/dev/null; sleep 0.5
# a registered-but-not-running meeting: the same door, an engine with nothing running
python3 "$TMP/srv.py" 18099 "$TMP/req2.log" --empty & SRV=$!
sleep 1
refute "status refuses to call a registered meeting a join" "$DOOR" status "google_meet/abc-defg-hij"
check "and says why" bash -c "'$DOOR' status 'google_meet/abc-defg-hij' 2>&1 | grep -q 'not a join'"
check "stop answers" bash -c "'$DOOR' stop 'google_meet/abc-defg-hij' | grep -q 'stopped'"
check "health answers" bash -c "'$DOOR' health | grep -q 'up'"
unset VEXA_ALLOW_HTTP
# the refusal is about the ENDPOINT, not the meeting link: a plain-http engine off loopback
refute "a plain-HTTP engine off loopback is refused without the test flag" \
  env VEXA_API_URL="http://vexa.example.test" VEXA_API_KEY=test-key "$DOOR" join "https://meet.google.com/abc-defg-hij"
# a key is required for any engine that is not this box's own Vexa Lite (whose key the door
# reads from the container), so the refusal is measured against a remote endpoint
refute "missing key is refused" env -u VEXA_API_KEY VEXA_API_URL="https://vexa.example.test" "$DOOR" join "https://meet.google.com/abc-defg-hij"

# failover: the first endpoint is down, the second answers — clean child env
check "failover skips a dead endpoint" env VEXA_API_URLS='http://127.0.0.1:18098,http://127.0.0.1:18099' VEXA_API_KEY=test-key VEXA_ALLOW_HTTP=1 "$DOOR" join 'https://meet.google.com/abc-defg-hij'
refute "all endpoints down is refused" env VEXA_API_URLS='http://127.0.0.1:18098,http://127.0.0.1:18097' VEXA_API_KEY=test-key VEXA_ALLOW_HTTP=1 "$DOOR" join 'https://meet.google.com/abc-defg-hij'

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]

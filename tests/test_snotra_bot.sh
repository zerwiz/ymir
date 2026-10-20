#!/usr/bin/env bash
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
class H(BaseHTTPRequestHandler):
    def _send(self,code,obj):
        b=json.dumps(obj).encode(); self.send_response(code); self.send_header('Content-Type','application/json'); self.send_header('Content-Length',str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_POST(self):
        n=int(self.headers.get('Content-Length') or 0); body=self.rfile.read(n).decode()
        log.write(json.dumps({"method":"POST","path":self.path,"auth":self.headers.get("Authorization"),"body":body})+"\n"); log.flush()
        if self.path.endswith('/stop'): return self._send(200,{"id":"b1","status":"stopped"})
        self._send(201,{"id":"b1","status":"queued"})
    def do_GET(self):
        log.write(json.dumps({"method":"GET","path":self.path,"auth":self.headers.get("Authorization")})+"\n"); log.flush()
        if self.path == '/health': return self._send(200,{"status":"ok"})
        self._send(200,{"id":"b1","status":"joining","failure_reason":None})
    def log_message(self,*a): pass
HTTPServer(('127.0.0.1',int(sys.argv[1])),H).serve_forever()
PY
python3 "$TMP/srv.py" 18099 "$TMP/req.log" & SRV=$!
sleep 1
export VEXA_API_URL="http://127.0.0.1:18099" VEXA_API_KEY="test-key" VEXA_ALLOW_HTTP=1

check "join succeeds" bash -c "'$DOOR' join 'https://meet.google.com/abc' --workspace work | grep -q 'joined'"
check "request names the bot Snotra" python3 -c "
import json
rows=[json.loads(l) for l in open('$TMP/req.log')]
b=json.loads([r for r in rows if r['method']=='POST' and 'body' in r][0]['body']);assert b['bot_name']=='Snotra'"
check "request carries the platform" python3 -c "
import json
rows=[json.loads(l) for l in open('$TMP/req.log')]
b=json.loads([r for r in rows if r['method']=='POST' and 'body' in r][0]['body']);assert b['platform']=='google_meet'"
check "request carries the workspace" python3 -c "
import json
rows=[json.loads(l) for l in open('$TMP/req.log')]
b=json.loads([r for r in rows if r['method']=='POST' and 'body' in r][0]['body']);assert b['workspace']=='work'"
check "request carries the bearer token" bash -c "grep -q 'Bearer test-key' '$TMP/req.log'"
check "status answers" bash -c "'$DOOR' status b1 | grep -q 'joining'"
check "stop answers" bash -c "'$DOOR' stop b1 | grep -q 'stopped'"
unset VEXA_ALLOW_HTTP
refute "plain HTTP is refused without the test flag" "$DOOR" join "http://127.0.0.1:18099/x"
VEXA_ALLOW_HTTP=1 VEXA_API_KEY="" refute "missing key is refused" "$DOOR" join "http://127.0.0.1:18099/x"

# failover: the first endpoint is down, the second answers — clean child env
check "failover skips a dead endpoint" env VEXA_API_URLS='http://127.0.0.1:18098,http://127.0.0.1:18099' VEXA_API_KEY=test-key VEXA_ALLOW_HTTP=1 "$DOOR" join 'https://meet.google.com/abc'
refute "all endpoints down is refused" env VEXA_API_URLS='http://127.0.0.1:18098,http://127.0.0.1:18097' VEXA_API_KEY=test-key VEXA_ALLOW_HTTP=1 "$DOOR" join 'https://meet.google.com/abc' 

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]

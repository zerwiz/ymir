#!/usr/bin/env bash
# test_tell_doors.sh — the one door to every agent (plan 340): hermes-tell.sh and tell.sh.
#
# WHY (the Allfather, 2026-11-20): "we need to have terminal etc communication to other agents. also
# into hermes." The proofs are the door's three promises and its two wards:
#   - every line is stamped "[from <who>]", and the session is named by X-Hermes-Session-Id;
#   - the gateway's key is read from Hermes's own env and NEVER appears in the door's output;
#   - a session mid-turn (live lease, or subagents running) is refused, not raced;
#   - a non-loopback listener is refused before the key is sent;
#   - tell.sh resolves a name to its road, and refuses a <machine>:<who> it cannot reach yet.
#
# Everything runs against a temporary HERMES_HOME and a fake gateway on a free loopback port:
# the real Hermes, the real arm and the real panes are never touched.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HT="$ROOT/bin/agents/hermes-tell.sh"
TELL="$ROOT/bin/agents/tell.sh"
pass=0; fail=0
t() { local name=$1; shift; if "$@"; then printf '  ok   %s\n' "$name"; pass=$((pass+1)); else printf '  FAIL %s\n' "$name"; fail=$((fail+1)); fi; }

T="$(mktemp -d)"; SRV=""
trap '[ -n "$SRV" ] && kill "$SRV" 2>/dev/null; rm -rf "$T"' EXIT
H="$T/hermes"; mkdir -p "$H"
KEY="fixture-key-$RANDOM$RANDOM"
PORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
printf 'API_SERVER_ENABLED=true\nAPI_SERVER_HOST=127.0.0.1\nAPI_SERVER_PORT=%s\nAPI_SERVER_KEY="%s"\n' "$PORT" "$KEY" >"$H/.env"

# a state.db with one idle session, one mid-turn session and one with a running subagent
python3 - "$H/state.db" <<'PY'
import sqlite3, sys, time
c = sqlite3.connect(sys.argv[1]); now = time.time()
c.executescript("""
CREATE TABLE sessions (id TEXT PRIMARY KEY, source TEXT, created_source TEXT, title TEXT,
  started_at REAL, ended_at REAL, end_reason TEXT, archived INTEGER DEFAULT 0);
CREATE TABLE messages (session_id TEXT, role TEXT, content TEXT, timestamp REAL);
CREATE TABLE session_turn_leases (conversation_id TEXT PRIMARY KEY, holder TEXT, acquired_at REAL, expires_at REAL);
CREATE TABLE session_admissions (seq INTEGER PRIMARY KEY AUTOINCREMENT, target_session_id TEXT, status TEXT);
CREATE TABLE async_delegations (delegation_id TEXT PRIMARY KEY, parent_session_id TEXT, state TEXT);
""")
c.execute("INSERT INTO sessions VALUES ('local-idle0001','local','desktop','Quiet chat',?,?,'ws_orphan_reap',0)", (now-90, now-50))
c.execute("INSERT INTO sessions VALUES ('local-busy0002','local','desktop','Busy chat',?,NULL,NULL,0)", (now-60,))
c.execute("INSERT INTO sessions VALUES ('local-kids0003','local','desktop','Parent chat',?,NULL,NULL,0)", (now-30,))
c.execute("INSERT INTO messages VALUES ('local-idle0001','user','hi',?)", (now-80,))
c.execute("INSERT INTO messages VALUES ('local-busy0002','user','hi',?)", (now-20,))
c.execute("INSERT INTO messages VALUES ('local-kids0003','user','hi',?)", (now-10,))
c.execute("INSERT INTO session_turn_leases VALUES ('local-busy0002','pid=1:platform=desktop',?,?)", (now, now+600))
c.execute("INSERT INTO async_delegations VALUES ('d1','local-kids0003','running')")
c.commit()
PY

# the fake gateway: records what it was sent, answers with the session it was asked for
cat >"$T/gw.py" <<'PY'
import http.server, json, sys
port, key, log = int(sys.argv[1]), sys.argv[2], sys.argv[3]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        sid = self.headers.get("X-Hermes-Session-Id", "")
        with open(log, "a") as f:
            f.write(json.dumps({"auth": self.headers.get("Authorization") == "Bearer " + key,
                                "sid": sid, "content": body["messages"][-1]["content"]}) + "\n")
        if self.headers.get("Authorization") != "Bearer " + key:
            self.send_response(401); self.end_headers(); return
        out = json.dumps({"choices": [{"message": {"content": "fixture answer for " + sid}}]}).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("X-Hermes-Session-Id", sid); self.send_header("Content-Length", str(len(out)))
        self.end_headers(); self.wfile.write(out)
http.server.HTTPServer(("127.0.0.1", port), H).serve_forever()
PY
python3 "$T/gw.py" "$PORT" "$KEY" "$T/gw.log" & SRV=$!
for _ in $(seq 1 40); do python3 -c "import socket;socket.create_connection(('127.0.0.1',$PORT),0.2)" 2>/dev/null && break; sleep 0.1; done

export HERMES_HOME="$H"; unset HERMES_PROFILE API_SERVER_KEY 2>/dev/null || true

echo "hermes-tell.sh"
out="$("$HT" --from "agent test" --new "ping one" 2>&1)"; rc=$?
t "a new tell is answered (exit 0)" [ "$rc" -eq 0 ]
t "the answer is printed" grep -q "fixture answer for tell-" <<<"$out"
t "the line arrived stamped [from agent test]" grep -q '"content": "\[from agent test\] ping one"' "$T/gw.log"
t "the gateway saw the right key" grep -q '"auth": true' "$T/gw.log"
t "the key never appears in the door's output" bash -c '! grep -q "$1" <<<"$2"' _ "$KEY" "$out"
t "the result says handed, never done" bash -c 'grep -q "handed" <<<"$1" && ! grep -qiw "done" <<<"$1"' _ "$out"

out="$("$HT" --session idle0001 "ping two" 2>&1)"; rc=$?
t "--session by prefix continues that session" grep -q '"sid": "local-idle0001"' "$T/gw.log"
t "a session marked ended by a closed window is still addressable" [ "$rc" -eq 0 ]

where="$("$HT" --where 2>&1)"
t "--where names the listener" grep -q "listener,http://127.0.0.1:$PORT" <<<"$where"
t "--where says the key is present without showing it" bash -c 'grep -q "key,present" <<<"$1" && ! grep -q "$2" <<<"$1"' _ "$where" "$KEY"
t "--where finds the desktop session from the live desktop lease" grep -q "desktop_session,local-busy0002" <<<"$where"

n0="$(wc -l <"$T/gw.log")"
"$HT" --desktop "ping three" >/dev/null 2>&1; rc=$?
t "--desktop into a mid-turn session is refused (exit 1)" [ "$rc" -eq 1 ]
"$HT" --session kids0003 "ping four" >/dev/null 2>&1; rc=$?
t "a session with subagents running is refused (exit 1)" [ "$rc" -eq 1 ]
t "nothing reached the gateway from a refused tell" [ "$(wc -l <"$T/gw.log")" -eq "$n0" ]
"$HT" --force --session kids0003 "ping five" >/dev/null 2>&1; rc=$?
t "--force posts into a busy session" [ "$rc" -eq 0 ]

"$HT" --session nosuch "x" >/dev/null 2>&1; rc=$?
t "an unknown session is refused (exit 1)" [ "$rc" -eq 1 ]
"$HT" "$(printf 'two\nlines')" >/dev/null 2>&1; rc=$?
t "a two-line message is refused (exit 2)" [ "$rc" -eq 2 ]

cp "$H/.env" "$T/env.keep"
sed -i 's/API_SERVER_HOST=127.0.0.1/API_SERVER_HOST=192.0.2.7/' "$H/.env"
"$HT" --new "x" >/dev/null 2>&1; rc=$?
t "a non-loopback listener is refused before the key is sent" [ "$rc" -eq 2 ]
cp "$T/env.keep" "$H/.env"

echo "tell.sh"
out="$("$TELL" --dry-run hermes:idle0001 "hello" 2>&1)"; rc=$?
t "hermes:<session> takes the hermes-api road" bash -c 'grep -q "road hermes-api" <<<"$1" && [ "$2" -eq 0 ]' _ "$out" "$rc"
out="$("$TELL" --dry-run --from "agent test" arm "hello" 2>&1)"
t "arm takes the arm road, stamped" bash -c 'grep -q "road arm" <<<"$1" && grep -q "\[from agent test\] hello" <<<"$1"' _ "$out"
"$TELL" --dry-run somehost:hermes "hello" >/dev/null 2>&1; rc=$?
t "<machine>:<who> is refused by name until plan 340.5 (exit 64)" [ "$rc" -eq 64 ]
"$TELL" --dry-run arm "$(printf 'a\nb')" >/dev/null 2>&1; rc=$?
t "tell.sh refuses a two-line message (exit 64)" [ "$rc" -eq 64 ]

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

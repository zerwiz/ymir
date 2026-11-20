#!/usr/bin/env bash
# test_gimle_mcp_board.sh — the Gimlé MCP's board face, proved by command.
#
# On 2026-11-07 the served MCP answered `count 0` for every caller because it read the meeting
# record and knew no project at all, while five collaborators sat in the token file with place
# names (client projects, a person's first name) that resolved to nothing. A door
# that refuses everything for the wrong reason is indistinguishable from one that works, so these
# claims are not reviewable by reading — each one is asserted here:
#
#   1 · a place resolves to a real project                    (`Ymir` → `a-house/Ymir`)
#   2 · a name that is not a place is NAMED, never silently empty   (a person's first name → unresolved)
#   3 · a token's scope is enforced by identity, and the refusal lists what it may touch
#   4 · my_tasks returns the caller's own cards, inside their scope only — never another place's
#   5 · place_board groups by the project's own state names
#   6 · create_card and update_card refuse while the server is read-only
#   7 · with --allow-write they file and move a card, and an unknown state is refused by name
#
# The board is a STUB that serves exactly the four endpoints the reader uses, in Plane's shapes;
# nothing here touches a real board, and every fixture name is invented.
#
#   bin/gates/tests/test_gimle_mcp_board.sh
#
# Exit: 0 all green · 1 a failure (each printed by name).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MCP="$ROOT/bin/gimle/mcp-read.py"
TMP="$(mktemp -d)"
# free ports, chosen at run time: a fixed port made this test answer from a leftover server that
# happened to hold it, and a test that talks to another process can pass for the wrong reason.
free_port() { python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()'; }
PORT_STUB=$(free_port)
PORT_RO=$(free_port)
PORT_RW=$(free_port)
rc=0
say() { printf '%s\n' "$*"; }
bad() { say "  $*"; rc=1; }
ok()  { say "  $*"; }

cleanup() { [ -n "${STUB_PID:-}" ] && kill "$STUB_PID" 2>/dev/null; [ -n "${RO_PID:-}" ] && kill "$RO_PID" 2>/dev/null; [ -n "${RW_PID:-}" ] && kill "$RW_PID" 2>/dev/null; rm -rf "$TMP"; }
trap cleanup EXIT

command -v python3 >/dev/null || { say "python3 is required"; exit 1; }

# ── the stub board ───────────────────────────────────────────────────────────────────────────────
cat >"$TMP/fake-plane.py" <<'PY'
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse
PROJECTS = {"a-house": [
    {"id": "p-anvil", "name": "Anvil", "identifier": "ANVIL", "archived_at": None},
    {"id": "p-loom", "name": "Loomery", "identifier": "OPT", "archived_at": None},
    {"id": "p-old", "name": "Retired Thing", "identifier": "OLD", "archived_at": "2026-01-01T00:00:00Z"}]}
STATES = {"p-anvil": [{"id": "s-bl", "name": "Backlog"}, {"id": "s-ip", "name": "In Progress"}],
          "p-loom": [{"id": "s-td", "name": "Todo"}, {"id": "s-dn", "name": "Done"}]}
ISSUES = {"p-anvil": [{"id": "i-1", "sequence_id": 1, "name": "Retire the workspace plan shelf",
                      "state": "s-bl", "assignees": ["m1"], "target_date": "2026-11-14"}],
          "p-loom": [{"id": "i-3", "sequence_id": 3, "name": "Timeline and the first invoice",
                     "state": "s-td", "assignees": ["m1"], "target_date": "2026-11-20"}]}
MEMBERS = {"a-house": [{"id": "m1", "email": "someone@example.invalid", "display_name": "Tester"}]}
class H(BaseHTTPRequestHandler):
    def _send(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def _body(self):
        n = int(self.headers.get("Content-Length", "0") or 0)
        return json.loads(self.rfile.read(n) or b"{}") if n else {}
    def do_GET(self):  # noqa: N802
        p = urlparse(self.path).path.rstrip("/").split("/")
        if len(p) == 6 and p[5] == "projects":
            return self._send({"results": PROJECTS.get(p[4], []), "total_count": len(PROJECTS.get(p[4], []))})
        if len(p) == 6 and p[5] == "members":
            return self._send(MEMBERS.get(p[4], []))
        if len(p) == 8 and p[7] == "states":
            return self._send(STATES.get(p[6], []))
        if len(p) == 8 and p[7] == "issues":
            return self._send({"results": ISSUES.get(p[6], []), "total_count": len(ISSUES.get(p[6], []))})
        return self._send({"error": "Page not found."}, 404)
    def do_POST(self):  # noqa: N802
        p = urlparse(self.path).path.rstrip("/").split("/"); body = self._body()
        if len(p) == 8 and p[7] == "issues":
            box = ISSUES.setdefault(p[6], [])
            new = {"id": f"i-new-{len(box)+1}", "sequence_id": 40 + len(box), "name": body.get("name", ""),
                   "state": body.get("state", ""), "assignees": [], "target_date": None}
            box.append(new); return self._send(new, 201)
        if len(p) == 10 and p[7] == "issues" and p[9] == "comments":
            return self._send({"id": "c-1"}, 201)
        return self._send({"error": "Page not found."}, 404)
    def do_PATCH(self):  # noqa: N802
        p = urlparse(self.path).path.rstrip("/").split("/"); body = self._body()
        if len(p) == 9 and p[7] == "issues":
            for i in ISSUES.get(p[6], []):
                if i["id"] == p[8]:
                    if body.get("state"):
                        i["state"] = body["state"]
                    return self._send(i)
        return self._send({"error": "Page not found."}, 404)
    def log_message(self, *a):
        pass
ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
PY
python3 - "$TMP/fake-plane.py" "$PORT_STUB" <<'PY'
import sys
p, port = sys.argv[1], sys.argv[2]
s = open(p).read().replace("ThreadingHTTPServer((\"127.0.0.1\", PORT)", f"ThreadingHTTPServer((\"127.0.0.1\", {port})")
open(p, "w").write(s)
PY

printf 'ro-token tester Loomery,Quill\nrw-token tester Loomery,Quill\nother-token second Anvil\n' >"$TMP/tokens"
printf 'fake\n' >"$TMP/plane-token"
printf '{"tester":"someone@example.invalid","second":"nobody@example.invalid"}' >"$TMP/people.json"
printf '{"meetings":[]}' >"$TMP/meetings.json"

python3 "$TMP/fake-plane.py" >/dev/null 2>&1 & STUB_PID=$!
export GIMLE_PLANE_TOKEN_FILE="$TMP/plane-token" GIMLE_PEOPLE_FILE="$TMP/people.json" \
       GIMLE_PLANE_WORKSPACES=a-house GIMLE_PLANE_URL="http://127.0.0.1:$PORT_STUB"
sleep 1

start_mcp() {  # <port> <extra args…>
  local port=$1; shift
  python3 "$MCP" --port "$port" --plane --data "$TMP/meetings.json" --tokens "$TMP/tokens" \
      --audit "$TMP/access.jsonl" "$@" >/dev/null 2>&1 &
  echo $!
}
RO_PID=$(start_mcp $PORT_RO)
RW_PID=$(start_mcp $PORT_RW --allow-write)
sleep 1.5

call() {  # <port> <token> <json-tool-call> → prints {"isError":…,"data":…}
  python3 - "$1" "$2" "$3" <<'PY'
import json, sys, urllib.request
port, token, body = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])
req = urllib.request.Request(f"http://127.0.0.1:{port}/mcp", method="POST",
                            data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                                             "params": body}).encode(),
                            headers={"Authorization": f"Bearer {token}",
                                     "Content-Type": "application/json"})
r = json.loads(urllib.request.urlopen(req, timeout=20).read())
res = r.get("result", {})
text = (res.get("content") or [{}])[0].get("text", "{}")
print(json.dumps({"isError": bool(res.get("isError")), "data": json.loads(text)}))
PY
}
field() { python3 -c 'import json,sys;d=json.load(sys.stdin);print(eval(sys.argv[1],{"d":d}))' "$1"; }

# 1 · a place resolves
out=$(call $PORT_RO other-token '{"name":"place_board","arguments":{"place":"Anvil"}}')
[ "$(echo "$out" | field 'd["isError"]')" = "False" ] \
  && ok "a place resolves to a project:        ok (Anvil)" || bad "a place resolves: FAIL ($out)"

# 2 · a name that is not a place is NAMED
out=$(call $PORT_RO ro-token '{"name":"who_am_i","arguments":{}}')
[ "$(echo "$out" | field 'd["data"]["unresolved_places"]')" = "['Quill']" ] \
  && ok "a person in a place column is named:  ok (Quill)" || bad "unresolved named: FAIL ($out)"

# 3 · scope is enforced, and the refusal says what may be touched
out=$(call $PORT_RO other-token '{"name":"place_board","arguments":{"place":"Loomery"}}')
echo "$out" | grep -q "outside this token's scope" \
  && ok "scope refused by name:                ok" || bad "scope refusal: FAIL ($out)"

# 4 · my_tasks is scoped — the Loomery-only token sees Loomery's card, never Anvil's
out=$(call $PORT_RO ro-token '{"name":"my_tasks","arguments":{}}')
[ "$(echo "$out" | field 'd["data"]["count"]')" = "1" ] \
  && [ "$(echo "$out" | field 'd["data"]["rows"][0]["place"]')" = "a-house/Loomery" ] \
  && ok "my_tasks is scoped to the place:      ok (1 card, Loomery)" || bad "my_tasks scope: FAIL ($out)"

# 5 · place_board groups by the project's own state names
out=$(call $PORT_RO other-token '{"name":"place_board","arguments":{"place":"Anvil"}}')
echo "$out" | grep -q '"Backlog"' \
  && ok "the board speaks its own states:      ok (Backlog)" || bad "state names: FAIL ($out)"

# 6 · the write pair refuses while read-only
out=$(call $PORT_RO ro-token '{"name":"create_card","arguments":{"place":"Loomery","title":"x"}}')
echo "$out" | grep -q "read-only on this server" \
  && ok "create_card refuses when read-only:   ok" || bad "read-only refusal: FAIL ($out)"

# 7 · with --allow-write it files, moves, and refuses an unknown state by name
out=$(call $PORT_RW rw-token '{"name":"create_card","arguments":{"place":"Loomery","title":"Filed by the test"}}')
echo "$out" | grep -q '"created"' && ok "create_card files a ticket:           ok" \
  || bad "create_card: FAIL ($out)"
out=$(call $PORT_RW rw-token '{"name":"update_card","arguments":{"place":"Loomery","card":"3","state":"Done"}}')
echo "$out" | grep -q '"state": "Done"' && ok "update_card moves a ticket:           ok" \
  || bad "update_card: FAIL ($out)"
out=$(call $PORT_RW rw-token '{"name":"update_card","arguments":{"place":"Loomery","card":"3","state":"Nonsense"}}')
echo "$out" | grep -q "no such state" && ok "an unknown state is refused by name:  ok" \
  || bad "unknown state: FAIL ($out)"

# 8 · the audit says who read what
[ -s "$TMP/access.jsonl" ] && grep -q '"tool": "place_board"' "$TMP/access.jsonl" \
  && ok "every call is written to the audit:   ok" || bad "audit: FAIL"

say ""
if [ "$rc" = 0 ]; then say "gimle mcp board self-test: PASS"; else say "gimle mcp board self-test: FAIL"; fi
exit "$rc"

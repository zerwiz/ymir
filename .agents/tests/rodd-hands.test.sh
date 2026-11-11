#!/usr/bin/env bash
# rodd-hands.test.sh — Rödd's six hands (plan 231) reach real doors, and refuse in words.
#
# The voice had 37 tools and not one of them could ask who holds the arm, list or speak
# to a herdr Eindri, reach a Sessrúmnir seat, or make and move a meeting. Six hands close
# that. This proves, hermetically:
#
#   * each hand is DECLARED in the toolbox and WIRED to an implementation (a tool that is
#     declared and unwired is a fault the fog never shows);
#   * with no arm held, arm_who/arm_tell say so and never claim a line was sent;
#   * with no shell answering, seat_wire refuses and names the shell;
#   * with a grant that carries no calendar.events, calendar_write REFUSES by name and
#     writes nothing.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VT="$ROOT/bin/voice/voice_tools.py"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

command -v python3 >/dev/null 2>&1 || { printf '1..0 # skip python3 is absent\n'; exit 0; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export YMIR_HOME="$TMP/home"
mkdir -p "$YMIR_HOME/hodd/state"

# ── 1. declared AND wired, one door each ───────────────────────────────────────
python3 - "$VT" <<'PY'
import ast, sys
src = open(sys.argv[1], encoding="utf-8").read()
tree = ast.parse(src)
declared = set()
for node in tree.body:
    if isinstance(node, ast.Assign) and any(getattr(t, "id", "") == "TOOLS" for t in node.targets):
        for elt in node.value.elts:
            for kv in elt.keys:
                if getattr(kv, "value", "") == "name":
                    declared.add(elt.values[elt.keys.index(kv)].value)
missing_decl = []
for name in ("arm_who", "arm_tell", "eindri_list", "eindri_send", "seat_wire", "calendar_write"):
    if name not in declared:
        missing_decl.append(name)
if missing_decl:
    print("not ok - the six hands are declared in TOOLS (missing: %s)" % ", ".join(missing_decl)); sys.exit(1)
print("ok - the six hands are declared in the toolbox")
wired = set()
import re
for m in re.finditer(r'NEW_TOOLS\["([a-z_]+)"\]\s*=\s*_tool_([a-z_]+)', src):
    wired.add(m.group(1))
for m in re.finditer(r'if name == "([a-z_]+)":', src):
    wired.add(m.group(1))
unwired = [n for n in ("arm_who", "arm_tell", "eindri_list", "eindri_send", "seat_wire", "calendar_write") if n not in wired]
if unwired:
    print("not ok - every declared hand is wired to an implementation (unwired: %s)" % ", ".join(unwired)); sys.exit(1)
print("ok - every declared hand is wired to an implementation")
PY
[ $? -eq 0 ] || fail=1

# ── 2. no arm held → the answer says nobody is armed, and claims no delivery ───
ARM_OUT="$(RODD_ARM_LEASE="$TMP/no-such-lease" python3 - "$VT" <<'PY' 2>&1
import asyncio, importlib.util, sys
spec = importlib.util.spec_from_file_location("voice_tools", sys.argv[1])
mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
for tool in ("arm_who", "arm_tell"):
    args = {} if tool == "arm_who" else {"text": "a line for nobody"}
    out = asyncio.run(mod._execute(tool, args))
    print(tool, "::", (out.get("output") if isinstance(out, dict) else out))
PY
)"
case "$ARM_OUT" in
  *"arm_who :: Nobody is armed"*) ok "arm_who says nobody is armed, in words" ;;
  *) bad "arm_who says nobody is armed (got: $(printf '%s' "$ARM_OUT" | head -2 | tr '\n' ' '))" ;;
esac
case "$ARM_OUT" in
  *"arm_tell :: Nobody is armed"*) ok "arm_tell refuses when nobody is armed, instead of claiming it was sent" ;;
  *) bad "arm_tell refuses when nobody is armed (got: $(printf '%s' "$ARM_OUT" | head -2 | tr '\n' ' '))" ;;
esac

# ── 3. no Sessrúmnir shell → the seat wire refuses and names the shell ────────
DEAD_PORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
SEAT_OUT="$(SESSRUMNIR_BRIDGE="http://127.0.0.1:$DEAD_PORT" python3 - "$VT" <<'PY' 2>&1
import asyncio, importlib.util, sys
spec = importlib.util.spec_from_file_location("voice_tools", sys.argv[1])
mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
out = asyncio.run(mod._execute("seat_wire", {"action": "seats"}))
print(out.get("output") if isinstance(out, dict) else out)
PY
)"
case "$SEAT_OUT" in
  *"not answering"*) ok "with no shell, seat_wire refuses and says the shell is not answering" ;;
  *) bad "with no shell, seat_wire refuses (got: $(printf '%s' "$SEAT_OUT" | head -2 | tr '\n' ' '))" ;;
esac
case "$SEAT_OUT" in
  *"sent"*) bad "seat_wire must not claim a seat was reached when the shell is down" ;;
  *) ok "seat_wire claims nothing it did not do" ;;
esac

# ── 4. a grant without calendar.events → REFUSED, naming the scope ────────────
PORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
cat > "$TMP/fixture.py" <<'PY'
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        if self.path.startswith("/tokeninfo"):
            return self._send(200, {"scope": "openid https://www.googleapis.com/auth/gmail.readonly"})
        self._send(404, {"error": "unknown"})
    def do_POST(self):
        self.rfile.read(int(self.headers.get("content-length") or 0))
        self._send(200, {"access_token": "fixture-token"})

HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
PY
python3 "$TMP/fixture.py" "$PORT" >"$TMP/fixture.log" 2>&1 &
FIXPID=$!
trap 'kill "$FIXPID" 2>/dev/null; rm -rf "$TMP"' EXIT
i=0; while [ "$i" -lt 40 ]; do
  curl -sS -m 1 -o /dev/null "http://127.0.0.1:$PORT/tokeninfo" 2>/dev/null && break; i=$((i+1)); sleep 0.1
done

# The door resolves its grant through the vault by KEY (or through CALENDAR_SECRETS_FILE, the
# fixture road the door itself documents): secrets are read by key, never handed as values.
printf 'GOOGLE_MCP_CLIENT_ID=fixture\nGOOGLE_MCP_CLIENT_SECRET=fixture\nSNOTRA_GOOGLE_REFRESH_TOKEN=fixture\n' \
  > "$TMP/secrets.env"
CAL_OUT="$(YMIR_OAUTH_TOKEN_URL="http://127.0.0.1:$PORT/token" \
           YMIR_OAUTH_TOKENINFO_URL="http://127.0.0.1:$PORT/tokeninfo" \
           CALENDAR_SECRETS_FILE="$TMP/secrets.env" \
           YMIR_CALENDAR_INVITE_DOOR="$TMP/never-called" \
           python3 - "$VT" <<'PY' 2>&1
import asyncio, importlib.util, sys
spec = importlib.util.spec_from_file_location("voice_tools", sys.argv[1])
mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
out = asyncio.run(mod._execute("calendar_write", {"action": "create", "title": "t", "when": "2026-11-10T14:00:00"}))
print(out.get("output") if isinstance(out, dict) else out)
PY
)"
case "$CAL_OUT" in
  *calendar.events*) ok "a grant without calendar.events is REFUSED, with the scope named" ;;
  *) bad "a grant without calendar.events is refused by name (got: $(printf '%s' "$CAL_OUT" | head -3 | tr '\n' ' '))" ;;
esac
case "$CAL_OUT" in
  *calendar-invite.sh*) bad "calendar_write must not reach the write door without the scope" ;;
  *) ok "calendar_write never reached the write door — nothing was created" ;;
esac

# ── 5. every tool name is unique → the realtime session can start ──────────────
# The realtime client refuses a session that carries two tools of one name
# ("Duplicate Realtime tool names found: 'arm_who' (2 function tools) …") and refuses
# BEFORE any audio — so Rödd opened a window that could never speak. Two branches each
# added arm_who / eindri_list / eindri_send and the merge kept both copies. Caught here,
# at the gate, instead of in his ear.
DUP_OUT="$(python3 - "$VT" <<'PY' 2>&1
import ast, collections, sys
src = open(sys.argv[1], encoding="utf-8").read()
tree = ast.parse(src)
names = []
for node in tree.body:
    if isinstance(node, ast.Assign) and any(getattr(t, "id", "") == "TOOLS" for t in node.targets):
        for elt in node.value.elts:
            for kv in elt.keys:
                if getattr(kv, "value", "") == "name":
                    names.append(elt.values[elt.keys.index(kv)].value)
dupes = sorted(n for n, c in collections.Counter(names).items() if c > 1)
print("dupes:" + ",".join(dupes))
print("count:%d" % len(names))
PY
)"
case "$DUP_OUT" in
  *dupes:*)
    if printf '%s\n' "$DUP_OUT" | grep -qx 'dupes:'; then
      ok "every voice tool name is unique"
    else
      bad "voice tool names repeat — the realtime session will refuse to start: $(printf '%s\n' "$DUP_OUT" | grep '^dupes:' | cut -d: -f2-)"
    fi ;;
  *) bad "the toolbox could not be read to check its names (got: $(printf '%s' "$DUP_OUT" | head -2 | tr '\n' ' '))" ;;
esac

[ "$fail" -eq 0 ] && printf '1..1 # all claims proved\n'
exit "$fail"

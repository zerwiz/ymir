#!/usr/bin/env bash
# a2a-talk.sh — list A2A agents and talk to one (bidirectional reply).
#
#   bin/bridge/a2a-talk.sh agents                 # who is registered
#   bin/bridge/a2a-talk.sh send <peer> "<text>"   # send a task, print the reply
#
# Peer is matched by name (exact or prefix). Directory from A2A_DIRECTORY
# (default http://127.0.0.1:7777). This is the proof-of-channel; pi gets the
# same as a tool once the extension execute-API is wired.
set -u
DIR="${A2A_DIRECTORY:-http://127.0.0.1:7777}"
ACTION="${1:-agents}"; shift || true

agents_json() {
  # a2abridge 3.0.0 serves the registry at `/agents` (a bare JSON array); the
  # older directory served it at `/` as {"served_agents":[...]}. Try the current
  # door first, then the legacy one — never report "unreachable" for a 404 on one path.
  local body
  body="$(curl -s --max-time 6 "$DIR/agents" 2>/dev/null)"
  case "$body" in
    '['*|'{'*) printf '%s' "$body"; return ;;
  esac
  curl -s --max-time 6 "$DIR/" 2>/dev/null
}

case "$ACTION" in
  agents)
    agents_json | python3 -c 'import json,sys
raw=sys.stdin.read()
try:
    d=json.loads(raw) if raw.strip() else None
except Exception:
    d=None
if d is None:
    print("error: directory unreachable (%s)" % (raw[:60].strip() or "no response")); raise SystemExit(1)
ags=(d.get("served_agents") or d.get("agents") or []) if isinstance(d,dict) else d
print("a2a-agents[%d]{name,url,local}:" % len(ags))
for a in ags:
    a=a if isinstance(a,dict) else {"name":str(a)}
    print("  \"%s\",\"%s\",\"%s\"" % (a.get("name") or a.get("id") or "?", a.get("url") or a.get("endpoint") or "", str(bool(a.get("local"))).lower()))' ;;
  send)
    PEER="${1:-}"; shift || true; TEXT="${*:-}"
    [ -n "$PEER" ] && [ -n "$TEXT" ] || { printf 'error: send <peer> "<text>"\n' >&2; exit 2; }
    URL="$(agents_json | python3 -c 'import json,sys
peer=sys.argv[1]
try:
    d=json.load(sys.stdin)
    ags=(d.get("served_agents") or d.get("agents") or []) if isinstance(d,dict) else d
    for a in ags:
        a=a if isinstance(a,dict) else {"name":str(a)}
        n=a.get("name") or a.get("id") or ""
        if n==peer or n.startswith(peer):
            print(a.get("url") or a.get("endpoint") or ""); break
except Exception: pass' "$PEER")"
    [ -n "$URL" ] || { printf 'error: no peer matching "%s"\nhelp: bin/bridge/a2a-talk.sh agents\n' "$PEER" >&2; exit 1; }
    curl -s --max-time 90 -X POST "$URL" -H 'Content-Type: application/json' \
      -d "$(python3 -c 'import json,sys;print(json.dumps({"jsonrpc":"2.0","id":1,"method":"message/send","params":{"message":{"role":"user","parts":[{"kind":"text","text":sys.argv[1]}]}}}))' "$TEXT")" \
      | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); r=d.get("result",{}); st=r.get("status",{})
    parts=(st.get("message") or {}).get("parts",[])
    text="\n".join(p.get("text","") for p in parts)
    print("a2a-talk[1]{peer,state,reply}:")
    print("  \"%s\",\"%s\",\"%s\"" % (sys.argv[1], st.get("state","?"), text))
except Exception as e:
    print("error: no reply:", e)' "$PEER" ;;
  *) printf 'error: usage: bin/bridge/a2a-talk.sh agents|<send peer text>\n' >&2; exit 2 ;;
esac

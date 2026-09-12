#!/usr/bin/env bash
# a2a-talk.sh — list A2A agents and talk to one (bidirectional reply).
#
#   bin/a2a-talk.sh agents                 # who is registered
#   bin/a2a-talk.sh send <peer> "<text>"   # send a task, print the reply
#
# Peer is matched by name (exact or prefix). Directory from A2A_DIRECTORY
# (default http://127.0.0.1:7777). This is the proof-of-channel; pi gets the
# same as a tool once the extension execute-API is wired.
set -u
DIR="${A2A_DIRECTORY:-http://127.0.0.1:7777}"
ACTION="${1:-agents}"; shift || true

agents_json() { curl -s --max-time 6 "$DIR/" 2>/dev/null; }

case "$ACTION" in
  agents)
    agents_json | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); ags=d.get("served_agents",[])
    print("a2a-agents[%d]{name,url,local}:" % len(ags))
    for a in ags:
        print("  \"%s\",\"%s\",\"%s\"" % (a.get("name"), a.get("url"), str(bool(a.get("local"))).lower()))
except Exception:
    print("error: directory unreachable")' ;;
  send)
    PEER="${1:-}"; shift || true; TEXT="${*:-}"
    [ -n "$PEER" ] && [ -n "$TEXT" ] || { printf 'error: send <peer> "<text>"\n' >&2; exit 2; }
    URL="$(agents_json | python3 -c 'import json,sys
peer=sys.argv[1]
try:
    d=json.load(sys.stdin)
    for a in d.get("served_agents",[]):
        if a.get("name")==peer or (a.get("name") or "").startswith(peer):
            print(a.get("url")); break
except Exception: pass' "$PEER")"
    [ -n "$URL" ] || { printf 'error: no peer matching "%s"\nhelp: bin/a2a-talk.sh agents\n' "$PEER" >&2; exit 1; }
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
  *) printf 'error: usage: bin/a2a-talk.sh agents|<send peer text>\n' >&2; exit 2 ;;
esac

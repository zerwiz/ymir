#!/usr/bin/env bash
# a2a-talk.sh — list A2A agents and talk to one (bidirectional reply).
#
#   bin/a2a-talk.sh agents                 # who is registered
#   bin/a2a-talk.sh send <peer> "<text>"   # send a task, print the reply
#
# The engine is **a2abridge 3.x**: its directory answers `GET /agents` with a
# bare list of `{url,lastSeen}` (not `{served_agents:[…]}` — the old shape this
# wrapper once parsed). Each agent's display name lives in the card at
# `<url>/.well-known/agent-card.json`. A peer is matched by card name (exact or
# prefix) or by its URL, and may also be passed as a full `http://…` URL.
# Directory from A2A_DIRECTORY (default http://127.0.0.1:7777).
set -u
DIR="${A2A_DIRECTORY:-http://127.0.0.1:7777}"
ACTION="${1:-agents}"; shift || true

agents_json() { curl -s --max-time 6 "$DIR/agents" 2>/dev/null; }

case "$ACTION" in
  agents)
    agents_json | python3 -c 'import json,sys,urllib.request
def card_name(url):
    try:
        with urllib.request.urlopen(url.rstrip("/") + "/.well-known/agent-card.json", timeout=4) as r:
            return json.load(r).get("name", "")
    except Exception:
        return ""
try:
    ags = json.load(sys.stdin)
    if not isinstance(ags, list):
        raise ValueError("unexpected directory shape")
    print("a2a-agents[%d]{name,url,last_seen}:" % len(ags))
    for a in ags:
        url = a.get("url", "")
        print("  \"%s\",\"%s\",\"%s\"" % (card_name(url), url, a.get("lastSeen", "")))
except Exception:
    print("error: directory unreachable")' ;;
  send)
    PEER="${1:-}"; shift || true; TEXT="${*:-}"
    [ -n "$PEER" ] && [ -n "$TEXT" ] || { printf 'error: send <peer> "<text>"\n' >&2; exit 2; }
    URL="$(agents_json | python3 -c 'import json,sys,urllib.request
def card_name(url):
    try:
        with urllib.request.urlopen(url.rstrip("/") + "/.well-known/agent-card.json", timeout=4) as r:
            return json.load(r).get("name", "")
    except Exception:
        return ""
peer = sys.argv[1]
if peer.startswith("http://") or peer.startswith("https://"):
    print(peer); raise SystemExit
try:
    for a in json.load(sys.stdin):
        url = a.get("url", "")
        if url.startswith(peer) or peer.startswith(url):
            print(url); raise SystemExit
        name = card_name(url)
        if name == peer or name.startswith(peer):
            print(url); raise SystemExit
except SystemExit:
    raise
except Exception:
    pass' "$PEER")"
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

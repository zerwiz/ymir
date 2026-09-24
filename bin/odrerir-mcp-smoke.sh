#!/usr/bin/env bash
# odrerir-mcp-smoke.sh — the boards' REAL smoke: tickets and plans through the
# Skuld MCP, live (2026-09-24, the Allfather's word: "make test tickets and
# plans thru the mcp for real").
#
# The Óðrerir boards do not read a local file for tickets/plans: they call the
# Skuld MCP over its tailnet door (whynot.tailefab81.ts.net:8320). This smoke
# walks the SAME wire the browser walks — initialize (an mcp-session-id), then
# tickets/list, plans/list, tickets/get, comments/list, plans/get — and judges
# the answers the boards parse:
#   * tickets/list must answer rows shaped id|no|ns|status|pri|title|who|...
#   * a "no plans"/"silence" sentence is the EMPTY state, never a row;
#   * tickets/get must answer the multi-field row the detail sheet renders.
#
# Usage:
#   bin/odrerir-mcp-smoke.sh [--url <mcp-url>]
#   bin/odrerir-mcp-smoke.sh --version
#
# Exit: 0 every live call answered; 1 a call or its shape failed.
set -u

VERSION="1.0.0"
URL="${SKULD_URL:-http://whynot.tailefab81.ts.net:8320}"
while [ $# -gt 0 ]; do
  case "$1" in
    --url) URL=${2-}; shift 2 ;;
    -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) shift ;;
  esac
done

SESSION="$(mktemp)"; trap 'rm -f "$SESSION"' EXIT
fail=0
say() { printf '%s\n' "$*"; }

# initialize — the session id rides a header, exactly as the boards' client does.
init_code="$(curl -s -D - -o /dev/null -w '%{http_code}' --max-time 8 -X POST "$URL" \
  -H 'content-type: application/json' -H 'accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"odrerir-mcp-smoke","version":"1"}}}' 2>/dev/null | tr -d '\r')"
sid="$(printf '%s\n' "$init_code" | sed -n 's/^[Mm]cp-[Ss]ession-[Ii]d: *//p' | head -1)"
code="$(printf '%s\n' "$init_code" | tail -1)"
if [ "$code" != "200" ]; then
  say "odrerir-mcp[1]{step,state,detail}:"
  say "  \"initialize\",\"FAIL\",\"HTTP $code from $URL\""
  exit 1
fi

# one tools/call, returning the content text (or an ERR: line)
mcp_call() {  # <tool> <json-args>
  local tool="$1" args="$2" hdrs
  hdrs=(-H 'content-type: application/json' -H 'accept: application/json, text/event-stream')
  [ -n "$sid" ] && hdrs+=(-H "mcp-session-id: $sid")
  curl -s --max-time 8 -X POST "$URL" "${hdrs[@]}" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"$tool\",\"arguments\":$args}}" 2>/dev/null \
    | python3 -c '
import json, sys
text = sys.stdin.read()
# Skuld answers tools/call as an SSE stream (event: message + a data: JSON
# frame); take the last data: frame when present, else parse plain JSON.
text = text.strip()
if text.startswith("event:") or "\ndata: " in text:
    data = [l[5:].strip() for l in text.split("\n") if l.startswith("data: ") or l.startswith("data:")]
    text = data[-1] if data else "{}"
try:
    d = json.loads(text)
except Exception:
    print("ERR: unparseable answer"); raise SystemExit
if "error" in d:
    print("ERR: " + str((d.get("error") or {}).get("message")))
else:
    print(((d.get("result") or {}).get("content") or [{}])[0].get("text", ""))
'
}

tickets="$(mcp_call tickets_list '{"namespace":"ymir"}')"
plans="$(mcp_call plans_list '{"namespace":"ymir"}')"

say "odrerir-mcp[2]{board,state,rows,detail}:"
# tickets — real rows or an explicit refusal
case "$tickets" in
  ERR:*|*"MCP error"*) say "  \"tickets\",\"FAIL\",0,\"$tickets\""; fail=1 ;;
  *)
    trows="$(printf '%s\n' "$tickets" | grep -c '|' || true)"
    if [ "${trows:-0}" -gt 0 ]; then say "  \"tickets\",\"ok\",$trows,\"$(printf '%s\n' "$tickets" | head -1 | cut -c1-90)\""
    else say "  \"tickets\",\"ok\",0,\"(the book is empty)\""; fi ;;
esac
# plans — a "no plans"/"silence" sentence is the EMPTY state, never a row
case "$plans" in
  ERR:*|*"MCP error"*) say "  \"plans\",\"FAIL\",0,\"$plans\""; fail=1 ;;
  *"no plans"*|*silence*|"")
    say "  \"plans\",\"ok\",0,\"empty (the roadmap has no plans cut yet)\"" ;;
  *)
    prows="$(printf '%s\n' "$plans" | grep -c '|' || true)"
    say "  \"plans\",\"ok\",$prows,\"$(printf '%s\n' "$plans" | head -1 | cut -c1-90)\"" ;;
esac

# the detail doors, on the first real row of each (when rows exist)
tid="$(printf '%s\n' "$tickets" | head -1 | cut -d'|' -f1)"
case "$tid" in ''|*[!0-9]*) tid="";; esac
if [ -n "$tid" ]; then
  get="$(mcp_call tickets_get "{\"id\":$tid}")"
  fields="$(printf '%s' "$get" | awk -F'|' '{print NF}')"
  case "$get" in ERR:*) say "  \"tickets/get\",\"FAIL\",\"$get\""; fail=1 ;;
    *) [ "${fields:-0}" -ge 8 ] && say "  \"tickets/get\",\"ok\",\"id $tid · $fields fields\"" \
         || { say "  \"tickets/get\",\"FAIL\",\"id $tid · only $fields fields\""; fail=1; } ;;
  esac
  thread="$(mcp_call comments_list "{\"id\":$tid}")"
  case "$thread" in ERR:*) say "  \"comments/list\",\"FAIL\",\"$thread\""; fail=1 ;;
    *) say "  \"comments/list\",\"ok\",\"$(printf '%s\n' "$thread" | grep -c . || true) line(s)\"" ;; esac
fi

pid="$(printf '%s\n' "$plans" | head -1 | cut -d'|' -f1)"
case "$pid" in ''|*[!0-9]*) pid="";; esac
if [ -n "$pid" ]; then
  pget="$(mcp_call plans_get "{\"id\":$pid}")"
  case "$pget" in ERR:*) say "  \"plans/get\",\"FAIL\",\"$pget\""; fail=1 ;;
    *) say "  \"plans/get\",\"ok\",\"id $pid · $(printf '%s' "$pget" | awk -F'|' '{print NF}') fields\"" ;; esac
fi

# ALIGNMENT (2026-09-24): the tools the UI calls must EXIST on the server. The
# old hall (and the first React port) called `tickets/list` — a name the server
# never had — so the boards rang a dead door in silence. Discover the server's
# names and assert every one the boards use.
tools_json="$(curl -s --max-time 8 -X POST "$URL" \
  -H 'content-type: application/json' -H 'accept: application/json, text/event-stream' \
  ${sid:+-H "mcp-session-id: $sid"} \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}' 2>/dev/null)"
names="$(printf '%s\n' "$tools_json" | sed -n 's/^data: //p' | python3 -c '
import json, sys
text = sys.stdin.read().strip()
try:
    d = json.loads(text) if text else {}
except Exception:
    d = {}
print("\n".join(t.get("name", "") for t in (d.get("result") or {}).get("tools", [])))' 2>/dev/null)"
missing=""
for want in tickets_list tickets_get tickets_create tickets_update comments_list comments_post plans_list plans_get plans_create; do
  printf '%s\n' "$names" | grep -qx "$want" || missing="$missing $want"
done
if [ -z "$missing" ]; then
  say "  \"alignment\",\"ok\",\"every tool the boards call exists on the server\""
else
  say "  \"alignment\",\"FAIL\",\"the server does not serve:$missing\""
  fail=1
fi

[ "$fail" = 0 ] && { say 'odrerir-mcp: PASS — tickets and plans answer through the Skuld MCP'; exit 0; }
say 'odrerir-mcp: FAIL — the boards cannot read their book' >&2
exit 1
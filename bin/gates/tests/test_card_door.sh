#!/usr/bin/env bash
# test_card_door.sh — the card contract, the door, the three adapters, the ledger and the audit (gimle plan 328).
#
#   1 · the contract file alone accepts a good card and refuses a bad one                (328.1)
#   2 · card.sh refuses a card without verb+deliverable, one owner and acceptance — BY NAME (328.2 / the guard)
#   3 · one card into each board (Plane, Trello, GitHub), and the ledger names the field each could not carry (328.3)
#   4 · a move reaches the boards; a move to `doing` without a due date is refused
#   5 · the hand road: no credentials → the card is projected, the caller binds the board's id
#   6 · a second card with the same key is refused — a re-run updates, never duplicates
#   7 · report.sh prints the per-board table                                              (328.5)
#   8 · card.sh audit gives every card a verdict and deletes nothing                       (328.6)
#
# Every board is a STUB on a free port; HOME, the ledger and the contract are fenced into a temp directory, and
# every fixture name is invented. Nothing here touches a real board or the real home.
#
#   bin/gates/tests/test_card_door.sh        Exit: 0 all green · 1 a failure (each printed by name)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CARD="$ROOT/bin/boards/card.sh"
TMP="$(mktemp -d)"
rc=0
ok()  { printf '  %s\n' "$*"; }
bad() { printf '  %s\n' "$*"; rc=1; }
cleanup() { [ -n "${STUB_PID:-}" ] && kill "$STUB_PID" 2>/dev/null; rm -rf "$TMP"; }
trap cleanup EXIT

export HOME="$TMP/home" YMIR_HOME="$TMP/ymirhome" CARDS_LEDGER="$TMP/cards.jsonl" CARDS_NO_VAULT=1 \
       CARDS_CONTRACT="$ROOT/config/cards.yaml.example" CARD_WHO=tester
mkdir -p "$HOME" "$YMIR_HOME"
unset PLANE_API_BASE PLANE_API_TOKEN TRELLO_API_KEY TRELLO_TOKEN GITHUB_TOKEN TRELLO_API_BASE GITHUB_API_BASE

PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
cat >"$TMP/stub.py" <<'PY'
import json, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
LOG = sys.argv[2]
P = "/api/v1/workspaces/ws"
ROUTES = {
    ("GET", P + "/projects/p1/states/"): {"results": [{"id": "s1", "name": "Backlog"}, {"id": "s2", "name": "In Progress"}, {"id": "s3", "name": "Done"}]},
    ("GET", P + "/members/"): [{"id": "m1", "display_name": "ada"}],
    ("POST", P + "/projects/p1/issues/"): {"id": "i1", "sequence_id": 7, "name": "x"},
    ("PATCH", P + "/projects/p1/issues/i1/"): {},
    ("GET", "/1/lists/L1"): {"idBoard": "B1", "name": "Backlog"},
    ("GET", "/1/boards/B1/lists"): [{"id": "L1", "name": "Backlog"}, {"id": "L2", "name": "Doing"}, {"id": "L3", "name": "Done"}],
    ("GET", "/1/boards/B1/labels"): [],
    ("POST", "/1/labels"): {"id": "lab"},
    ("GET", "/1/boards/B1/members"): [{"id": "u1", "username": "bob", "fullName": "Bob"}],
    ("POST", "/1/cards"): {"id": "c1", "shortUrl": "https://trello.invalid/c/c1"},
    ("GET", "/1/cards/c1"): {"idBoard": "B1"},
    ("PUT", "/1/cards/c1"): {},
    ("POST", "/gh/repos/o/r/issues"): {"number": 5},
    ("PATCH", "/gh/repos/o/r/issues/5"): {},
}
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def go(self):
        n = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(n).decode() if n else ""
        path = self.path.split("?")[0]
        with open(LOG, "a") as fh:
            fh.write(json.dumps({"m": self.command, "p": path, "b": json.loads(body) if body else None}) + "\n")
        hit = ROUTES.get((self.command, path))
        self.send_response(200 if hit is not None else 404)
        self.send_header("Content-Type", "application/json"); self.end_headers()
        self.wfile.write(json.dumps(hit if hit is not None else {"error": "no route"}).encode())
    do_GET = do_POST = do_PUT = do_PATCH = go
ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
PY
python3 "$TMP/stub.py" "$PORT" "$TMP/stub.log" >/dev/null 2>&1 & STUB_PID=$!
sleep 0.8

echo "card door self-test"
# 1 · the contract file alone
out=$(cd "$ROOT/bin/boards" && python3 - <<'PY'
import cardlib as L
c = L.load_contract()
good = L.normalise({"title": "Add rate limiting to the users endpoint", "owner": "ada", "place": "loom",
                    "acceptance": ["101 calls in a minute answer 429 on the last"]}, c)
bad = L.normalise({"title": "Board", "owner": "the team", "place": "loom"}, c)
print("good", len(L.validate(good, c)), "bad", sorted({r["field"] for r in L.validate(bad, c)}))
PY
)
[ "$out" = "good 0 bad ['acceptance', 'owner', 'title']" ] && ok "the contract alone judges a card:     ok ($out)" || bad "contract: FAIL ($out)"

# 2 · the guard, by name
err=$("$CARD" add --to loom --title "Look into the login" --owner "ada and bob" 2>&1 >/dev/null); r=$?
[ $r = 1 ] && echo "$err" | grep -q '"REFUSED","acceptance"' && echo "$err" | grep -q '"REFUSED","owner"' \
  && echo "$err" | grep -q "'look into' names no deliverable" \
  && ok "a bad card is refused by name:        ok" || bad "guard: FAIL (rc=$r $err)"
err=$("$CARD" add --door mcp --to loom --title "Write the loom fixture" --owner ada --accept "it loads" 2>&1 >/dev/null)
echo "$err" | grep -q '"REFUSED","evidence"' && ok "an MCP-made card owes its evidence:   ok" || bad "provenance: FAIL ($err)"
out=$("$CARD" add --to loom --title "Write the loom fixture" --owner ada --accept "it loads in the test" 2>&1)
echo "$out" | grep -q '"added": "loom:write-the-loom-fixture"' && ok "a good card lands:                    ok" || bad "good card: FAIL ($out)"

# 3 · one card into each board — with the stubs as the boards
export PLANE_API_BASE="http://127.0.0.1:$PORT" PLANE_API_TOKEN=fake TRELLO_API_KEY=k TRELLO_TOKEN=t \
       TRELLO_API_BASE="http://127.0.0.1:$PORT/1" GITHUB_TOKEN=fake GITHUB_API_BASE="http://127.0.0.1:$PORT/gh"
for b in plane:ws/p1 trello:L1 github:o/r; do
  board=${b%%:*} target=${b#*:}
  "$CARD" add --to loom --title "Ship the $board projection" --owner ada --accept "the card reads back on $board" \
     --due 2026-12-01 --energy deep --board "$board" --target "$target" >"$TMP/$board.out" 2>"$TMP/$board.err" \
     && ok "a card lands on $board:$(printf '%*s' $((17-${#board})) '')ok ($(grep -o '"ref": "[^"]*"' "$TMP/$board.out"))" \
     || bad "$board create: FAIL ($(cat "$TMP/$board.err"))"
done
python3 - "$CARDS_LEDGER" >"$TMP/carry.txt" <<'PY'
import json, sys
for l in open(sys.argv[1]):
    r = json.loads(l)
    if r.get("verb") == "add" and r.get("ok") and r.get("board"):
        print(r["board"], "carried=" + ",".join(r["carried"]), "degraded=" + ",".join(r["degraded"]), "notes=" + " | ".join(r.get("notes") or []))
PY
grep -q '^plane .*carried=title,owner,place,status,key,due' "$TMP/carry.txt" && ok "plane carries the owner natively:     ok" || bad "plane carry: FAIL ($(cat "$TMP/carry.txt"))"
grep -q '^trello .*degraded=.*owner' "$TMP/carry.txt" && grep -q "'ada' is not a member of this board" "$TMP/carry.txt" \
  && ok "trello names the owner it could not hold: ok" || bad "trello carry: FAIL ($(cat "$TMP/carry.txt"))"
grep -q '^github .*degraded=.*due' "$TMP/carry.txt" && grep -q "names no GitHub login for 'ada'" "$TMP/carry.txt" \
  && ok "github names due and owner kept in the body: ok" || bad "github carry: FAIL ($(cat "$TMP/carry.txt"))"
grep -q "has no place for 'energy'" "$TMP/trello.err" && ok "the door SAYS what it kept in the body: ok" || bad "say-so: FAIL ($(cat "$TMP/trello.err"))"
grep -q '"p": "/1/cards".*"key:loom:ship-the-trello-projection"' "$TMP/stub.log" || grep -q '"name": "key:loom:ship-the-trello-projection"' "$TMP/stub.log" \
  && ok "trello keeps the key as a label:      ok" || bad "trello key label: FAIL"

# 4 · move
err=$("$CARD" move loom:write-the-loom-fixture --status doing 2>&1 >/dev/null)
echo "$err" | grep -q '"REFUSED","due"' && ok "doing without a due date is refused:  ok" || bad "move guard: FAIL ($err)"
"$CARD" move loom:ship-the-trello-projection --status doing >/dev/null 2>&1
grep -q '"m": "PUT", "p": "/1/cards/c1", "b": {"idList": "L2"}' "$TMP/stub.log" && ok "a move reaches the board's list:      ok" || bad "trello move: FAIL"
"$CARD" move loom:ship-the-github-projection --status done >/dev/null 2>&1
grep -q '"m": "PATCH", "p": "/gh/repos/o/r/issues/5", "b": {"state": "closed"' "$TMP/stub.log" && ok "done closes the GitHub issue:         ok" || bad "github move: FAIL"

# 5 · the hand road
unset TRELLO_API_KEY TRELLO_TOKEN
out=$("$CARD" add --to loom --title "Carry the hand-road card" --owner ada --accept "it is bound" --board trello --target L1 2>/dev/null)
echo "$out" | grep -q '"board_state": "projected"' && echo "$out" | grep -q '"then": "card.sh bind' \
  && ok "no credentials → projected, not lost: ok" || bad "hand road: FAIL ($out)"
"$CARD" bind loom:carry-the-hand-road-card --board trello --ref https://trello.invalid/c/zz >/dev/null 2>&1
"$CARD" show loom:carry-the-hand-road-card | grep -q '"ref": "https://trello.invalid/c/zz"' && ok "bind records the board's id:          ok" || bad "bind: FAIL"

# 6 · no duplicates
export TRELLO_API_KEY=k TRELLO_TOKEN=t
err=$("$CARD" add --to loom --title "Ship the trello projection" --owner ada --accept "x" --board trello --target L1 2>&1 >/dev/null)
echo "$err" | grep -q '"REFUSED","key"' && ok "a second card for one key is refused: ok" || bad "dedupe: FAIL ($err)"

# 7 · the report
out=$("$ROOT/bin/boards/report.sh" --last 30d)
echo "$out" | grep -qE '^trello +2 +1 +1 ' && echo "$out" | grep -q 'refusals by field' \
  && ok "report.sh prints the per-board table: ok" || bad "report: FAIL ($out)"

# 8 · the audit
cat >"$TMP/record.md" <<'MD'
| # | Action | Owner | State |
|---|---|---|---|
| **XA1** | **Write the loom manual** | Ada | open |
| **XA2** | **Weave the second cloth** | Ada and Bob | open |
| **XA3** | Prepare the answer | unnamed in the notes | open |
MD
cat >"$TMP/board.json" <<'JS'
{"lists":[{"name":"Project Todos","cards":[
  {"name":"XA1 — Loom manual","description":"Owner: Ada."},
  {"name":"XA2 — Second cloth","description":"Owners: Ada and Bob."},
  {"name":"XA3 — The answer","description":"No owner named."}]},
 {"name":"Decided","cards":[{"name":"P1–P2 — We weave wool","description":"Holds."}]}]}
JS
out=$("$CARD" audit --export "$TMP/board.json" --record "$TMP/record.md" --place loom --out "$TMP/audit.md")
echo "$out" | grep -q '"cards": 4' && echo "$out" | grep -q '"held": 2' && echo "$out" | grep -q '"retired": 2' \
  && grep -q 'Write the loom manual' "$TMP/audit.md" && grep -q 'Nothing was deleted' "$TMP/audit.md" \
  && ok "the audit names every card's verdict: ok" || bad "audit: FAIL ($out)"

echo
[ $rc = 0 ] && echo "card door self-test: PASS" || echo "card door self-test: FAIL"
exit $rc

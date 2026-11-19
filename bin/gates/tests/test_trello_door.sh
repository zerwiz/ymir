#!/usr/bin/env bash
# test_trello_door.sh — the house's Trello door, proved by command against a stand-in of Trello's REST.
#
# Each plan 324 row the door answers is asserted, never read:
#   F1  · a card is assigned to a register person, and read back with members[] non-empty
#   F2  · three per-person labels are created (idempotently) and attached to a card each
#   F3  · a custom field is set, an attachment added, and a board's visibility changed AFTER creation
#   F4  · a board raised from a record with three attendees is created at `org` and invites them
#   F9  · a card without `source` is refused (and recorded); with one, the source rides on the card
#   F10 · no key → a clean skip naming TRELLO_API_KEY and TRELLO_TOKEN
#   F12 · every write appends its diff to the boards audit
#   and · the token travels in an Authorization header, never in a URL
#
# The stand-in serves Trello's shapes for exactly the endpoints the door calls; every name is invented
# and nothing touches a real board. HOME, the register and the audit are fenced in a temporary dir.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DOOR="$ROOT/bin/boards/trello.sh"
TMP="$(mktemp -d)"
PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
rc=0
ok()  { printf '  %s\n' "$*"; }
bad() { printf '  %s\n' "$*"; rc=1; }
cleanup() { [ -n "${STUB:-}" ] && kill "$STUB" 2>/dev/null; rm -rf "$TMP"; }
trap cleanup EXIT

cat >"$TMP/stub.py" <<'PY'
import json, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs
LOG = sys.argv[2]
MEMBERS = [{"id": "u-ada", "username": "adalovelace", "fullName": "Ada Lovelace"},
           {"id": "u-alan", "username": "aturing", "fullName": "Alan Turing"},
           {"id": "u-me", "username": "operator1", "fullName": "The Operator"}]
BOARDS = {"b1": {"id": "b1", "name": "Anvil board", "prefs": {"permissionLevel": "private"}, "idOrganization": "o1"}}
LABELS = {"b1": [{"id": "l-red", "name": "", "color": "red"}]}
FIELDS = {"b1": [{"id": "f-est", "name": "Estimate", "type": "number"},
                 {"id": "f-ph", "name": "Phase", "type": "list",
                  "options": [{"id": "o-a", "value": {"text": "Alpha"}}, {"id": "o-b", "value": {"text": "Beta"}}]}]}
CARDS = {f"c{i}": {"id": f"c{i}", "name": f"Card {i}", "idBoard": "b1", "idList": "L1",
                   "idMembers": [], "idLabels": [], "desc": ""} for i in range(1, 4)}
ITEMS, ATT = {}, {}
class H(BaseHTTPRequestHandler):
    def _send(self, obj, code=200):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def _req(self):
        u = urlparse(self.path); q = {k: v[0] for k, v in parse_qs(u.query).items()}
        n = int(self.headers.get("Content-Length", "0") or 0)
        body = json.loads(self.rfile.read(n) or b"{}") if n else {}
        with open(LOG, "a") as fh:
            fh.write(json.dumps({"m": self.command, "url": self.path,
                                 "auth": self.headers.get("Authorization", "")[:5]}) + "\n")
        if not self.headers.get("Authorization", "").startswith("OAuth "):
            self._send({"message": "invalid key"}, 401); return None
        return u.path.rstrip("/").split("/")[2:], q, body
    def do_GET(self):  # noqa: N802
        r = self._req()
        if r is None: return
        p, q, _ = r
        if p == ["members", "me"]: return self._send({"id": "u-me", "username": "operator1"})
        if p[0] == "cards" and len(p) == 2: return self._send(CARDS[p[1]])
        if p[0] == "cards" and p[2:] == ["members"]:
            return self._send([m for m in MEMBERS if m["id"] in CARDS[p[1]]["idMembers"]])
        if p[0] == "cards" and p[2:] == ["customFieldItems"]: return self._send(ITEMS.get(p[1], []))
        if p[0] == "boards" and len(p) == 2: return self._send(BOARDS[p[1]])
        if p[0] == "boards" and p[2:] == ["members"]: return self._send(MEMBERS)
        if p[0] == "boards" and p[2:] == ["labels"]: return self._send(LABELS.setdefault(p[1], []))
        if p[0] == "boards" and p[2:] == ["customFields"]: return self._send(FIELDS.get(p[1], []))
        if p[0] == "boards" and p[2:] == ["lists"]: return self._send([{"name": "Todo"}])
        self._send({"message": "not found"}, 404)
    def do_POST(self):  # noqa: N802
        r = self._req()
        if r is None: return
        p, q, _ = r
        if p == ["labels"]:
            lab = {"id": f"l-{len(LABELS.setdefault(q['idBoard'], []))}", "name": q["name"], "color": q["color"]}
            LABELS[q["idBoard"]].append(lab); return self._send(lab)
        if p[0] == "cards" and p[2:] == ["idMembers"]:
            CARDS[p[1]]["idMembers"].append(q["value"]); return self._send(CARDS[p[1]]["idMembers"])
        if p[0] == "cards" and p[2:] == ["idLabels"]:
            CARDS[p[1]]["idLabels"].append(q["value"]); return self._send(CARDS[p[1]]["idLabels"])
        if p[0] == "cards" and p[2:] == ["attachments"]:
            ATT.setdefault(p[1], []).append(q["url"]); return self._send({"id": "a1", "url": q["url"]})
        if p == ["cards"]:
            c = {"id": "c-new", "name": q["name"], "desc": q.get("desc", ""), "idList": q["idList"]}
            CARDS["c-new"] = c; return self._send(c)
        if p == ["boards"]:
            b = {"id": "b-new", "name": q["name"], "url": "https://trello.example.invalid/b/new",
                 "prefs": {"permissionLevel": q.get("prefs_permissionLevel", "private")}}
            BOARDS["b-new"] = b; return self._send(b)
        self._send({"message": "not found"}, 404)
    def do_PUT(self):  # noqa: N802
        r = self._req()
        if r is None: return
        p, q, body = r
        if p[0] == "boards" and len(p) == 2:
            BOARDS[p[1]]["prefs"]["permissionLevel"] = q["prefs/permissionLevel"]; return self._send(BOARDS[p[1]])
        if p[0] == "boards" and p[2:] == ["members"]: return self._send({"members": [q["email"]]})
        if p[0] == "cards" and p[2] == "customField":
            items = [i for i in ITEMS.get(p[1], []) if i["idCustomField"] != p[3]]
            items.append({"idCustomField": p[3], **body}); ITEMS[p[1]] = items; return self._send({})
        self._send({"message": "not found"}, 404)
    def log_message(self, *a): pass
ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
PY
python3 "$TMP/stub.py" "$PORT" "$TMP/requests.jsonl" >/dev/null 2>&1 & STUB=$!
mkdir -p "$TMP/home/hodd/identity"
cat >"$TMP/home/hodd/identity/members.yaml" <<'Y'
members:
  - person: ada-lovelace
    scope: "*"
    role: cto
  - person: alan-turing
    scope: anvil
    role: owner
    trello: aturing
Y
printf '{"title":"Anvil sync","attendees":["ada@example.invalid",{"email":"alan@example.invalid"},"op@example.invalid"]}' >"$TMP/record.json"
export HOME="$TMP" YMIR_HOME="$TMP/home" TRELLO_NO_VAULT=1 YMIR_BOARDS_AUDIT="$TMP/audit.jsonl" \
       TRELLO_API_BASE="http://127.0.0.1:$PORT/1"
sleep 0.8
j() { python3 -c 'import json,sys;d=json.load(sys.stdin);print(eval(sys.argv[1],{"d":d}))' "$1"; }

# F10 · no key: a clean skip naming both values
out=$(env -u TRELLO_API_KEY -u TRELLO_TOKEN bash "$DOOR" status 2>&1)
echo "$out" | grep -q '"skip","TRELLO_API_KEY, TRELLO_TOKEN unset' && ok "F10 no key: skip names both values      ok" || bad "F10: FAIL ($out)"
export TRELLO_API_KEY=k-test TRELLO_TOKEN=t-test
out=$(bash "$DOOR" status 2>&1)
echo "$out" | grep -q '"up (door)"' && ok "F13 status: up (door) as operator1       ok" || bad "status: FAIL ($out)"

# F1 · assign by register person (by name) and by an explicit handle
out=$(bash "$DOOR" assign c1 ada-lovelace 2>&1)
[ "$(echo "$out" | j 'd["members"]')" = "['adalovelace']" ] && ok "F1 assign: members[] = ['adalovelace']   ok" || bad "F1: FAIL ($out)"
out=$(bash "$DOOR" assign c2 alan-turing 2>&1)
[ "$(echo "$out" | j 'd["members"]')" = "['aturing']" ] && ok "F1 assign by handle: ['aturing']        ok" || bad "F1 handle: FAIL ($out)"
out=$(bash "$DOOR" assign c3 grace-hopper 2>&1); rcx=$?
[ $rcx -ne 0 ] && echo "$out" | grep -q "not a member of this board" && ok "F1 a stranger is refused by name         ok" || bad "F1 stranger: FAIL ($out)"

# F2 · three labels, created once, each attached to its card
for spec in "Ada:c1:green" "Alan:c2:blue" "Operator:c3:purple"; do
  IFS=: read -r name card color <<<"$spec"
  bash "$DOOR" label-create b1 "$name" "$color" >/dev/null 2>&1 || bad "F2 create $name: FAIL"
  out=$(bash "$DOOR" label-attach "$card" "$name" 2>&1)
  [ "$(echo "$out" | j 'd["label"]')" = "$name" ] || bad "F2 attach $name: FAIL ($out)"
done
again=$(bash "$DOOR" label-create b1 Ada green 2>&1)
[ "$(echo "$again" | j 'd["state"]')" = "present" ] && [ "$rc" = 0 ] && ok "F2 three labels created+attached, idempotent ok" || bad "F2 idempotent: FAIL ($again)"

# F3 · custom fields, attachment, visibility after creation
out=$(bash "$DOOR" field-set c1 Estimate 5 2>&1)
[ "$(echo "$out" | j 'd["value"]')" = "{'number': '5'}" ] && ok "F3 custom field Estimate = 5            ok" || bad "F3 field: FAIL ($out)"
out=$(bash "$DOOR" field-set c1 Phase Beta 2>&1)
[ "$(echo "$out" | j 'd["value"]')" = "o-b" ] && ok "F3 list field Phase = Beta              ok" || bad "F3 list: FAIL ($out)"
out=$(bash "$DOOR" attach c1 https://example.invalid/minutes.pdf minutes 2>&1)
echo "$out" | grep -q '"attachment": "a1"' && ok "F3 attachment added                     ok" || bad "F3 attach: FAIL ($out)"
out=$(bash "$DOOR" visibility b1 org 2>&1)
[ "$(echo "$out" | j 'd["audit"]["permissionLevel"]')" = "['private', 'org']" ] && ok "F3 visibility private → org, after creation ok" || bad "F3 visibility: FAIL ($out)"

# F4 · a board from a record of three is raised once, at the workspace audience, with them invited
out=$(bash "$DOOR" board-create "Anvil sync" --org o1 --from-record "$TMP/record.json" 2>&1)
[ "$(echo "$out" | j 'd["visibility"]')" = "org" ] && [ "$(echo "$out" | j 'len(d["invited"])')" = "3" ] \
  && ok "F4 board from record: org, 3 invited    ok" || bad "F4: FAIL ($out)"

# F9 · provenance
out=$(bash "$DOOR" card-create L1 "no record" 2>&1); rcx=$?
[ $rcx -ne 0 ] && echo "$out" | grep -q 'needs `source' && ok "F9 a card without source is refused     ok" || bad "F9 refuse: FAIL ($out)"
out=$(bash "$DOOR" card-create L1 "with record" --source meetings/anvil/record.md#A3 2>&1)
[ "$(echo "$out" | j 'd["source"]')" = "meetings/anvil/record.md#A3" ] && ok "F9 with a source: on the card           ok" || bad "F9 accept: FAIL ($out)"

# F12 · the audit carries diffs
python3 - "$TMP/audit.jsonl" <<'PY' && ok "F12 audit: one diff row per write         ok" || bad "F12: FAIL"
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
acts = [r["action"] for r in rows]
want = {"assign", "create", "label", "field", "attach", "visibility", "refused"}
a = next(r for r in rows if r["action"] == "assign")
print("    audit:", json.dumps({k: a[k] for k in ("action", "object", "id", "changed")}))
sys.exit(0 if want <= set(acts) and a["changed"]["idMembers"][1] == ["u-ada"] else 1)
PY

# and · the token never rides in a URL
if grep -q 't-test\|k-test' "$TMP/requests.jsonl"; then bad "the key or token reached a URL: FAIL"
else ok "the key and token never reach a URL      ok"; fi

echo
[ "$rc" = 0 ] && echo "trello door self-test: PASS" || echo "trello door self-test: FAIL"
exit "$rc"

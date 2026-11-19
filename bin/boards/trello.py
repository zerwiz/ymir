#!/usr/bin/env python3
"""trello.py — the house's own door to Trello's REST API (plan 324 F1–F4, F9, F10, F12, F13).

Why this exists: the hosted Trello MCP cannot put a person on a card (`add_member` is documented in its
field help and absent from its action list), cannot create a label, cannot change a board's visibility,
and cannot set a custom field or add an attachment. On 2026-11-19 that left all 41 cards of a board
with nobody on them, and a board for three people had to be raised twice. Trello's own REST API does all
of it; this door speaks it.

    trello.sh status                                   up (door) as <user> · skip <the missing value>
    trello.sh me
    trello.sh board        <board>                     lists, labels, members, custom fields, visibility
    trello.sh assign       <card> <who>[,<who>…]       who = a members.yaml person, a username or a full name
    trello.sh label-create <board> <name> <color>      idempotent by name
    trello.sh label-attach <card> <label name|id>
    trello.sh field-set    <card> <field name|id> <value>      text · number · date · checkbox · list option
    trello.sh attach       <card> <url> [name]
    trello.sh visibility   <board> private|org|public  changed AFTER creation (F3/F4)
    trello.sh board-create <name> --org <workspace> [--visibility V] [--from-record <meeting.json>] [--invite a@x,b@y]
    trello.sh card-create  <list> <name> --source <path>#<id> [--desc text]

<board>, <card> and <list> are Trello ids or short links. A board created from a record whose attendees
are more than one defaults to the workspace's audience (`org`) and invites them (F4).

The key and token come from the environment or the vault, never from a file in this repository:
`TRELLO_API_KEY` and `TRELLO_TOKEN` (the token minted for the operator's own account). They travel in an
`Authorization: OAuth …` header, never in a URL. `TRELLO_API_BASE` overrides the endpoint (tests).
Every write appends WHAT changed to the boards audit (board_audit.py).
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import board_audit  # noqa: E402
import board_people  # noqa: E402

COLORS = {"green", "yellow", "orange", "red", "purple", "blue", "sky", "lime", "pink", "black"}


def out(obj):
    print(json.dumps(obj, indent=1, ensure_ascii=False))


def refuse(why: str, code: int = 1):
    print(f'trello[1]{{door,state,why}}:\n  "trello","refused","{why.replace(chr(34), chr(39))}"', file=sys.stderr)
    sys.exit(code)


def _vault() -> dict:
    if os.environ.get("TRELLO_NO_VAULT"):
        return {}
    try:
        text = subprocess.run(["bash", os.path.join(ROOT, "bin", "vault", "hodd.sh"), "emit", "secrets/platform.env"],
                              capture_output=True, text=True, timeout=20).stdout
    except Exception:  # noqa: BLE001
        return {}
    keys = {}
    for line in text.splitlines():
        line = line.strip().removeprefix("export ")
        if line.startswith("TRELLO_") and "=" in line:
            k, v = line.split("=", 1)
            keys[k] = v.strip().strip("'\"")
    return keys


def creds() -> tuple[str, str, str]:
    key, tok = os.environ.get("TRELLO_API_KEY", ""), os.environ.get("TRELLO_TOKEN", "")
    if not key or not tok:
        v = _vault()
        key, tok = key or v.get("TRELLO_API_KEY", ""), tok or v.get("TRELLO_TOKEN", "")
    missing = [n for n, val in (("TRELLO_API_KEY", key), ("TRELLO_TOKEN", tok)) if not val]
    return key, tok, ", ".join(missing)


class Trello:
    def __init__(self):
        key, tok, missing = creds()
        if missing:
            print(f'trello[1]{{door,state,why}}:\n  "trello","skip","{missing} unset (env or vault) — this seat has no Trello door"')
            sys.exit(3)
        self.base = os.environ.get("TRELLO_API_BASE", "https://api.trello.com/1").rstrip("/")
        self.auth = f'OAuth oauth_consumer_key="{key}", oauth_token="{tok}"'

    def call(self, method: str, path: str, params: dict | None = None, body: dict | None = None):
        url = self.base + path + (("?" + urllib.parse.urlencode(params)) if params else "")
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, method=method, data=data,
                                     headers={"Authorization": self.auth, "Accept": "application/json",
                                              **({"Content-Type": "application/json"} if data else {})})
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                raw = r.read().decode()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as exc:
            refuse(f"{method} {path} answered HTTP {exc.code}: {exc.read().decode('utf-8', 'replace')[:160]}")
        except urllib.error.URLError as exc:
            refuse(f"{self.base} did not answer ({exc.reason})")

    # ── reads ────────────────────────────────────────────────────────────────────────────────────
    def card(self, cid):
        return self.call("GET", f"/cards/{cid}", {"fields": "name,idBoard,idMembers,idLabels,idList"})

    def board_members(self, bid):
        return [{"id": m["id"], "username": m.get("username"), "fullName": m.get("fullName")}
                for m in self.call("GET", f"/boards/{bid}/members", {"fields": "username,fullName"})]

    def labels(self, bid):
        return self.call("GET", f"/boards/{bid}/labels", {"fields": "name,color", "limit": "1000"})

    def fields(self, bid):
        return self.call("GET", f"/boards/{bid}/customFields")

    def prefs(self, bid):
        b = self.call("GET", f"/boards/{bid}", {"fields": "name,prefs,idOrganization"})
        return b, (b.get("prefs") or {}).get("permissionLevel")


def opts(argv, names):
    o, rest, i = {}, [], 0
    while i < len(argv):
        if argv[i] in names and i + 1 < len(argv):
            o[argv[i][2:]] = argv[i + 1]
            i += 2
        else:
            rest.append(argv[i])
            i += 1
    return o, rest


def need(args, n, usage):
    if len(args) < n:
        refuse(f"usage: trello.sh {usage}", 2)


def record_attendees(path: str) -> list[str]:
    """The emails a meeting record names as attendees (`attendees`: strings or {email})."""
    try:
        doc = json.load(open(path, encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        refuse(f"the record {path} could not be read ({exc.__class__.__name__})")
    rows = doc.get("attendees") or []
    emails = []
    for a in rows:
        e = a.get("email") if isinstance(a, dict) else str(a)
        if e and "@" in e:
            emails.append(e.strip())
    return emails


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0 if argv else 2
    verb, args = argv[0], argv[1:]
    o, args = opts(args, ("--org", "--visibility", "--from-record", "--invite", "--source", "--desc"))

    if verb == "card-create":  # F9 before any credential is touched: no record, no card
        ok, src = board_people.source_ok(o.get("source", ""))
        if not ok:
            board_audit.record("trello", "refused", "card", "", where=(args or [""])[0], why=src)
            refuse(src)

    if verb == "status":
        _k, _t, missing = creds()
        if missing:
            print(f'trello[1]{{door,state,detail}}:\n  "trello","skip","{missing} unset (env or vault) — mint them on the operator account, then store them in the vault"')
            return 0
    t = Trello()

    if verb == "status":
        me = t.call("GET", "/members/me", {"fields": "username"})
        print(f'trello[1]{{door,state,detail}}:\n  "trello","up (door)","{t.base} as {me.get("username")}"')
        return 0
    if verb == "me":
        out(t.call("GET", "/members/me", {"fields": "username,fullName,idOrganizations"}))
        return 0
    if verb == "board":
        need(args, 1, "board <board>")
        b, level = t.prefs(args[0])
        out({"board": b.get("name"), "id": b.get("id"), "visibility": level,
             "lists": [l.get("name") for l in t.call("GET", f"/boards/{args[0]}/lists", {"fields": "name"})],
             "labels": [{"name": l.get("name"), "color": l.get("color")} for l in t.labels(args[0])],
             "members": [m["username"] for m in t.board_members(args[0])],
             "custom_fields": [{"name": f.get("name"), "type": f.get("type")} for f in t.fields(args[0])]})
        return 0

    if verb == "assign":  # F1
        need(args, 2, "assign <card> <who>[,<who>…]")
        c = t.card(args[0])
        mem = t.board_members(c["idBoard"])
        before = list(c.get("idMembers") or [])
        for who in [w.strip() for w in args[1].split(",") if w.strip()]:
            hit, why = board_people.find(who, mem, "trello")
            if not hit:
                board_audit.record("trello", "refused", "card", c["id"], where=c.get("name", ""), why=why)
                refuse(why)
            if hit["id"] not in before:
                t.call("POST", f"/cards/{c['id']}/idMembers", {"value": hit["id"]})
        now = t.call("GET", f"/cards/{c['id']}/members", {"fields": "username,fullName"})
        after = [m["id"] for m in now]
        row = board_audit.record("trello", "assign", "card", c["id"], where=c.get("name", ""),
                                 changed={"idMembers": [before, after]})
        out({"card": c.get("name"), "members": [m.get("username") for m in now], "audit": row["changed"]})
        return 0

    if verb == "label-create":  # F2
        need(args, 3, "label-create <board> <name> <color>")
        bid, name, color = args[0], args[1], args[2].lower()
        if color not in COLORS:
            refuse(f"colour {color!r} is not a Trello label colour ({', '.join(sorted(COLORS))})")
        for lab in t.labels(bid):
            if (lab.get("name") or "").lower() == name.lower():
                out({"label": name, "id": lab["id"], "state": "present"})
                return 0
        made = t.call("POST", "/labels", {"name": name, "color": color, "idBoard": bid})
        row = board_audit.record("trello", "create", "label", made.get("id", ""), where=bid,
                                 changed={"name": [None, name], "color": [None, color]})
        out({"label": name, "id": made.get("id"), "state": "created", "audit": row["changed"]})
        return 0

    if verb == "label-attach":
        need(args, 2, "label-attach <card> <label name|id>")
        c = t.card(args[0])
        labs = t.labels(c["idBoard"])
        hit = next((l for l in labs if l["id"] == args[1] or (l.get("name") or "").lower() == args[1].lower()), None)
        if not hit:
            refuse(f"no label {args[1]!r} on this board (labels: {', '.join(l.get('name') or l['color'] for l in labs)})")
        before = list(c.get("idLabels") or [])
        if hit["id"] not in before:
            t.call("POST", f"/cards/{c['id']}/idLabels", {"value": hit["id"]})
        after = t.card(c["id"]).get("idLabels") or []
        row = board_audit.record("trello", "label", "card", c["id"], where=c.get("name", ""),
                                 changed={"idLabels": [before, after]})
        out({"card": c.get("name"), "label": hit.get("name"), "labels": after, "audit": row["changed"]})
        return 0

    if verb == "field-set":  # F3
        need(args, 3, "field-set <card> <field name|id> <value>")
        c = t.card(args[0])
        fs = t.fields(c["idBoard"])
        f = next((x for x in fs if x["id"] == args[1] or (x.get("name") or "").lower() == args[1].lower()), None)
        if not f:
            refuse(f"no custom field {args[1]!r} on this board (fields: {', '.join(x.get('name', '') for x in fs) or 'none'})")
        val, typ = args[2], f.get("type")
        if typ == "list":
            opt = next((x for x in f.get("options") or [] if (x.get("value") or {}).get("text", "").lower() == val.lower()), None)
            if not opt:
                refuse(f"{val!r} is not an option of {f.get('name')}")
            body = {"idValue": opt["id"]}
        elif typ == "checkbox":
            body = {"value": {"checked": "true" if val.lower() in ("1", "true", "yes", "on") else "false"}}
        elif typ in ("number", "date", "text"):
            body = {"value": {typ: val}}
        else:
            refuse(f"custom field type {typ!r} is not supported by this door")
        items = t.call("GET", f"/cards/{c['id']}/customFieldItems")
        before = next((i.get("value") or i.get("idValue") for i in items if i.get("idCustomField") == f["id"]), None)
        t.call("PUT", f"/cards/{c['id']}/customField/{f['id']}/item", body=body)
        items = t.call("GET", f"/cards/{c['id']}/customFieldItems")
        after = next((i.get("value") or i.get("idValue") for i in items if i.get("idCustomField") == f["id"]), None)
        row = board_audit.record("trello", "field", "card", c["id"], where=c.get("name", ""),
                                 changed={f"customField:{f.get('name')}": [before, after]})
        out({"card": c.get("name"), "field": f.get("name"), "value": after, "audit": row["changed"]})
        return 0

    if verb == "attach":  # F3
        need(args, 2, "attach <card> <url> [name]")
        c = t.card(args[0])
        made = t.call("POST", f"/cards/{c['id']}/attachments",
                      {"url": args[1], **({"name": args[2]} if len(args) > 2 else {})})
        row = board_audit.record("trello", "attach", "card", c["id"], where=c.get("name", ""),
                                 changed={"attachment": [None, made.get("url") or args[1]]})
        out({"card": c.get("name"), "attachment": made.get("id"), "audit": row["changed"]})
        return 0

    if verb == "visibility":  # F3, F4
        need(args, 2, "visibility <board> private|org|public")
        level = args[1].lower()
        if level not in ("private", "org", "public"):
            refuse("visibility is private, org or public")
        b, before = t.prefs(args[0])
        t.call("PUT", f"/boards/{args[0]}", {"prefs/permissionLevel": level})
        _b, after = t.prefs(args[0])
        row = board_audit.record("trello", "visibility", "board", b.get("id", args[0]), where=b.get("name", ""),
                                 changed={"permissionLevel": [before, after]})
        out({"board": b.get("name"), "visibility": after, "audit": row["changed"]})
        return 0 if after == level else 1

    if verb == "board-create":  # F4
        need(args, 1, "board-create <name> --org <workspace> [--visibility V] [--from-record F] [--invite …]")
        if not o.get("org"):
            refuse("--org <workspace> is required: a board belongs to a workspace, never to a guess")
        invite = [e.strip() for e in (o.get("invite") or "").split(",") if e.strip()]
        if o.get("from-record"):
            invite += [e for e in record_attendees(o["from-record"]) if e not in invite]
        # the widest audience the record names: more than one person → the workspace, never private
        level = (o.get("visibility") or ("org" if len(invite) > 1 else "private")).lower()
        made = t.call("POST", "/boards/", {"name": args[0], "idOrganization": o["org"],
                                          "prefs_permissionLevel": level, "defaultLists": "false"})
        invited = []
        for e in invite:
            t.call("PUT", f"/boards/{made['id']}/members", {"email": e, "type": "normal"})
            invited.append(e)
        row = board_audit.record("trello", "create", "board", made.get("id", ""), where=o["org"],
                                 changed={"name": [None, args[0]], "permissionLevel": [None, level],
                                          "invited": [[], invited]})
        out({"board": args[0], "id": made.get("id"), "url": made.get("url"), "visibility": level,
             "invited": invited, "audit": row["changed"]})
        return 0

    if verb == "card-create":  # F9
        need(args, 2, "card-create <list> <name> --source <path>#<id>")
        desc = ((o.get("desc") or "") + "\n\n" if o.get("desc") else "") + f"Source: {src}"
        made = t.call("POST", "/cards", {"idList": args[0], "name": args[1], "desc": desc})
        row = board_audit.record("trello", "create", "card", made.get("id", ""), where=args[0],
                                 changed={"name": [None, args[1]], "source": [None, src]})
        out({"card": args[1], "id": made.get("id"), "source": src, "audit": row["changed"]})
        return 0

    refuse(f"unknown verb {verb} (trello.sh --help)", 2)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

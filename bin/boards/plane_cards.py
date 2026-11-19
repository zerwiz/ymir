#!/usr/bin/env python3
"""plane_cards.py — the card verbs of the Plane door (plan 324 F5), reached through `bin/boards/plane.sh`.

    plane.sh cards       <ws> <project>
    plane.sh card-create <ws> <project> <title> --source <path>#<id> [--state S] [--assign who,…] [--desc text]
    plane.sh card-move   <ws> <project> <card#> <state>
    plane.sh card-assign <ws> <project> <card#> <who>[,<who>…]

<project> is a project's name, identifier or id. Every verb first proves the base is Plane (plane_base,
F6) and says which value is missing when it cannot act (F10). A create without provenance is refused
(F9). Every write appends its diff to the boards audit (F12).
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import board_audit  # noqa: E402
import board_people  # noqa: E402
import plane_base  # noqa: E402


def die(msg: str, code: int = 1):
    print(f'plane[1]{{door,state,why}}:\n  "plane","refused","{msg.replace(chr(34), chr(39))}"', file=sys.stderr)
    sys.exit(code)


class Plane:
    def __init__(self):
        r = plane_base.resolve()
        v = plane_base.probe(r["base"], r["token"])
        if v["verdict"] == "skip":
            print(f'plane[1]{{door,state,why}}:\n  "plane","skip","{v["why"]}"')
            sys.exit(3)
        if v["verdict"] != "plane":
            die(v["why"])
        self.base, self.token = r["base"], r["token"]

    def call(self, method: str, path: str, body=None):
        req = urllib.request.Request(self.base + path, method=method,
                                     data=json.dumps(body).encode() if body is not None else None,
                                     headers={"X-Api-Key": self.token, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                raw = r.read().decode()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as exc:
            die(f"{method} {path} answered HTTP {exc.code}: {exc.read().decode('utf-8', 'replace')[:160]}")

    @staticmethod
    def rows(payload):
        return payload if isinstance(payload, list) else (payload or {}).get("results", [])

    def project(self, ws: str, want: str) -> dict:
        ps = self.rows(self.call("GET", f"/api/v1/workspaces/{ws}/projects/?per_page=100"))
        w = want.lower()
        for p in ps:
            if w in (str(p.get("id", "")).lower(), str(p.get("identifier", "")).lower(), str(p.get("name", "")).lower()):
                return p
        die(f"no project {want!r} in workspace {ws} (projects: {', '.join(p.get('name', '') for p in ps[:20])})")

    def states(self, ws, pid):
        return self.rows(self.call("GET", f"/api/v1/workspaces/{ws}/projects/{pid}/states/"))

    def state_id(self, ws, pid, name):
        sts = self.states(ws, pid)
        for s in sts:
            if s.get("name", "").lower() == name.lower():
                return s["id"], sts
        die(f"no state {name!r} in this project (states: {', '.join(s.get('name', '') for s in sts)})")

    def issues(self, ws, pid):
        return self.rows(self.call("GET", f"/api/v1/workspaces/{ws}/projects/{pid}/issues/?per_page=100"))

    def issue(self, ws, pid, seq):
        for i in self.issues(ws, pid):
            if str(i.get("sequence_id")) == str(seq):
                return i
        die(f"no card #{seq} in this project")

    def members(self, ws) -> list[dict]:
        out = []
        for m in self.rows(self.call("GET", f"/api/v1/workspaces/{ws}/members/?per_page=100")):
            m = m.get("member", m) if isinstance(m.get("member"), dict) else m
            out.append({"id": m.get("id"), "email": m.get("email"), "display_name": m.get("display_name"),
                        "fullName": " ".join(x for x in (m.get("first_name"), m.get("last_name")) if x)})
        return out

    def resolve_people(self, ws, names: str) -> list[str]:
        mem, ids = self.members(ws), []
        for who in [n.strip() for n in names.split(",") if n.strip()]:
            hit, why = board_people.find(who, mem, "plane")
            if not hit:
                die(why)
            ids.append(hit["id"])
        return ids


def opts(argv, names):
    out, rest, i = {}, [], 0
    while i < len(argv):
        if argv[i] in names and i + 1 < len(argv):
            out[argv[i][2:]] = argv[i + 1]
            i += 2
        else:
            rest.append(argv[i])
            i += 1
    return out, rest


def main(argv):
    if not argv:
        print(__doc__, file=sys.stderr)
        return 2
    verb, args = argv[0], argv[1:]
    o, args = opts(args, ("--source", "--state", "--assign", "--desc"))
    if verb == "card-create":
        ok, src = board_people.source_ok(o.get("source", ""))
        if not ok:
            board_audit.record("plane", "refused", "card", "", where=" ".join(args[:2]), why=src)
            die(src)
    p = Plane()
    if len(args) < 2:
        die("a workspace slug and a project are required")
    ws, proj = args[0], p.project(args[0], args[1])
    pid, where = proj["id"], f"{ws}/{proj.get('name')}"
    if verb == "cards":
        names = {s["id"]: s.get("name") for s in p.states(ws, pid)}
        mem = {m["id"]: (m["display_name"] or m["email"]) for m in p.members(ws)}
        rows = p.issues(ws, pid)
        print(f"cards[{len(rows)}]{{card,state,people,title}}:")
        for i in rows:
            people = ";".join(mem.get(a, a) for a in (i.get("assignees") or []))
            print(f'  {i.get("sequence_id")},"{names.get(i.get("state"), "")}","{people}","{str(i.get("name", "")).replace(chr(34), chr(39))}"')
        return 0
    if verb == "card-create":
        if len(args) < 3:
            die("a title is required")
        title = args[2]
        body = {"name": title,
                "description_html": f"<p>{o.get('desc', '')}</p><p><b>Source:</b> {src}</p>"}
        if o.get("state"):
            body["state"], _ = p.state_id(ws, pid, o["state"])
        if o.get("assign"):
            body["assignees"] = p.resolve_people(ws, o["assign"])
        made = p.call("POST", f"/api/v1/workspaces/{ws}/projects/{pid}/issues/", body)
        row = board_audit.record("plane", "create", "card", str(made.get("id")), where=where,
                                 changed={"name": [None, title], "source": [None, src],
                                          **({"state": [None, o["state"]]} if o.get("state") else {}),
                                          **({"assignees": [[], o["assign"].split(",")]} if o.get("assign") else {})})
        print(json.dumps({"created": {"card": made.get("sequence_id"), "id": made.get("id"), "source": src},
                          "audit": row["changed"]}, ensure_ascii=False))
        return 0
    if verb == "card-move":
        if len(args) < 4:
            die("card-move <ws> <project> <card#> <state>")
        i = p.issue(ws, pid, args[2])
        sid, sts = p.state_id(ws, pid, args[3])
        before = {s["id"]: s.get("name") for s in sts}.get(i.get("state"))
        p.call("PATCH", f"/api/v1/workspaces/{ws}/projects/{pid}/issues/{i['id']}/", {"state": sid})
        row = board_audit.record("plane", "move", "card", str(i["id"]), where=where,
                                 changed={"state": [before, args[3]]})
        print(json.dumps({"moved": {"card": i.get("sequence_id"), "state": args[3]}, "audit": row["changed"]}))
        return 0
    if verb == "card-assign":
        if len(args) < 4:
            die("card-assign <ws> <project> <card#> <who>[,<who>…]")
        i = p.issue(ws, pid, args[2])
        before = list(i.get("assignees") or [])
        after = sorted(set(before) | set(p.resolve_people(ws, args[3])))
        got = p.call("PATCH", f"/api/v1/workspaces/{ws}/projects/{pid}/issues/{i['id']}/", {"assignees": after})
        row = board_audit.record("plane", "assign", "card", str(i["id"]), where=where,
                                 changed={"assignees": [before, after]})
        print(json.dumps({"assigned": {"card": i.get("sequence_id"), "assignees": got.get("assignees", after)},
                          "audit": row["changed"]}))
        return 0
    die(f"unknown verb {verb}", 2)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

#!/usr/bin/env python3
"""mcp-read.py — Gimlé MCP, phase 1: the six read tools, audited, behind a token.

One server for the suite: Plane, AFFiNE and Excalidraw appear to a client as one namespace. This phase is
**read-only on purpose** — an agent that can read the record before it can write to it is a colleague; an
agent that can write first is a risk.

    POST /mcp      JSON-RPC 2.0 (MCP streamable HTTP): initialize · tools/list · tools/call
    GET  /health   liveness only

Auth: `Authorization: Bearer <token>` (or `X-API-Key`). The token file holds one token per line as
`<token> <subject>`; every call is appended to `access.jsonl` as `at · subject · tool · verdict · why`,
so the ledger can always answer *who read what*.

Refusal is a record, never a silence: a tool whose backend is not configured answers `isError` with the
reason, and the reason is logged.
"""
from __future__ import annotations

import argparse
import datetime
import hmac
import json
import os
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PROTOCOL = "2025-06-18"
SERVER_INFO = {"name": "gimle", "version": "0.1.0-read"}

TOOLS = [
    {"name": "who_am_i",
     "description": "Who the caller is, and which places they may touch.",
     "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False}},
    {"name": "list_places",
     "description": "The places this caller belongs to, with a count of what is open in each.",
     "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False}},
    {"name": "my_tasks",
     "description": "The actions owed by the caller, with due dates, across their places.",
     "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False}},
    {"name": "place_board",
     "description": "One place's open work: actions and questions, grouped by state.",
     "inputSchema": {"type": "object", "required": ["place"],
                     "properties": {"place": {"type": "string", "description": "the place (meeting or project)"}},
                     "additionalProperties": False}},
    {"name": "meeting_record",
     "description": "The decisions, questions and actions of one meeting, with their evidence.",
     "inputSchema": {"type": "object", "required": ["meeting"],
                     "properties": {"meeting": {"type": "string", "description": "meeting id or title fragment"}},
                     "additionalProperties": False}},
    {"name": "who_owes_what",
     "description": "The register across the caller's places: every owner, what they owe, and by when.",
     "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False}},
    {"name": "find_doc",
     "description": "Search AFFiNE documents and databases by title or content.",
     "inputSchema": {"type": "object", "required": ["query"],
                     "properties": {"query": {"type": "string"}}, "additionalProperties": False}},
    {"name": "read_scene",
     "description": "The elements of an Excalidraw scene that its owner has shared with the house (consented, read-only). A scene that has not been shared answers isError 'not shared' — consent is required before the house can see a board.",
     "inputSchema": {"type": "object", "required": ["scene"],
                     "properties": {"scene": {"type": "string", "description": "the scene id its owner shared"}},
                     "additionalProperties": False}},
    {"name": "create_card",
     "description": "File a ticket into one place on the board. Refused by name when the place does not resolve or is outside this token's scope, and refused outright while the server runs read-only.",
     "inputSchema": {"type": "object", "required": ["place", "title"],
                     "properties": {"place": {"type": "string", "description": "the place, e.g. Ymir or example-house/Ymir"},
                                    "title": {"type": "string"},
                                    "description": {"type": "string", "description": "plain text — the evidence, the plan number, the address of the file"},
                                    "state": {"type": "string", "description": "the state name to open in (default the project's first state)"}},
                     "additionalProperties": False}},
    {"name": "update_card",
     "description": "Move a ticket's state, and optionally add a comment carrying the evidence. Refused by name when the ticket or the state does not resolve.",
     "inputSchema": {"type": "object", "required": ["place", "card"],
                     "properties": {"place": {"type": "string"},
                                    "card": {"type": "string", "description": "the ticket's sequence number, or a fragment of its title"},
                                    "state": {"type": "string", "description": "the state name to move it to"},
                                    "comment": {"type": "string", "description": "evidence to append as a comment"}},
                     "additionalProperties": False}},
    {"name": "list_plans",
     "description": "The plans the hall mirrors for a project: the numbered plan documents served at /desk/docs. Answers honestly when a project has no mirror yet — it never pretends a plan exists.",
     "inputSchema": {"type": "object",
                     "properties": {"project": {"type": "string", "description": "a mirrored project's name (default: every project the hall mirrors)"}},
                     "additionalProperties": False}},
]


class State:
    def __init__(self, data: str, tokens: str, audit: str, scenes: str = "", board=None,
                 allow_write: bool = False, docs: str = ""):
        self.data = data
        self.tokens = tokens
        self.audit = audit
        self.scenes = scenes
        self.board = board
        self.allow_write = allow_write
        self.docs = docs
        self.lock = threading.Lock()

    def load(self) -> dict:
        try:
            with open(self.data, encoding="utf-8") as fh:
                return json.load(fh)
        except Exception:
            return {"meetings": []}

    def tokens_map(self) -> dict:
        """`<token> <subject> [places] [fleet]` — places are comma-separated; `*` means every place.

        A token that names no place may touch **nothing**: the default is deny, because a token
        with no scope is how "one token = the whole record" happened (plan 105, H4).

        The optional fourth field is the FLEET the subject belongs to (plan 172): a collaborator
        of another Ymir is a guest, not a housemate, and a ledger that cannot say which house a
        read came from cannot answer the one question an incident asks.
        """
        out = {}
        try:
            with open(self.tokens, encoding="utf-8") as fh:
                for line in fh:
                    parts = line.split()
                    if len(parts) >= 2:
                        places = parts[2].split(",") if len(parts) > 2 else []
                        fleet = parts[3] if len(parts) > 3 else ""
                        out[parts[1]] = (parts[0], [p for p in places if p]) + ((fleet,) if fleet else ())
        except Exception:
            pass
        return out

    def token_rows(self) -> list:
        """Every token line, in file order — `<token> <subject> [places] [fleet]`.

        Read as a LIST, not a dict keyed by subject: two tokens for one subject used to collapse to
        the last line, so minting a second token for a person silently revoked the first (found by
        this file's own self-test, 2026-11-07).
        """
        rows = []
        try:
            with open(self.tokens, encoding="utf-8") as fh:
                for line in fh:
                    parts = line.split()
                    if len(parts) < 2:
                        continue
                    rows.append({"token": parts[0], "subject": parts[1],
                                 "places": [p for p in (parts[2].split(",") if len(parts) > 2 else []) if p],
                                 "fleet": parts[3] if len(parts) > 3 else ""})
        except Exception:
            pass
        return rows

    def subject_for(self, presented: str) -> tuple[str, list[str]] | None:
        for row in self.token_rows():
            if hmac.compare_digest(row["token"], presented):
                return row["subject"], row["places"]
        return None

    def fleet_of(self, subject: str) -> str:
        for row in self.token_rows():
            if row["subject"] == subject:
                return str(row["fleet"] or "")
        return ""

    @staticmethod
    def may(subject_places: list[str], place: str) -> bool:
        if "*" in subject_places:
            return True
        return any(place.lower().startswith(p.lower()) for p in subject_places)

    def record(self, subject: str, tool: str, verdict: str, why: str = ""):
        row = {"at": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
               "subject": subject, "fleet": self.fleet_of(subject), "tool": tool,
               "verdict": verdict, "why": why}
        with self.lock:
            try:
                with open(self.audit, "a", encoding="utf-8") as fh:
                    fh.write(json.dumps(row, ensure_ascii=False) + "\n")
            except Exception:
                pass


def places_of(data: dict) -> dict:
    return {m.get("title") or m.get("id"): m for m in data.get("meetings", [])}


class Board:
    """The board behind the MCP — the same reader the desk uses (plan 217, G1 and G2).

    A *place* is a Plane project, named `<workspace>/<project>`. A token's place column is matched
    against that name, so `Example4` resolves and `Michael` — a person, not a project — is refused by
    name instead of answering an empty board. That silence was the fault measured on 2026-11-07: five
    collaborators seated, every one of them counting zero, and nothing saying why.
    """

    def __init__(self, reader, workspaces, docs: str = ""):
        self.reader = reader
        self.workspaces = [w for w in workspaces if w]
        self.docs = docs
        self.detail = ""

    def places(self) -> list:
        out = []
        for slug in self.workspaces:
            try:
                for p in self.reader.projects(slug):
                    out.append({"place": f"{slug}/{p.get('name', '')}", "name": p.get("name", ""),
                                "workspace": slug, "identifier": p.get("identifier", ""),
                                "id": p.get("id", "")})
            except Exception as exc:  # noqa: BLE001
                self.detail = f"{slug}: {exc.__class__.__name__}"
        return out

    def resolve(self, fragment) -> dict | None:
        """An exact project name, then the shortest containing match, then a project identifier."""
        f = str(fragment or "").strip().lower()
        if not f:
            return None
        every = self.places()
        for p in every:
            if f in (p["place"].lower(), p["name"].lower()):
                return p
        near = [p for p in every if f in p["place"].lower() or f in p["name"].lower()]
        near.sort(key=lambda p: len(p["name"]))
        if near:
            return near[0]
        for p in every:
            if p["identifier"] and p["identifier"].lower() == f:
                return p
        return None

    def open_count(self, place: dict) -> int:
        try:
            return len(self.reader.issues(place["workspace"], place["id"]))
        except Exception:  # noqa: BLE001
            return 0

    def board(self, place: dict) -> dict:
        try:
            names = {s["id"]: s.get("name", "") for s in
                     self.reader.states(place["workspace"], place["id"])}
        except Exception:  # noqa: BLE001
            names = {}
        groups: dict = {}
        for i in self.reader.issues(place["workspace"], place["id"]):
            key = names.get(i.get("state"), i.get("state") or "—")
            groups.setdefault(key, []).append({"card": i.get("sequence_id"), "title": i.get("name", ""),
                                               "due": i.get("target_date"), "id": i.get("id")})
        return groups

    def tasks(self, subject: str, places: list):
        """The caller's own cards — and only inside the places this token carries.

        `plane_reader.board_for` reads every workspace and is right for the desk, where the person is
        the scope. The MCP's scope is the PLACE on the token, so a card from a place outside it is not
        the caller's to see — measured 2026-11-07, where an Example4-only token was handed a Ymir card.
        """
        email = (self.reader._people().get(subject.lower()) or "").lower()
        rows, notes = [], []
        for place in places:
            try:
                names = {s["id"]: s.get("name", "") for s in
                         self.reader.states(place["workspace"], place["id"])}
            except Exception:  # noqa: BLE001
                names = {}
            try:
                known = {}
                for mid, shown in self.reader.members(place["workspace"]).items():
                    known[str(shown).lower()] = mid
                    known[str(mid)] = mid
                member = known.get(str(subject).lower()) or known.get(email)
            except Exception:  # noqa: BLE001
                member = None
            if not member:
                notes.append(f"{place['place']}: {subject} is not a member here")
                continue
            try:
                for i in self.reader.issues(place["workspace"], place["id"]):
                    if member not in (i.get("assignees") or []):
                        continue
                    rows.append({"place": place["place"], "card": i.get("sequence_id"),
                                 "title": i.get("name", ""),
                                 "state": names.get(i.get("state"), i.get("state") or ""),
                                 "due": i.get("target_date")})
            except Exception as exc:  # noqa: BLE001
                notes.append(f"{place['place']}: {exc.__class__.__name__}")
        rows.sort(key=lambda r: (r["due"] or "9999-99-99"))
        return rows, ("; ".join(notes) or f"{len(rows)} card(s) assigned in {len(places)} place(s)")

    def owes(self, places: list) -> list:
        rows = []
        for place in places:
            try:
                names = self.reader.members(place["workspace"])
            except Exception:  # noqa: BLE001
                names = {}
            try:
                states = {s["id"]: s.get("name", "") for s in
                          self.reader.states(place["workspace"], place["id"])}
            except Exception:  # noqa: BLE001
                states = {}
            for i in self.reader.issues(place["workspace"], place["id"]):
                rows.append({"place": place["place"], "card": i.get("sequence_id"),
                             "task": i.get("name", ""),
                             "state": states.get(i.get("state"), i.get("state") or ""),
                             "due": i.get("target_date"),
                             "owners": [names.get(a, a) for a in (i.get("assignees") or [])]})
        return rows

    def state_id(self, place: dict, wanted: str) -> str | None:
        try:
            states = self.reader.states(place["workspace"], place["id"])
        except Exception:  # noqa: BLE001
            return None
        w = str(wanted or "").strip().lower()
        if not w:
            return states[0]["id"] if states else None
        for s in states:
            if (s.get("name") or "").lower() == w:
                return s["id"]
        for s in states:
            if w in (s.get("name") or "").lower():
                return s["id"]
        return None

    def card_id(self, place: dict, wanted: str) -> dict | None:
        w = str(wanted or "").strip().lower()
        for i in self.reader.issues(place["workspace"], place["id"]):
            if str(i.get("sequence_id")) == w or (i.get("name") or "").lower() == w:
                return i
        for i in self.reader.issues(place["workspace"], place["id"]):
            if w and w in (i.get("name") or "").lower():
                return i
        return None

    def create(self, place: dict, title: str, description: str = "", state: str = "") -> dict:
        body = {"name": title}
        if description:
            body["description_html"] = f"<p>{description}</p>"
        sid = self.state_id(place, state)
        if sid:
            body["state"] = sid
        return self.reader.write(
            "POST", f"/api/v1/workspaces/{place['workspace']}/projects/{place['id']}/issues/", body)

    def update(self, place: dict, issue_id: str, state: str = "", comment: str = "") -> dict:
        out = {}
        if state:
            sid = self.state_id(place, state)
            if not sid:
                return {"error": f"no such state in {place['place']}"}
            out["issue"] = self.reader.write(
                "PATCH", f"/api/v1/workspaces/{place['workspace']}/projects/{place['id']}/issues/{issue_id}/",
                {"state": sid})
        if comment:
            try:
                out["comment"] = self.reader.write(
                    "POST",
                    f"/api/v1/workspaces/{place['workspace']}/projects/{place['id']}/issues/{issue_id}/comments/",
                    {"comment_html": f"<p>{comment}</p>"})
            except Exception as exc:  # noqa: BLE001
                # the move already landed; losing the comment must not undo it, and must be said
                out["comment_error"] = f"{exc.__class__.__name__}: the move landed, the comment did not"
        return out

    def plans(self, project: str = "") -> dict:
        """The mirrored plan documents — the same files the desk serves at /desk/docs."""
        root = self.docs
        if not root or not os.path.isdir(root):
            return {"projects": [], "detail": "the hall mirrors no documents on this host yet"}
        names = [project] if project else sorted(os.listdir(root))
        out = []
        for name in names:
            shelf = os.path.join(root, name)
            if not os.path.isdir(shelf):
                continue
            files = []
            for fn in sorted(os.listdir(shelf)):
                if not fn.endswith(".md"):
                    continue
                head = ""
                try:
                    with open(os.path.join(shelf, fn), encoding="utf-8") as fh:
                        for line in fh:
                            if line.startswith("# "):
                                head = line[2:].strip()
                                break
                except OSError:
                    pass
                files.append({"file": fn, "heading": head,
                              "url": f"/desk/docs/{name}/{fn}"})
            out.append({"project": name, "plans": files, "count": len(files)})
        if not out:
            return {"projects": [], "detail": f"no mirrored documents for '{project}'" if project
                    else "the hall mirrors no project yet"}
        return {"projects": out}


def result(payload, is_error=False):
    return {"content": [{"type": "text", "text": json.dumps(payload, indent=1, ensure_ascii=False)}],
            "isError": is_error}


def allowed(visible: list, place: dict) -> bool:
    """Is this place among the ones the token resolved to? Scope by identity, never by string prefix.

    A token says `Ymir`; the board's place is `example-house/Ymir`. Prefix matching refused the
    caller's own place (measured 2026-11-07), so the resolved ids are compared instead.
    """
    return any(v["id"] == place["id"] for v in visible)


def visible_on_board(st: State, places_allowed: list[str]):
    """The places this token may touch, as the board knows them, plus the names that resolve to nothing.

    A name in the token's place column that is not a project on the board is returned in `unresolved`
    rather than dropped: that list is the correction of the 2026-11-07 fault, where five seated
    collaborators silently counted zero.
    """
    board = st.board
    if board is None:
        return [], []
    every = board.places()
    if not places_allowed or "*" in places_allowed:
        return every, []
    visible, unresolved = [], []
    for name in places_allowed:
        hit = board.resolve(name)
        if hit:
            if hit["id"] not in [v["id"] for v in visible]:
                visible.append(hit)
        else:
            unresolved.append(name)
    return visible, unresolved


def call_tool(st: State, subject: str, places_allowed: list[str], name: str, args: dict):
    data = st.load()
    places = places_of(data)
    board = st.board
    visible, unresolved = visible_on_board(st, places_allowed)

    if name == "who_am_i":
        if board is not None:
            return result({"subject": subject,
                           "backend": "plane",
                           "phase": "read-write" if st.allow_write else "read-only",
                           "allowed_places": [v["place"] for v in visible],
                           "unresolved_places": unresolved,
                           "board_detail": board.detail,
                           "meetings_in_the_record": len(places)})
        return result({"subject": subject, "allowed_places": places, "places_in_the_record": sorted(places),
                       "phase": "read-only"})

    if name == "list_places":
        if board is not None:
            return result({"backend": "plane",
                           "places": [{"place": v["place"], "identifier": v["identifier"],
                                       "open": board.open_count(v)} for v in visible],
                           "unresolved": unresolved,
                           "detail": board.detail})
        shown = {k: v for k, v in places.items() if st.may(places_allowed, k)}
        counts = {k: len(v.get("actions", [])) + len(v.get("questions", [])) for k, v in shown.items()}
        return result({"places": [{"place": k, "open": n} for k, n in counts.items()],
                       "refused": len(places) - len(shown)})

    if name == "my_tasks":
        if board is not None:
            cards, detail = board.tasks(subject, visible)
            return result({"subject": subject, "backend": "plane", "count": len(cards),
                           "rows": cards, "detail": detail, "unresolved_places": unresolved})
        rows = []
        refused = 0
        for place, m in places.items():
            if not st.may(places_allowed, place):
                refused += 1
                continue
            for a in m.get("actions", []):
                owner = str(a.get("owner", ""))
                if subject.lower() not in owner.lower():
                    continue
                rows.append({"place": place, "task": a.get("text"), "owner": owner,
                             "due": a.get("due"), "evidence": a.get("evidence")})
        return result({"subject": subject, "count": len(rows), "rows": rows, "places_refused": refused})

    if name == "who_owes_what":
        if board is not None:
            rows = board.owes(visible)
            return result({"backend": "plane", "count": len(rows), "rows": rows,
                           "places": [v["place"] for v in visible], "unresolved_places": unresolved})
        rows, refused = [], 0
        for place, m in places.items():
            if not st.may(places_allowed, place):
                refused += 1
                continue
            for a in m.get("actions", []):
                rows.append({"place": place, "task": a.get("text"), "owner": str(a.get("owner", "")),
                             "due": a.get("due")})
        return result({"subject": subject, "count": len(rows), "rows": rows, "places_refused": refused})

    if name == "place_board":
        target = str(args.get("place", "")).strip()
        if board is not None:
            hit = board.resolve(target)
            if hit is None:
                return result({"error": f"no such place on the board: {target}",
                               "places": [v["place"] for v in board.places()][:40],
                               "unresolved": unresolved}, True)
            if not allowed(visible, hit):
                return result({"error": "that place is outside this token's scope",
                               "place": hit["place"],
                               "allowed_places": [v["place"] for v in visible]}, True)
            return result({"place": hit["place"], "identifier": hit["identifier"],
                           "backend": "plane", "board": board.board(hit)})
        for place, m in places.items():
            if target and target.lower() in place.lower():
                if not st.may(places_allowed, place):
                    return result({"error": "that place is outside this token's scope", "place": place}, True)
                return result({"place": place,
                               "actions": m.get("actions", []),
                               "questions": m.get("questions", [])})
        return result({"error": "no such place in the record", "places": sorted(places)}, True)

    if name == "meeting_record":
        target = str(args.get("meeting", "")).lower()
        for place, m in places.items():
            if target and (target in place.lower() or target == m.get("id", "")):
                if not st.may(places_allowed, place):
                    return result({"error": "that meeting is outside this token's scope", "meeting": place}, True)
                return result({"meeting": place,
                               "decisions": m.get("decisions", []),
                               "questions": m.get("questions", []),
                               "actions": m.get("actions", [])})
        return result({"error": "no such meeting in the record", "meetings": sorted(places)}, True)

    if name == "list_plans":
        if board is None:
            return result({"error": "no board configured on this server", "backend": "mirror"}, True)
        return result(dict({"backend": "mirror"}, **board.plans(str(args.get("project", "")).strip())))

    if name == "create_card":
        if board is None:
            return result({"error": "no board configured on this server", "backend": "plane"}, True)
        if not st.allow_write:
            return result({"error": "the board door is read-only on this server — the unit must be started "
                                    "with --allow-write before a ticket can be filed", "backend": "plane"}, True)
        hit = board.resolve(args.get("place"))
        if hit is None:
            return result({"error": f"no such place on the board: {args.get('place')}",
                           "places": [v["place"] for v in board.places()][:40]}, True)
        if not allowed(visible, hit):
            return result({"error": "that place is outside this token's scope", "place": hit["place"],
                           "allowed_places": [v["place"] for v in visible]}, True)
        title = str(args.get("title", "")).strip()
        if not title:
            return result({"error": "a title is required"}, True)
        made = board.create(hit, title, str(args.get("description", "")).strip(), str(args.get("state", "")))
        return result({"created": {"place": hit["place"], "card": made.get("sequence_id"),
                                   "title": made.get("name"), "id": made.get("id")}})

    if name == "update_card":
        if board is None:
            return result({"error": "no board configured on this server", "backend": "plane"}, True)
        if not st.allow_write:
            return result({"error": "the board door is read-only on this server — the unit must be started "
                                    "with --allow-write before a ticket can be moved", "backend": "plane"}, True)
        hit = board.resolve(args.get("place"))
        if hit is None or not allowed(visible, hit):
            return result({"error": "that place does not resolve or is outside this token's scope",
                           "place": str(args.get("place", ""))}, True)
        card = board.card_id(hit, args.get("card"))
        if card is None:
            return result({"error": f"no such card in {hit['place']}: {args.get('card')}",
                           "board": board.board(hit)}, True)
        state = str(args.get("state", "")).strip()
        if state and board.state_id(hit, state) is None:
            return result({"error": f"no such state in {hit['place']}: {state}",
                           "states": [s.get("name") for s in
                                      (st.board.reader.states(hit["workspace"], hit["id"]) or [])]}, True)
        out = board.update(hit, card["id"], state, str(args.get("comment", "")).strip())
        answered = {"place": hit["place"], "card": card.get("sequence_id"),
                    "title": card.get("name"), "state": state or None,
                    "comment": bool(out.get("comment"))}
        if out.get("comment_error"):
            answered["comment_error"] = out["comment_error"]
        return result({"updated": answered})
    if name == "find_doc":
        return result({"error": "AFFiNE is not configured for MCP yet — its GraphQL token is not in the "
                                "house's hands", "backend": "affine"}, True)
    if name == "read_scene":
        scene_id = str(args.get("scene", "")).strip()
        if not scene_id:
            return result({"error": "a scene id is required", "backend": "excalidraw"}, True)
        # Consented share only: a scene lives under <scenes>/<subject>/<id>.json (the owner's
        # own shared copy) or <scenes>/<id>.json (a globally shared copy). Anything else is
        # not shared, and the house refuses to see it rather than reaching past consent.
        candidates = []
        if st.scenes:
            candidates.append(os.path.join(st.scenes, subject, scene_id + ".json"))
            candidates.append(os.path.join(st.scenes, scene_id + ".json"))
        for path in candidates:
            try:
                with open(path, encoding="utf-8") as fh:
                    doc = json.load(fh)
            except (OSError, json.JSONDecodeError):
                continue
            return result({"scene": scene_id,
                           "owner": doc.get("owner", subject),
                           "shared_at": doc.get("shared_at"),
                           "elements": doc.get("elements", []),
                           "element_count": len(doc.get("elements", [])),
                           "app_state": doc.get("appState")})
        return result({"error": "scene not shared with the house — consent required before the "
                                "house can see a board", "scene": scene_id,
                       "backend": "excalidraw", "consent_required": True}, True)
    return result({"error": f"unknown tool {name}"}, True)


class Handler(BaseHTTPRequestHandler):
    state: State = None  # set in main()
    server_version = "gimle-mcp/0.1"

    def _json(self, code: int, obj: dict):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):  # noqa: N802
        if self.path.startswith("/health"):
            return self._json(200, {"status": "ok", "server": SERVER_INFO})
        self._json(404, {"error": "not found"})

    def do_POST(self):  # noqa: N802
        if not self.path.startswith("/mcp"):
            return self._json(404, {"error": "not found"})
        presented = ""
        auth = self.headers.get("Authorization", "")
        if auth.lower().startswith("bearer "):
            presented = auth[7:].strip()
        presented = presented or self.headers.get("X-API-Key", "")
        ident = self.state.subject_for(presented) if presented else None
        subject, places = (ident if ident else (None, []))
        if not subject:
            self.state.record("anonymous", "?", "refused", "no valid token")
            return self._json(401, {"error": "a Gimlé token is required"})
        try:
            length = int(self.headers.get("Content-Length", "0"))
            req = json.loads(self.rfile.read(length) or b"{}")
        except Exception:
            return self._json(400, {"error": "malformed JSON-RPC body"})
        method = req.get("method")
        rid = req.get("id")
        if method == "initialize":
            return self._json(200, {"jsonrpc": "2.0", "id": rid, "result": {
                "protocolVersion": PROTOCOL,
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": SERVER_INFO}})
        if method == "tools/list":
            return self._json(200, {"jsonrpc": "2.0", "id": rid, "result": {"tools": TOOLS}})
        if method == "tools/call":
            params = req.get("params") or {}
            name = params.get("name", "")
            args = params.get("arguments") or {}
            try:
                out = call_tool(self.state, subject, places, name, args)
            except Exception as exc:  # noqa: BLE001
                out = result({"error": f"the backend did not answer ({exc.__class__.__name__})",
                              "tool": name}, True)
            why = ""
            if out.get("isError"):
                # the ledger must say WHY, not "refused": a read-only door and a missing place are
                # different faults, and an operator reading access.jsonl must be able to tell them apart.
                try:
                    why = str(json.loads(out["content"][0]["text"]).get("error", ""))[:200] or "refused"
                except Exception:  # noqa: BLE001
                    why = "refused"
            self.state.record(subject, name, "refused" if out.get("isError") else "allowed", why)
            return self._json(200, {"jsonrpc": "2.0", "id": rid, "result": out})
        if method in ("notifications/initialized", "ping"):
            return self._json(200, {"jsonrpc": "2.0", "id": rid, "result": {}})
        return self._json(200, {"jsonrpc": "2.0", "id": rid,
                                "error": {"code": -32601, "message": f"unknown method {method}"}})

    def log_message(self, fmt, *args):
        sys.stderr.write("mcp %s\n" % (fmt % args))


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8489)
    ap.add_argument("--bind", default="127.0.0.1")
    ap.add_argument("--data", default="/srv/gimle-desk/meetings.json")
    ap.add_argument("--tokens", default="/etc/gimle/mcp-tokens")
    ap.add_argument("--audit", default="/srv/gimle-desk/access.jsonl")
    ap.add_argument("--scenes", default=None,
                    help="directory of consented shared Excalidraw scenes (default: <data dir>/../shared-scenes)")
    ap.add_argument("--plane", action="store_true",
                    help="read the board (Plane) as truth for places, cards and owners — the desk's own reader")
    ap.add_argument("--workspaces", default="",
                    help="the board workspaces a place may name (csv; default: the reader's own GIMLE_PLANE_WORKSPACES)")
    ap.add_argument("--allow-write", action="store_true",
                    help="let create_card and update_card act; without it the board door is read-only")
    ap.add_argument("--docs", default="",
                    help="the mirrored document shelf (default: <data dir>/docs)")
    args = ap.parse_args(argv)
    scenes = args.scenes
    if not scenes:
        scenes = os.path.join(os.path.dirname(os.path.abspath(args.data)), "shared-scenes")
    docs = args.docs or os.path.join(os.path.dirname(os.path.abspath(args.data)), "docs")
    board = None
    if args.plane:
        try:
            sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
            import plane_reader  # the desk's reader — one door for both faces of the hall
            # Rule 07: the workspaces are the READER's, from one place (GIMLE_PLANE_WORKSPACES), so the
            # desk and the MCP can never disagree about which boards exist.
            named = args.workspaces or ",".join(getattr(plane_reader, "WORKSPACES", []))
            board = Board(plane_reader, [w.strip() for w in named.split(",") if w.strip()], docs)
        except Exception as exc:  # noqa: BLE001
            sys.stderr.write(f"mcp: the board backend is not available ({exc.__class__.__name__}: {exc})\n")
    Handler.state = State(args.data, args.tokens, args.audit, scenes,
                          board=board, allow_write=args.allow_write, docs=docs)
    srv = ThreadingHTTPServer((args.bind, args.port), Handler)
    face = "board" if board is not None else "meeting record"
    print(f"gimle mcp ({'read-write' if args.allow_write else 'read-only'}, {face}) on "
          f"http://{args.bind}:{args.port}/mcp", flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

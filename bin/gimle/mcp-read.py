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
     "description": "The elements of an Excalidraw scene, as data (read-only; the board tracks nothing).",
     "inputSchema": {"type": "object", "required": ["scene"],
                     "properties": {"scene": {"type": "string"}}, "additionalProperties": False}},
]


class State:
    def __init__(self, data: str, tokens: str, audit: str):
        self.data = data
        self.tokens = tokens
        self.audit = audit
        self.lock = threading.Lock()

    def load(self) -> dict:
        try:
            with open(self.data, encoding="utf-8") as fh:
                return json.load(fh)
        except Exception:
            return {"meetings": []}

    def tokens_map(self) -> dict:
        """`<token> <subject> [places]` — places are comma-separated; `*` means every place.

        A token that names no place may touch **nothing**: the default is deny, because a token
        with no scope is how "one token = the whole record" happened (plan 105, H4).
        """
        out = {}
        try:
            with open(self.tokens, encoding="utf-8") as fh:
                for line in fh:
                    parts = line.split()
                    if len(parts) >= 2:
                        places = parts[2].split(",") if len(parts) > 2 else []
                        out[parts[1]] = (parts[0], [p for p in places if p])
        except Exception:
            pass
        return out

    def subject_for(self, presented: str) -> tuple[str, list[str]] | None:
        for subject, (token, places) in self.tokens_map().items():
            if hmac.compare_digest(token, presented):
                return subject, places
        return None

    @staticmethod
    def may(subject_places: list[str], place: str) -> bool:
        if "*" in subject_places:
            return True
        return any(place.lower().startswith(p.lower()) for p in subject_places)

    def record(self, subject: str, tool: str, verdict: str, why: str = ""):
        row = {"at": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
               "subject": subject, "tool": tool, "verdict": verdict, "why": why}
        with self.lock:
            try:
                with open(self.audit, "a", encoding="utf-8") as fh:
                    fh.write(json.dumps(row, ensure_ascii=False) + "\n")
            except Exception:
                pass


def places_of(data: dict) -> dict:
    return {m.get("title") or m.get("id"): m for m in data.get("meetings", [])}


def result(payload, is_error=False):
    return {"content": [{"type": "text", "text": json.dumps(payload, indent=1, ensure_ascii=False)}],
            "isError": is_error}


def call_tool(st: State, subject: str, places_allowed: list[str], name: str, args: dict):
    data = st.load()
    places = places_of(data)
    if name == "who_am_i":
        return result({"subject": subject, "allowed_places": places, "places_in_the_record": sorted(places),
                       "phase": "read-only"})
    if name == "list_places":
        visible = {k: v for k, v in places.items() if st.may(places_allowed, k)}
        counts = {k: len(v.get("actions", [])) + len(v.get("questions", [])) for k, v in visible.items()}
        return result({"places": [{"place": k, "open": n} for k, n in counts.items()],
                       "refused": len(places) - len(visible)})
    if name in ("my_tasks", "who_owes_what"):
        rows = []
        refused = 0
        for place, m in places.items():
            if not st.may(places_allowed, place):
                refused += 1
                continue
            for a in m.get("actions", []):
                owner = str(a.get("owner", ""))
                if name == "my_tasks" and subject.lower() not in owner.lower():
                    continue
                rows.append({"place": place, "task": a.get("text"), "owner": owner,
                             "due": a.get("due"), "evidence": a.get("evidence")})
        return result({"subject": subject, "count": len(rows), "rows": rows, "places_refused": refused})
    if name == "place_board":
        target = str(args.get("place", "")).lower()
        for place, m in places.items():
            if target and target in place.lower():
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
    if name == "find_doc":
        return result({"error": "AFFiNE is not configured for MCP yet — its GraphQL token is not in the "
                                "house's hands", "backend": "affine"}, True)
    if name == "read_scene":
        return result({"error": "Excalidraw scene storage is not configured for MCP yet",
                       "backend": "excalidraw"}, True)
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
            out = call_tool(self.state, subject, places, name, args)
            self.state.record(subject, name, "refused" if out.get("isError") else "allowed",
                              "" if not out.get("isError") else "backend not configured or no such object")
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
    args = ap.parse_args(argv)
    Handler.state = State(args.data, args.tokens, args.audit)
    srv = ThreadingHTTPServer((args.bind, args.port), Handler)
    print(f"gimle mcp (read-only) on http://{args.bind}:{args.port}/mcp", flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

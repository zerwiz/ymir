#!/usr/bin/env python3
"""calendar_fixture.py — a stand-in for Google's token, tokeninfo and calendar doors.

Plan 231 §2/R2. Nothing here talks to Google and nothing mocks the door under test: the
REAL `calendar-write.sh` runs against a local server, with the endpoints given as
configuration (Rule 07: YMIR_OAUTH_TOKEN_URL · YMIR_OAUTH_TOKENINFO_URL ·
YMIR_CALENDAR_API_BASE).

    python3 calendar_fixture.py --port-file /tmp/port --state /tmp/state.json \
        --scope "<space separated scopes>" [--api-403]

Writes its port to --port-file and appends every write it saw to --state, so a proof can say
"nothing was posted" rather than trusting the door's own word.
"""
from __future__ import annotations

import argparse
import json
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, unquote, urlparse

WRITE_SCOPE = "https://www.googleapis.com/auth/calendar.events"
READ_SCOPE = "https://www.googleapis.com/auth/calendar.events.readonly"

ITEMS = [
    {"id": "ev-standup", "summary": "Standup", "status": "confirmed",
     "start": {"dateTime": "2030-01-02T08:00:00+01:00"},
     "end": {"dateTime": "2030-01-02T08:15:00+01:00"}},
    {"id": "ev-two-a", "summary": "Example4 review", "status": "confirmed",
     "start": {"dateTime": "2030-01-03T10:00:00+01:00"},
     "end": {"dateTime": "2030-01-03T10:30:00+01:00"}},
    {"id": "ev-two-b", "summary": "Example4 review — pricing", "status": "confirmed",
     "start": {"dateTime": "2030-01-04T10:00:00+01:00"},
     "end": {"dateTime": "2030-01-04T10:30:00+01:00"}},
]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--port-file", required=True)
    ap.add_argument("--state", required=True)
    ap.add_argument("--scope", default=f"{READ_SCOPE}")
    ap.add_argument("--api-403", action="store_true", help="the grant is fine, Google says no")
    ap.add_argument("--tokeninfo-500", action="store_true", help="the scope cannot be measured")
    args = ap.parse_args()

    seen: list[dict] = []

    def record(kind: str, body: dict) -> None:
        seen.append({"kind": kind, "body": body})
        with open(args.state, "w", encoding="utf-8") as fh:
            json.dump(seen, fh)

    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *a):  # the proofs are the record
            return

        def _body(self) -> dict:
            n = int(self.headers.get("Content-Length") or 0)
            raw = self.rfile.read(n) if n else b"{}"
            try:
                return json.loads(raw or b"{}")
            except Exception:
                return {}

        def _json(self, code: int, doc) -> None:
            raw = json.dumps(doc).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)

        def _empty(self, code: int) -> None:
            self.send_response(code)
            self.send_header("Content-Length", "0")
            self.end_headers()

        def do_POST(self):
            u = urlparse(self.path)
            if u.path == "/token":
                self._body()
                return self._json(200, {"access_token": "fixture-token", "expires_in": 3599})
            if u.path.endswith("/events"):
                body = self._body()
                if args.api_403:
                    return self._json(403, {"error": {
                        "code": 403, "message": "Insufficient Permission",
                        "errors": [{"reason": "insufficientPermissions"}],
                        "status": "PERMISSION_DENIED"}})
                record("create", body)
                return self._json(200, {"id": "ev-created", "htmlLink": "https://example.invalid/ev",
                                        "hangoutLink": ""})
            return self._empty(404)

        def do_PATCH(self):
            u = urlparse(self.path)
            body = self._body()
            if args.api_403:
                return self._json(403, {"error": {
                    "code": 403, "message": "Insufficient Permission",
                    "errors": [{"reason": "insufficientPermissions"}],
                    "status": "PERMISSION_DENIED"}})
            record("patch", {"path": u.path, "query": u.query, **body})
            return self._json(200, {"id": u.path.rsplit("/", 1)[-1], "summary": "moved"})

        def do_GET(self):
            u = urlparse(self.path)
            if u.path == "/tokeninfo":
                if args.tokeninfo_500:
                    return self._empty(500)
                return self._json(200, {"scope": args.scope})
            if "/events/" in u.path:
                eid = unquote(u.path.rsplit("/", 1)[-1])
                for it in ITEMS:
                    if it["id"] == eid:
                        return self._json(200, it)
                return self._json(404, {"error": {"message": "not found"}})
            if u.path.endswith("/events"):
                q = (parse_qs(u.query).get("q") or [""])[0].lower()
                items = [it for it in ITEMS if not q or q in it["summary"].lower()]
                return self._json(200, {"items": items})
            return self._empty(404)

    srv = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    with open(args.port_file, "w", encoding="utf-8") as fh:
        fh.write(str(srv.server_address[1]))
    srv.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main())

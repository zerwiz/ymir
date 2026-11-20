#!/usr/bin/env python3
"""share-scene.py — the consented share door for Excalidraw scenes.

A scene in a collab room is end-to-end encrypted: the house cannot see it. This service is the one
place the boundary is crossed, and only when the owner explicitly asks. It accepts a snapshot the
owner's browser sends and stores it under that subject's tree, where the Gimlé MCP `read_scene`
tool can read it. Revoking removes the file.

    POST   /share          { "scene": "<id>", "elements": [...], "appState": {...} }
    DELETE /share/<scene>  revoke a previously shared scene
    GET    /health         liveness

Auth: `Remote-User` (Authelia, passed by Caddy) is preferred; `Authorization: Bearer <token>`
(Gimlé MCP token) is accepted for API callers. A request with no identity is refused and recorded.
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

SERVER_INFO = {"name": "gimle-share", "version": "0.1.0"}


def subject_from(headers, tokens_path):
    ru = headers.get("Remote-User", "").strip()
    if ru:
        return ru
    auth = headers.get("Authorization", "")
    if auth.lower().startswith("bearer "):
        presented = auth[7:].strip()
        try:
            with open(tokens_path, encoding="utf-8") as fh:
                for line in fh:
                    parts = line.split()
                    if len(parts) >= 2 and hmac.compare_digest(parts[0], presented):
                        return parts[1]
        except Exception:
            pass
    return None


class State:
    def __init__(self, scenes: str, tokens: str, audit: str):
        self.scenes = scenes
        self.tokens = tokens
        self.audit = audit
        self.lock = threading.Lock()

    def record(self, subject, action, verdict, why=""):
        row = {"at": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
               "subject": subject, "tool": "share_scene", "action": action,
               "verdict": verdict, "why": why}
        try:
            with open(self.audit, "a", encoding="utf-8") as fh:
                fh.write(json.dumps(row, ensure_ascii=False) + "\n")
        except Exception:
            pass

    def path_for(self, subject, scene):
        # keep scene id safe: basename only, no traversal
        safe = os.path.basename(scene).replace("..", "")
        if not safe or safe != scene.strip():
            return None
        return os.path.join(self.scenes, subject, safe + ".json")

    def share(self, subject, scene, elements, app_state):
        path = self.path_for(subject, scene)
        if not path:
            return (400, {"error": "invalid scene id"})
        os.makedirs(os.path.dirname(path), exist_ok=True)
        doc = {"owner": subject, "scene": scene,
               "shared_at": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
               "elements": elements if isinstance(elements, list) else [],
               "appState": app_state if isinstance(app_state, dict) else {}}
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(doc, fh, ensure_ascii=False, indent=1)
        return (200, {"ok": True, "scene": scene, "owner": subject, "path": path})

    def revoke(self, subject, scene):
        path = self.path_for(subject, scene)
        if not path:
            return (400, {"error": "invalid scene id"})
        # an owner may revoke their own; a wildcard admin may revoke any
        if not os.path.exists(path):
            return (404, {"error": "scene not shared", "scene": scene})
        try:
            with open(path, encoding="utf-8") as fh:
                doc = json.load(fh)
        except Exception:
            doc = {}
        if doc.get("owner") not in (subject, None) and subject != "admin":
            return (403, {"error": "not your scene to revoke"})
        os.remove(path)
        return (200, {"ok": True, "revoked": scene})


class Handler(BaseHTTPRequestHandler):
    state: State = None

    def _json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", self.headers.get("Origin", "*"))
        self.send_header("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):  # noqa: N802
        self._json(204, {})

    def do_GET(self):  # noqa: N802
        if self.path.startswith("/health"):
            return self._json(200, {"status": "ok", "server": SERVER_INFO})
        self._json(404, {"error": "not found"})

    def do_POST(self):  # noqa: N802
        if not self.path.startswith("/share"):
            return self._json(404, {"error": "not found"})
        subject = subject_from(self.headers, self.state.tokens)
        if not subject:
            self.state.record("anonymous", "share", "refused", "no identity")
            return self._json(401, {"error": "identity required (Remote-User or Gimlé token)"})
        try:
            length = int(self.headers.get("Content-Length", "0"))
            body = json.loads(self.rfile.read(length) or b"{}")
        except Exception:
            return self._json(400, {"error": "malformed JSON body"})
        scene = str(body.get("scene", "")).strip()
        if not scene:
            return self._json(400, {"error": "scene id is required"})
        code, out = self.state.share(subject, scene, body.get("elements", []),
                                    body.get("appState", {}))
        self.state.record(subject, "share", "allowed" if code < 400 else "refused",
                          "" if code < 400 else out.get("error", ""))
        self._json(code, out)

    def do_DELETE(self):  # noqa: N802
        # /share/<scene>
        parts = self.path.strip("/").split("/")
        scene = parts[-1] if len(parts) >= 2 else ""
        subject = subject_from(self.headers, self.state.tokens)
        if not subject:
            self.state.record("anonymous", "revoke", "refused", "no identity")
            return self._json(401, {"error": "identity required"})
        if not scene:
            return self._json(400, {"error": "scene id is required"})
        code, out = self.state.revoke(subject, scene)
        self.state.record(subject, "revoke", "allowed" if code < 400 else "refused",
                          "" if code < 400 else out.get("error", ""))
        self._json(code, out)

    def log_message(self, fmt, *args):
        sys.stderr.write("share %s\n" % (fmt % args))


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8490)
    ap.add_argument("--bind", default="127.0.0.1")
    ap.add_argument("--scenes", default=None)
    ap.add_argument("--tokens", default="/etc/gimle/mcp-tokens")
    ap.add_argument("--audit", default="/srv/gimle-desk/access.jsonl")
    args = ap.parse_args(argv)
    scenes = args.scenes
    if not scenes:
        scenes = "/srv/gimle-desk/shared-scenes"
    os.makedirs(scenes, exist_ok=True)
    Handler.state = State(scenes, args.tokens, args.audit)
    srv = ThreadingHTTPServer((args.bind, args.port), Handler)
    print(f"gimle share-scene on http://{args.bind}:{args.port}/share", flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
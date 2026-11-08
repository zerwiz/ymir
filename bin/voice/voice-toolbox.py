#!/usr/bin/env python3
"""voice-toolbox.py — the house's hands for a browser face.

The fourteen voice tools are Python doors in this repo (`bin/voice/voice_tools.py`).
A browser client can only run JavaScript, so this door gives it the same hands over
loopback HTTP:

    GET  /tools          the definitions the client registers with the Realtime session
    POST /tool           {"name": ..., "arguments": {...}} → {"output": ..., "create_response": bool}
    GET  /health         liveness

Every call goes through `voice_tools.execute_tool`, so the confirm gate on `hand_over`,
the vault refusal, the seat-scoping and the activity log are exactly the terminal's.

Bind: 127.0.0.1 only (a hand reached from the network is not a hand, it is a hole).
CORS is allowed for loopback origins only, because the UI is served from an ephemeral
loopback port.

    python3 bin/voice/voice-toolbox.py [--port 8891]
"""
from __future__ import annotations

import argparse
import asyncio
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import voice_tools  # noqa: E402

LOOPBACK = ("127.0.0.1", "localhost", "[::1]")


class Handler(BaseHTTPRequestHandler):
    server_version = "rodd-toolbox/1.0"

    def _cors(self) -> None:
        origin = self.headers.get("Origin") or ""
        if not origin:
            return
        host = origin.split("//")[-1].split(":")[0]
        if host in LOOPBACK:
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")

    def _json(self, code: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self._cors()
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(204)
        self._cors()
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        if self.path.startswith("/health"):
            return self._json(200, {"ok": True, "tools": len(voice_tools.TOOLS)})
        if self.path.startswith("/tools"):
            defs = []
            for t in voice_tools.TOOLS:
                defs.append({
                    "name": t["name"],
                    "description": t.get("description", ""),
                    "parameters": t.get("parameters", {"type": "object", "properties": {}}),
                })
            return self._json(200, {"tools": defs})
        return self._json(404, {"error": "unknown path", "paths": ["/tools", "/tool", "/health"]})

    def do_POST(self) -> None:  # noqa: N802
        if not self.path.startswith("/tool"):
            return self._json(404, {"error": "unknown path"})
        try:
            length = int(self.headers.get("Content-Length") or 0)
            payload = json.loads(self.rfile.read(length) or b"{}")
            name = str(payload.get("name") or "").strip()
            args = payload.get("arguments") or {}
            if isinstance(args, str):
                args = json.loads(args or "{}")
            if not name:
                return self._json(400, {"error": "a tool name is required"})
            result = asyncio.run(voice_tools.execute_tool(name, args))
            out = getattr(result, "output", None)
            speaks = getattr(result, "create_response", None)
            if out is None and isinstance(result, dict):
                out, speaks = result.get("output"), result.get("create_response")
            return self._json(200, {"output": str(out if out is not None else result),
                                    "create_response": bool(speaks if speaks is not None else True)})
        except Exception as exc:  # a refused tool is a spoken refusal, never a silent 500
            return self._json(200, {"output": f"that door refused: {exc}", "create_response": True})

    def log_message(self, fmt: str, *a) -> None:  # quiet by design; the tools log themselves
        return


def main() -> None:
    ap = argparse.ArgumentParser(description="Rödd's hands for a browser face")
    ap.add_argument("--port", type=int, default=8891)
    ap.add_argument("--host", default="127.0.0.1")
    a = ap.parse_args()
    srv = ThreadingHTTPServer((a.host, a.port), Handler)
    # the address is printed for the operator's eyes only; it is built at run time and
    # never written into this file (RULES/39: this tree carries no addresses)
    print(f"rodd toolbox on {a.host}:{a.port} — {len(voice_tools.TOOLS)} tools", flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()

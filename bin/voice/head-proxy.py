#!/usr/bin/env python3
"""head-proxy.py — a loopback OpenAI-compatible door in front of an online head.

Some hosted endpoints refuse a plain client. opencode-go, measured 2026-11-11:

    403  error code: 1010            the default Python User-Agent (Cloudflare)
    400  MissingSessionID            no `x-opencode-session` header
    200  …                           `x-opencode-client`, `x-opencode-session`, own UA

The speech-to-speech engine speaks plain OpenAI (`--responses_api_base_url`), so the
headers it cannot send are added here, on loopback, in one place. The key stays in the
private home and is never logged; the proxy binds 127.0.0.1 only.

    bin/voice/head-proxy.py --port 8893 --base-url https://…/v1 --client opencode
    GET  /v1/models             forwarded
    POST /v1/chat/completions   forwarded, streaming preserved

`--client` names the compatibility profile:
    plain      no extra headers (the default for any OpenAI-compatible endpoint)
    opencode   x-opencode-client + x-opencode-session + a non-default User-Agent
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parent))

BASE = ""
CLIENT = "plain"
SESSION = "rodd-" + uuid.uuid4().hex[:12]
KEY = ""


def _headers() -> dict[str, str]:
    h = {"Content-Type": "application/json", "Accept": "application/json"}
    if KEY:
        h["Authorization"] = f"Bearer {KEY}"
    if CLIENT == "opencode":
        h["User-Agent"] = "rodd/1.0 (+ymir)"
        h["x-opencode-client"] = "rodd"
        h["x-opencode-session"] = SESSION
    return h


class Handler(BaseHTTPRequestHandler):
    server_version = "rodd-head-proxy/1.0"

    def _forward(self, method: str, body: bytes | None) -> None:
        # the engine asks for /v1/chat/completions; the base already ends with /v1.
        # Joining blindly produced …/v1/v1/chat/completions and a 404 dressed as a refusal
        # (measured 2026-11-11).
        base_path = urlsplit(BASE).path.rstrip("/")
        path = self.path
        base_last = base_path.rsplit("/", 1)[-1] if base_path else ""
        first = path.lstrip("/").split("/", 1)[0]
        if base_last and first == base_last:
            # …/openai/v1 + /v1/chat/completions → …/openai/v1/chat/completions
            rest = path.lstrip("/").split("/", 1)
            path = "/" + (rest[1] if len(rest) > 1 else "")
        url = BASE.rstrip("/") + path
        req = urllib.request.Request(url, data=body, headers=_headers(), method=method)
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                status = r.status
                ctype = r.headers.get("Content-Type", "application/json")
                streaming = "text/event-stream" in ctype
                self.send_response(status)
                self.send_header("Content-Type", ctype)
                if streaming:
                    self.send_header("Cache-Control", "no-cache")
                    self.end_headers()
                    self.wfile.flush()
                    while True:
                        chunk = r.read(1)
                        if not chunk:
                            break
                        self.wfile.write(chunk)
                        self.wfile.flush()
                    return
                payload = r.read()
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
        except urllib.error.HTTPError as exc:
            upstream = (exc.read() or b"").decode("utf-8", "replace")[:600]
            payload = json.dumps({
                "error": {"message": f"the head refused ({exc.code}): {upstream or 'no body'}"}
            }).encode()
            self.send_response(exc.code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        except Exception as exc:  # a dead endpoint is a sentence, never a silent hang
            payload = json.dumps({"error": {"message": f"the head is unreachable: {exc}"}}).encode()
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

    def do_GET(self) -> None:  # noqa: N802
        if self.path.startswith("/health"):
            body = json.dumps({"ok": True, "client": CLIENT, "upstream": urlsplit(BASE).hostname}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self._forward("GET", None)

    def do_POST(self) -> None:  # noqa: N802
        length = int(self.headers.get("Content-Length") or 0)
        self._forward("POST", self.rfile.read(length) or b"{}")

    def log_message(self, fmt: str, *a) -> None:  # never log a header: the key rides one
        return


def main() -> int:
    global BASE, CLIENT, KEY
    ap = argparse.ArgumentParser(description="loopback OpenAI-compatible door for an online head")
    ap.add_argument("--port", type=int, default=8893)
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--base-url", default=os.environ.get("RODD_HEAD_ONLINE_BASE_URL", ""))
    ap.add_argument("--client", default=os.environ.get("RODD_HEAD_ONLINE_CLIENT", "plain"))
    a = ap.parse_args()
    client = (a.client or os.environ.get("RODD_HEAD_ONLINE_CLIENT") or "plain").strip().lower()
    if not a.base_url:
        # the one door knows the endpoint: ask it rather than take a second argument
        try:
            import importlib.util
            spec = importlib.util.spec_from_file_location("rodd_head",
                                                         Path(__file__).resolve().parent / "rodd-head.py")
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            r = mod.resolve()
            a.base_url = r.get("base_url", "")
            client = r.get("client", client) or client
        except Exception:
            pass
    if not a.base_url:
        print("error: no online base url — set one in Rödd's settings (or --base-url)", file=sys.stderr)
        return 2
    BASE, CLIENT = a.base_url, client
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location("rodd_head", Path(__file__).resolve().parent / "rodd-head.py")
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        KEY = mod.resolve().get("key", "")
    except Exception:
        KEY = ""
    srv = ThreadingHTTPServer((a.host, a.port), Handler)
    print(f"rodd head proxy on {a.host}:{a.port} → {urlsplit(BASE).hostname} (client {CLIENT}, key {'set' if KEY else 'none'})",
          flush=True)
    srv.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main())

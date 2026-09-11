#!/usr/bin/env python3
"""opencode-go-bridge.py — expose opencode-go (Zen Go) to pi via an
OpenAI-compatible local endpoint, keyed from ~/Ymir/.env.

Why: pi resolves models from ~/.pi/agent/models.json, which cannot read the
API key from the repo's .env. This bridge listens on 127.0.0.1, reads
OPENCODE_GO_API_KEY from .env, and proxies /v1/* to the opencode-go gateway
(https://opencode.ai/zen/go/v1). pi then just registers the provider with
baseUrl=http://127.0.0.1:PORT/v1 and any placeholder key.

Endpoints (OpenAI-compatible):
    GET  /v1/models                          -> model list (for pi listing)
    POST /v1/chat/completions                -> proxied (JSON or SSE stream)

Usage:
    python3 scripts/opencode-go-bridge.py [--port 4603] [--env /path/.env]

Env:
    OPENCODE_GO_API_KEY  (required; read from --env or $ENV_FILE)
    OPENCODE_GO_BRIDGE_PORT   default 4603
    OPENCODE_GO_BASE_URL      default https://opencode.ai/zen/go/v1
"""
import argparse
import json
import os
import sys
import threading
from http.client import HTTPSConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DEFAULT_PORT = 4603
BASE_URL = os.environ.get("OPENCODE_GO_BASE_URL", "https://opencode.ai/zen/go/v1")

# The opencode-go catalog (from `opencode models`, 2026-08-31).
# Bare model ids — the gateway rejects the `opencode-go/` prefix.
MODELS = [
    {"id": "deepseek-v4-flash", "contextWindow": 131072, "input": ["text"]},
    {"id": "deepseek-v4-flash-vision-exp", "contextWindow": 131072, "input": ["text", "image"]},
    {"id": "deepseek-v4-pro", "contextWindow": 131072, "input": ["text"]},
    {"id": "glm-5.1", "contextWindow": 131072, "input": ["text"]},
]

KEY = ""  # injected at startup after .env load


def load_env(path: str) -> dict:
    env = {}
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, _, v = line.partition("=")
                env[k.strip()] = v.strip().strip('"').strip("'")
    except FileNotFoundError:
        pass
    return env


def upstream_path() -> str:
    # BASE_URL "https://host/path" -> (host, path)
    rest = BASE_URL.split("://", 1)[1]
    host, _, path = rest.partition("/")
    return host, "/" + path if path else ""


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):  # quieter, timestamped
        print(f"[bridge] {self.log_date_time_string()} {fmt % args}", flush=True)

    def _send(self, code: int, body: bytes, ctype: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.split("?")[0] == "/v1/models":
            payload = {"object": "list",
                       "data": [{"id": m["id"], "object": "model"} for m in MODELS]}
            self._send(200, json.dumps(payload).encode(), "application/json")
        else:
            self._send(404, json.dumps({"error": "not found"}).encode(), "application/json")

    def do_POST(self):
        if self.path.split("?")[0] != "/v1/chat/completions":
            self._send(404, json.dumps({"error": "not found"}).encode(), "application/json")
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length) if length else b"{}"
            # normalize bare ids -> what the gateway wants; strip a provider prefix
            req = json.loads(body)
            mid = req.get("model", "")
            if "/" in mid and mid.split("/", 1)[0] != "openai":
                req["model"] = mid.split("/", 1)[1]
                body = json.dumps(req).encode()
            self._proxy(body, req.get("stream", False))
        except Exception as e:
            print(f"[bridge] proxy error: {e}", flush=True)
            try:
                self._send(500, json.dumps({"error": str(e)}).encode(), "application/json")
            except Exception:
                pass

    def _proxy(self, body: bytes, stream: bool) -> None:
        host, path = upstream_path()
        conn = HTTPSConnection(host, timeout=120)
        conn.request("POST", path.rstrip("/") + "/chat/completions",
                     body=body,
                     headers={
                         "Authorization": f"Bearer {KEY}",
                         "Content-Type": "application/json",
                         "Accept": "text/event-stream" if stream else "application/json",
                     })
        resp = conn.getresponse()
        # relay status + the headers that matter (drop upstream transfer-encoding;
        # WE control the framing below)
        self.send_response(resp.status)
        for k, v in resp.getheaders():
            if k.lower() in ("content-type",):
                self.send_header(k, v)
        self.send_header("Cache-Control", "no-cache")
        if stream:
            # no Content-Length: frame as chunked so the client gets EOF at
            # the terminating 0-chunk even though upstream SSE never closes
            self.send_header("Transfer-Encoding", "chunked")
            self.send_header("Connection", "close")
            chunked = True
        else:
            for k, v in resp.getheaders():
                if k.lower() == "content-length":
                    self.send_header(k, v)
            chunked = False
        self.end_headers()
        # relay the body — small chunks keep SSE flowing in (near) real time
        while True:
            chunk = resp.read(4096)
            if not chunk:
                break
            try:
                if chunked:
                    self.wfile.write(f"{len(chunk):x}\r\n".encode() + chunk + b"\r\n")
                else:
                    self.wfile.write(chunk)
                self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                break  # client went away; upstream closes with us
        if chunked:
            try:
                self.wfile.write(b"0\r\n\r\n")
                self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                pass
        conn.close()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--port", type=int, default=int(os.environ.get("OPENCODE_GO_BRIDGE_PORT", DEFAULT_PORT)))
    ap.add_argument("--env", default=os.environ.get("ENV_FILE",
                   str(__import__("pathlib").Path(__file__).resolve().parents[1] / ".env")))
    args = ap.parse_args()

    global KEY
    env = load_env(args.env)
    KEY = env.get("OPENCODE_GO_API_KEY") or os.environ.get("OPENCODE_GO_API_KEY", "")
    if not KEY:
        print("[bridge] ERROR: OPENCODE_GO_API_KEY missing (set it in " + args.env + ")", file=sys.stderr)
        return 1

    host, path = upstream_path()
    print(f"[bridge] opencode-go bridge on 127.0.0.1:{args.port}/v1 "
          f"-> {host}{path.rstrip('/')}/chat/completions (key from {args.env})", flush=True)
    print(f"[bridge] models: {', '.join(m['id'] for m in MODELS)}", flush=True)

    srv = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\n[bridge] stopped", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
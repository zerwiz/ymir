#!/usr/bin/env python3
"""model-bridge.py — expose a model provider to pi via an OpenAI-compatible
local endpoint.

Why: pi resolves models from ~/.pi/agent/models.json, which cannot read the API
key from the repo's .env. This bridge listens on 127.0.0.1, reads the provider
credential from .env, and proxies /v1/* to the selected provider. pi then just
registers the provider with baseUrl=http://127.0.0.1:PORT/v1 and any placeholder
key.

Providers (YMIR_MODEL_PROVIDER):
    opencode-go   (default)  OpenCode Zen Go gateway — REQUIRES OPENCODE_GO_API_KEY
    lmstudio                 LM Studio on localhost — NO KEY REQUIRED
    openai-compatible        any OpenAI-compatible server — optional key

The Allfather chooses. No provider is forced to need a key: LM Studio runs
entirely locally and the bridge starts with no credential at all.

Endpoints (OpenAI-compatible):
    GET  /v1/models                          -> model list (for pi listing)
    POST /v1/chat/completions                -> proxied (JSON or SSE stream)

Usage:
    python3 model-bridge.py [--port 4603] [--env /path/.env] [--provider NAME]

Env:
    YMIR_MODEL_PROVIDER       opencode-go | lmstudio | openai-compatible
    YMIR_MODEL_BASE_URL       override the provider's base URL
    YMIR_MODEL_API_KEY        credential for the selected provider
    OPENCODE_GO_API_KEY       credential when provider=opencode-go
    LMSTUDIO_BASE_URL         default http://127.0.0.1:1234/v1
    OPENCODE_GO_BASE_URL      default https://opencode.ai/zen/go/v1
    OPENCODE_GO_BRIDGE_PORT   default 4603
"""
import argparse
import json
import os
import sys
import urllib.request
import urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DEFAULT_PORT = 4603

# Provider catalogue. `key_env` lists the env names checked, in order; an empty
# key requirement (lmstudio) means the bridge starts with no credential.
PROVIDERS = {
    "opencode-go": {
        "base_url": "https://opencode.ai/zen/go/v1",
        "base_url_env": "OPENCODE_GO_BASE_URL",
        "key_env": ["OPENCODE_GO_API_KEY", "YMIR_MODEL_API_KEY"],
        "requires_key": True,
    },
    "lmstudio": {
        "base_url": "http://127.0.0.1:1234/v1",
        "base_url_env": "LMSTUDIO_BASE_URL",
        "key_env": ["LMSTUDIO_API_KEY", "YMIR_MODEL_API_KEY"],
        "requires_key": False,
    },
    "openai-compatible": {
        "base_url": "",
        "base_url_env": "YMIR_MODEL_BASE_URL",
        "key_env": ["YMIR_MODEL_API_KEY"],
        "requires_key": False,
    },
}

# The opencode-go catalog (from `opencode models`, 2026-08-31).
# Bare model ids — the gateway rejects the `opencode-go/` prefix.
MODELS = [
    {"id": "deepseek-v4-flash", "contextWindow": 131072, "input": ["text"]},
    {"id": "deepseek-v4-flash-vision-exp", "contextWindow": 131072, "input": ["text", "image"]},
    {"id": "deepseek-v4-pro", "contextWindow": 131072, "input": ["text"]},
    {"id": "glm-5.1", "contextWindow": 131072, "input": ["text"]},
]

# Resolved at startup.
KEY = ""
BASE_URL = ""
PROVIDER = "opencode-go"


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


def resolve_provider(env: dict, cli_provider: str | None) -> str:
    name = (cli_provider or env.get("YMIR_MODEL_PROVIDER")
            or os.environ.get("YMIR_MODEL_PROVIDER") or "opencode-go").strip()
    if name not in PROVIDERS:
        print(f"[bridge] ERROR: unknown provider '{name}'. "
              f"Choose one of: {', '.join(PROVIDERS)}", file=sys.stderr)
        raise SystemExit(2)
    return name


def resolve_base_url(env: dict, spec: dict) -> str:
    for holder in (env, os.environ):
        v = holder.get("YMIR_MODEL_BASE_URL")
        if v:
            return v
    v = env.get(spec["base_url_env"]) or os.environ.get(spec["base_url_env"])
    return v or spec["base_url"]


def resolve_key(env: dict, spec: dict) -> str:
    for name in spec["key_env"]:
        v = env.get(name) or os.environ.get(name)
        if v:
            return v
    return ""


def is_https(url: str) -> bool:
    return url.startswith("https://")


def split_url(url: str) -> tuple[str, str]:
    rest = url.split("://", 1)[1]
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

    def _models(self) -> list:
        # Ask the provider what it serves; fall back to the static catalogue.
        try:
            req = urllib.request.Request(_upstream("models"),
                                         headers=_auth_headers())
            with urllib.request.urlopen(req, timeout=10) as r:
                data = json.loads(r.read())
            return data.get("data", [])
        except Exception:
            return [{"id": m["id"], "object": "model"} for m in MODELS]

    def do_GET(self):
        if self.path.split("?")[0] == "/v1/models":
            payload = {"object": "list", "data": self._models()}
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
            req = json.loads(body)
            mid = req.get("model", "")
            # opencode-go rejects the `opencode-go/` prefix; strip provider prefixes.
            if PROVIDER == "opencode-go" and "/" in mid and mid.split("/", 1)[0] != "openai":
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
        req = urllib.request.Request(
            _upstream("chat/completions"),
            data=body,
            headers=_auth_headers(stream),
            method="POST",
        )
        try:
            resp = urllib.request.urlopen(req, timeout=300)
        except urllib.error.HTTPError as e:
            # Relay the provider's error verbatim so the operator sees the cause.
            payload = e.read()
            self._send(e.code, payload, e.headers.get("Content-Type", "application/json"))
            return
        self.send_response(resp.status)
        ctype = resp.headers.get("Content-Type", "application/json")
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-cache")
        if stream:
            # no Content-Length: frame as chunked so the client gets EOF at
            # the terminating 0-chunk even though upstream SSE never closes
            self.send_header("Transfer-Encoding", "chunked")
            self.send_header("Connection", "close")
            chunked = True
        else:
            cl = resp.headers.get("Content-Length")
            if cl:
                self.send_header("Content-Length", cl)
            chunked = False
        self.end_headers()
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


def _upstream(suffix: str) -> str:
    return BASE_URL.rstrip("/") + "/" + suffix


def _auth_headers(stream: bool = False) -> dict:
    h = {"Content-Type": "application/json",
         "Accept": "text/event-stream" if stream else "application/json"}
    if KEY:
        h["Authorization"] = f"Bearer {KEY}"
    return h


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--port", type=int,
                    default=int(os.environ.get("OPENCODE_GO_BRIDGE_PORT", DEFAULT_PORT)))
    ap.add_argument("--env", default=os.environ.get("ENV_FILE",
                    str(__import__("pathlib").Path(__file__).resolve().parents[1] / ".env")))
    ap.add_argument("--provider", default=None,
                    help="opencode-go | lmstudio | openai-compatible")
    args = ap.parse_args()

    global KEY, BASE_URL, PROVIDER
    env = load_env(args.env)
    PROVIDER = resolve_provider(env, args.provider)
    spec = PROVIDERS[PROVIDER]
    BASE_URL = resolve_base_url(env, spec)
    KEY = resolve_key(env, spec)

    if spec["requires_key"] and not KEY:
        print(f"[bridge] ERROR: provider '{PROVIDER}' requires a key. Set "
              f"{' or '.join(spec['key_env'])} in {args.env}, or choose a "
              f"keyless provider such as 'lmstudio'.", file=sys.stderr)
        return 1
    if not BASE_URL:
        print(f"[bridge] ERROR: provider '{PROVIDER}' has no base URL. Set "
              f"YMIR_MODEL_BASE_URL in {args.env}.", file=sys.stderr)
        return 1

    host, path = split_url(BASE_URL)
    keynote = "no key required" if not KEY else f"key from {args.env}"
    print(f"[bridge] provider '{PROVIDER}' on 127.0.0.1:{args.port}/v1 "
          f"-> {host}{path.rstrip('/')}/chat/completions ({keynote})", flush=True)

    srv = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\n[bridge] stopped", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

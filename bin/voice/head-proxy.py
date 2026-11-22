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

FALLBACK (2026-11-22, the Allfather: "use a free model as fallback if models are failing"). When the head refuses a
chat request with a quota, rate, payment or server error (402 · 403 · 429 · 5xx) or cannot be reached, the same request
is tried, in order, on:
    1. RODD_HEAD_FALLBACK_MODELS   the same endpoint, other models (comma-separated; e.g. a free tier), with
                                   request fields such models refuse dropped (chat_template_kwargs, reasoning_effort)
    2. RODD_HEAD_FALLBACK_LOCAL    an OpenAI-compatible local rail as "<base_url> <model>" (free: this machine's GPU);
                                   its key from RODD_HEAD_FALLBACK_LOCAL_KEY, else none
Each fallback that answers is said on stderr (never a key). Nothing is configured by default: the operator names them.

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
FALLBACK_MODELS = [m.strip() for m in os.environ.get("RODD_HEAD_FALLBACK_MODELS", "").split(",") if m.strip()]
_loc = os.environ.get("RODD_HEAD_FALLBACK_LOCAL", "").split()
FALLBACK_LOCAL = (_loc[0], _loc[1]) if len(_loc) >= 2 else None
FALLBACK_LOCAL_KEY = os.environ.get("RODD_HEAD_FALLBACK_LOCAL_KEY", "")
FAIL_CODES = {402, 403, 408, 429, 500, 502, 503, 504}
DROP_FOR_FALLBACK = ("chat_template_kwargs", "reasoning_effort")


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

    def _try(self, url: str, body: bytes | None, method: str, headers: dict) -> tuple[int, object]:
        """(status, response-or-error-body). A status in FAIL_CODES, or 0 for unreachable, may fall back."""
        req = urllib.request.Request(url, data=body, headers=headers, method=method)
        try:
            return 200, urllib.request.urlopen(req, timeout=180)
        except urllib.error.HTTPError as exc:
            return exc.code, (exc.read() or b"").decode("utf-8", "replace")[:600]
        except Exception as exc:  # noqa: BLE001
            return 0, f"the head is unreachable: {exc}"

    def _fallbacks(self, body: bytes | None):
        """Yield (url, body, headers, label) for each configured fallback of a chat request."""
        try:
            doc = json.loads(body or b"{}")
        except ValueError:
            return
        for k in DROP_FOR_FALLBACK:
            doc.pop(k, None)
        for m in FALLBACK_MODELS:
            d = dict(doc, model=m)
            yield BASE.rstrip("/") + "/chat/completions", json.dumps(d).encode(), _headers(), f"{urlsplit(BASE).hostname} {m}"
        if FALLBACK_LOCAL:
            base, m = FALLBACK_LOCAL
            h = {"Content-Type": "application/json", "Accept": "application/json"}
            if FALLBACK_LOCAL_KEY:
                h["Authorization"] = f"Bearer {FALLBACK_LOCAL_KEY}"
            yield base.rstrip("/") + "/chat/completions", json.dumps(dict(doc, model=m)).encode(), h, f"local {m}"

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
        status, got = self._try(url, body, method, _headers())
        if (status in FAIL_CODES or status == 0) and method == "POST" and path.endswith("/chat/completions"):
            for furl, fbody, fh, label in self._fallbacks(body):
                fs, fgot = self._try(furl, fbody, "POST", fh)
                if fs == 200:
                    print(f"head-proxy: the head failed ({status or 'unreachable'}); answered by the fallback {label}",
                          file=sys.stderr, flush=True)
                    status, got = fs, fgot
                    break
        if status != 200:
            msg = f"the head refused ({status}): {got or 'no body'}" if status else str(got)
            payload = json.dumps({"error": {"message": msg}}).encode()
            self.send_response(status or 502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        try:
            with got as r:
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
    # the fallbacks may also be named in the operator's own Rödd settings (hodd/secrets/rodd.env), read the same way
    global FALLBACK_MODELS, FALLBACK_LOCAL, FALLBACK_LOCAL_KEY
    try:
        home_env = mod._parse(mod.SECRETS)  # type: ignore[name-defined]
    except Exception:  # noqa: BLE001
        home_env = {}
    if not FALLBACK_MODELS and home_env.get("RODD_HEAD_FALLBACK_MODELS"):
        FALLBACK_MODELS = [m.strip() for m in home_env["RODD_HEAD_FALLBACK_MODELS"].split(",") if m.strip()]
    if not FALLBACK_LOCAL and len(home_env.get("RODD_HEAD_FALLBACK_LOCAL", "").split()) >= 2:
        FALLBACK_LOCAL = tuple(home_env["RODD_HEAD_FALLBACK_LOCAL"].split()[:2])
    FALLBACK_LOCAL_KEY = FALLBACK_LOCAL_KEY or home_env.get("RODD_HEAD_FALLBACK_LOCAL_KEY", "")
    print(f"fallbacks: models {FALLBACK_MODELS or 'none'} · local {FALLBACK_LOCAL[1] if FALLBACK_LOCAL else 'none'}", flush=True)
    srv = ThreadingHTTPServer((a.host, a.port), Handler)
    print(f"rodd head proxy on {a.host}:{a.port} → {urlsplit(BASE).hostname} (client {CLIENT}, key {'set' if KEY else 'none'})",
          flush=True)
    srv.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main())

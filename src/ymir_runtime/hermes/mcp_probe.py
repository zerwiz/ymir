"""A minimal MCP client for the doctor — one real, read-only call per door (plan 96's four states).

Two transports, the two Hermes seats: streamable HTTP (a `url`) and stdio (a `command`). Each probe
answers four questions — configured, listening, authenticated, answering — and keeps the first
characters of the answer as proof. Nothing here writes; the only tool it ever calls by name is one
the caller passes (the doctor passes `ymir_where`, a read).
"""

from __future__ import annotations

import json
import os
import selectors
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from typing import Mapping

PROTOCOL = "2025-06-18"
YES, NO, NA = "yes", "no", "—"


@dataclass
class Probe:
    configured: str = YES
    listening: str = NO
    authenticated: str = NO
    answering: str = NO
    detail: str = ""
    tools: list[str] = field(default_factory=list)
    call_text: str = ""

    @property
    def green(self) -> bool:
        return all(s in (YES, NA) for s in (self.configured, self.listening, self.authenticated, self.answering))


def _init(rid: int) -> dict:
    return {"jsonrpc": "2.0", "id": rid, "method": "initialize",
            "params": {"protocolVersion": PROTOCOL, "capabilities": {},
                       "clientInfo": {"name": "ymir-doctor", "version": "1"}}}


def _call(rid: int, tool: str) -> dict:
    return {"jsonrpc": "2.0", "id": rid, "method": "tools/call", "params": {"name": tool, "arguments": {}}}


def _text(result: Mapping) -> str:
    parts = [c.get("text", "") for c in (result.get("content") or []) if isinstance(c, dict)]
    return " ".join(p for p in parts if p).strip()


# ── streamable HTTP ─────────────────────────────────────────────────────────────────────────────

def _post(url: str, body: dict, session: str, timeout: float) -> tuple[int, dict | None, str]:
    headers = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream",
               "MCP-Protocol-Version": PROTOCOL}
    if session:
        headers["Mcp-Session-Id"] = session
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            sid = resp.headers.get("Mcp-Session-Id") or session
            raw = resp.read().decode("utf-8", errors="replace")
            status = resp.status
    except urllib.error.HTTPError as exc:
        return exc.code, None, ""
    if not raw.strip():
        return status, None, sid
    if raw.lstrip().startswith("{"):
        return status, json.loads(raw), sid
    for line in raw.splitlines():               # an SSE stream: the first data frame with our id
        if line.startswith("data:"):
            try:
                msg = json.loads(line[5:].strip())
            except ValueError:
                continue
            if msg.get("id") == body.get("id"):
                return status, msg, sid
    return status, None, sid


def probe_http(url: str, *, tool: str = "", timeout: float = 10.0) -> Probe:
    p = Probe()
    u = urllib.parse.urlparse(url)
    port = u.port or (443 if u.scheme == "https" else 80)
    try:
        with socket.create_connection((u.hostname or "", port), timeout=min(timeout, 5)):
            p.listening = YES
    except OSError as exc:
        p.detail = f"connect {u.hostname}:{port}: {exc}"
        return p
    try:
        status, msg, sid = _post(url, _init(1), "", timeout)
        if status in (401, 403):
            p.detail = f"HTTP {status} — credentials refused or missing"
            return p
        p.authenticated = YES
        if not msg or "result" not in msg:
            p.detail = f"initialize: HTTP {status}, no result"
            return p
        _post(url, {"jsonrpc": "2.0", "method": "notifications/initialized"}, sid, timeout)
        status, msg, sid = _post(url, {"jsonrpc": "2.0", "id": 2, "method": "tools/list"}, sid, timeout)
        p.tools = [t.get("name", "") for t in ((msg or {}).get("result") or {}).get("tools", [])]
        if not p.tools:
            p.detail = f"tools/list: HTTP {status}, empty"
            return p
        p.answering = YES
        p.detail = f"{len(p.tools)} tools"
        if tool:
            status, msg, _ = _post(url, _call(3, tool), sid, timeout)
            p.call_text = _text((msg or {}).get("result") or {})
    except (OSError, ValueError, urllib.error.URLError) as exc:
        p.answering = NO
        p.detail = f"{type(exc).__name__}: {exc}"[:120]
    return p


# ── stdio ───────────────────────────────────────────────────────────────────────────────────────

def _resolvable(cmd: str, env: Mapping[str, str]) -> bool:
    if os.sep in cmd:
        return os.access(cmd, os.X_OK)
    return shutil.which(cmd, path=env.get("PATH")) is not None


def probe_stdio(command: str, args: list[str], env: Mapping[str, str], *, extra_env: Mapping[str, str] | None = None,
                tool: str = "", timeout: float = 30.0) -> Probe:
    p = Probe(authenticated=NA)
    if not _resolvable(command, env):
        p.detail = f"command not found: {command}"
        return p
    p.listening = YES
    run_env = dict(env)
    run_env.update({k: str(v) for k, v in (extra_env or {}).items()})
    errlog = tempfile.TemporaryFile(mode="w+")   # kept, and quoted when the door does not answer
    try:
        proc = subprocess.Popen([command, *args], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                stderr=errlog, env=run_env, text=True, bufsize=1)
    except OSError as exc:
        errlog.close()
        p.listening = NO
        p.detail = f"could not start: {exc}"
        return p
    deadline = time.monotonic() + timeout
    sel = selectors.DefaultSelector()
    assert proc.stdout is not None and proc.stdin is not None
    sel.register(proc.stdout, selectors.EVENT_READ)

    def send(msg: dict) -> None:
        proc.stdin.write(json.dumps(msg) + "\n")
        proc.stdin.flush()

    def wait_for(rid: int) -> dict | None:
        while time.monotonic() < deadline:
            if not sel.select(timeout=max(0.1, deadline - time.monotonic())):
                continue
            line = proc.stdout.readline()
            if not line:
                return None
            try:
                msg = json.loads(line)
            except ValueError:
                continue
            if msg.get("id") == rid:
                return msg
        return None

    try:
        send(_init(1))
        if not (msg := wait_for(1)) or "result" not in msg:
            p.detail = "initialize: no answer within the timeout"
            return p
        send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        send({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
        msg = wait_for(2) or {}
        p.tools = [t.get("name", "") for t in (msg.get("result") or {}).get("tools", [])]
        if not p.tools:
            p.detail = "tools/list: empty or no answer"
            return p
        p.answering = YES
        p.detail = f"{len(p.tools)} tools"
        if tool:
            send(_call(3, tool))
            p.call_text = _text((wait_for(3) or {}).get("result") or {})
    except (OSError, ValueError) as exc:
        p.detail = f"{type(exc).__name__}: {exc}"[:120]
    finally:
        sel.close()
        try:
            proc.stdin.close()
        except OSError:
            pass
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=5)
        if p.answering != YES:
            errlog.seek(0)
            tail = errlog.read()[-160:].strip().replace("\n", " ")
            if tail:
                p.detail = f"{p.detail} · stderr: {tail}"
        errlog.close()
    return p

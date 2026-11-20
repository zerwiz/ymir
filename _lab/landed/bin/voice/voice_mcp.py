#!/usr/bin/env python3
"""voice_mcp.py — the voice's MCP adapter: every server this seat knows, as hands.

Rödd already had the house's own doors (voice_tools.py). What it could not reach was
**anything on the other side of MCP** — Chrome DevTools, Gimlé, the board, the mail, the
well's other faces. This module is that bridge, and only that: a small client for the two
transports MCP uses, reading the servers *this seat already declares* rather than a table
of its own (RULES/07).

    stdio  — a command that speaks newline-delimited JSON-RPC on its stdin/stdout
    http   — an endpoint that answers JSON-RPC (or SSE) on POST

Sources, later winning:
    .pi/mcp-adapter.json          (ships with the tree: ymir · well · engram)
    ~/.pi/agent/mcp.json          (this seat's own servers — the harness's list)
    <home>/config/voice-mcp.json  (the operator's additions for the voice: chrome-devtools …)

Law it obeys:
  * the servers are the seat's own; nothing private is written here (RULES/04);
  * a server that cannot start, or a tool that errors, is SAID, never swallowed;
  * a call is one line in the voice's activity log (voice_tools does the logging);
  * a remote server that wants an interactive sign-in is refused in words (RULES/39).

Usage (also importable):
    python3 bin/voice/voice_mcp.py servers
    python3 bin/voice/voice_mcp.py tools <server>
    python3 bin/voice/voice_mcp.py call <server> <tool> '<json args>'
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

PROTOCOL_VERSION = "2025-06-18"
DEFAULT_TIMEOUT = int(os.environ.get("YMIR_VOICE_MCP_TIMEOUT", "90"))


def _root() -> Path:
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "RULES").is_dir() and (parent / ".agents").is_dir():
            return parent
    return here.parent


ROOT = _root()


def _home() -> Path:
    if (explicit := os.environ.get("YMIR_HOME")):
        return Path(explicit)
    try:
        lib = ROOT / "bin" / "vault" / "hoard-lib.sh"
        out = subprocess.run(["bash", "-lc", f'. "{lib}" && ymir_home_root'], capture_output=True,
                             text=True, timeout=15)
        cand = (out.stdout or "").strip().splitlines()[-1] if out.stdout.strip() else ""
        if cand and (Path(cand) / "hodd").is_dir():
            return Path(cand)
    except Exception:
        pass
    return Path(os.environ.get("YMIR_VOICE_STATE", str(Path.home())))


# ── the servers: what this seat declares, nothing invented ────────────────────

def _sources() -> list[Path]:
    return [
        ROOT / ".pi" / "mcp-adapter.json",
        Path.home() / ".pi" / "agent" / "mcp.json",
        _home() / "config" / "voice-mcp.json",
    ]


def servers() -> dict[str, dict]:
    """Every declared server, merged. A later file wins a name it repeats."""
    out: dict[str, dict] = {}
    for path in _sources():
        try:
            data = json.loads(path.read_text())
        except Exception:
            continue
        table = data.get("mcpServers") or data.get("servers") or data
        if not isinstance(table, dict):
            continue
        for name, spec in table.items():
            if isinstance(spec, dict) and (spec.get("url") or spec.get("command")):
                out[name] = spec
    return out


def _remote(spec: dict) -> bool:
    return bool(spec.get("url"))


# ── the harness's own grants, borrowed not copied ─────────────────────────────
# The seat already holds OAuth grants for the Google MCP servers (gmail · drive · docs)
# and for trello: Pi minted them once, in a browser, and keeps them in
# ~/.pi/agent/mcp-auth.json keyed by `mcp__<name>|<url>`. A voice that asked him to
# consent a second time for the same account would be a worse guest than the harness.
# So the token is READ from that store and, when it has expired, REFRESHED in memory
# for this process only — the store is the harness's to rewrite, never ours.

_AUTH_CACHE: dict[str, str] = {}


def _pi_auth_path() -> Path:
    return Path.home() / ".pi" / "agent" / "mcp-auth.json"


def _pi_auth(name: str, url: str) -> str:
    """A bearer token for this server, refreshed in memory if the stored one has expired."""
    key = f"mcp__{name}|{url}"
    if key in _AUTH_CACHE:
        return _AUTH_CACHE[key]
    try:
        store = json.loads(_pi_auth_path().read_text())
    except Exception:
        return ""
    entry = store.get(key) or {}
    tokens = entry.get("tokens") or {}
    access = str(tokens.get("access_token") or "")
    expires_at = entry.get("tokensExpireAt") or 0
    import time as _time
    fresh_enough = access and (not expires_at or _time.time() < (expires_at / 1000) - 60)
    if fresh_enough:
        _AUTH_CACHE[key] = access
        return access
    refresh = str(tokens.get("refresh_token") or "")
    client = entry.get("clientInformation") or {}
    token_endpoint = (entry.get("discovery") or {}).get("token_endpoint") or "https://oauth2.googleapis.com/token"
    if not (refresh and client.get("client_id")):
        return access          # nothing to refresh with: use it and let the server refuse in words
    import urllib.error
    import urllib.parse
    import urllib.request
    body = urllib.parse.urlencode({
        "grant_type": "refresh_token",
        "refresh_token": refresh,
        "client_id": client["client_id"],
        **({"client_secret": client["client_secret"]} if client.get("client_secret") else {}),
    }).encode()
    req = urllib.request.Request(token_endpoint, data=body, method="POST",
                                 headers={"Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            payload = json.loads(resp.read().decode("utf-8", "ignore"))
    except Exception as exc:
        raise McpError(f"{name} needs a fresh sign-in: its grant could not be refreshed ({exc}). "
                       "Ask the harness to re-authorise that server once.") from None
    new = str(payload.get("access_token") or "")
    if not new:
        raise McpError(f"{name} needs a fresh sign-in: the refresh returned no token")
    _AUTH_CACHE[key] = new
    return new


# ── one JSON-RPC exchange, per transport ─────────────────────────────────────

def _server_name(url: str) -> str:
    """Which declared server this URL belongs to — so the harness's grant key is found."""
    for name, spec in servers().items():
        if spec.get("url") == url:
            return name
    return url

class McpError(RuntimeError):
    pass


def _rpc_http(spec: dict, messages: list[dict], timeout: int) -> list[dict]:
    """JSON-RPC over streamable HTTP: POST, then read JSON or SSE back."""
    import urllib.error
    import urllib.request

    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
        "MCP-Protocol-Version": PROTOCOL_VERSION,
    }
    for key, value in (spec.get("headers") or {}).items():
        headers[key] = str(value)
    auth = os.environ.get(spec.get("token_env", ""), "") if spec.get("token_env") else ""
    if not auth:
        auth = _pi_auth(_server_name(spec.get("url", "")), spec["url"])
    if auth:
        headers.setdefault("Authorization", f"Bearer {auth}")
    body = json.dumps(messages[0] if len(messages) == 1 else messages).encode()
    req = urllib.request.Request(spec["url"], data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8", "ignore")
            ctype = resp.headers.get("Content-Type", "")
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "ignore")[:300]
        raise McpError(f"HTTP {exc.code} from {spec['url']}: {detail or exc.reason}") from None
    except Exception as exc:
        raise McpError(f"{spec['url']} did not answer: {exc}") from None
    if "text/event-stream" in ctype:
        out = []
        for line in raw.splitlines():
            if line.startswith("data:"):
                payload = line[5:].strip()
                if not payload or payload == "[DONE]":
                    continue
                try:
                    out.append(json.loads(payload))
                except Exception:
                    continue
        return out
    try:
        data = json.loads(raw)
    except Exception as exc:
        raise McpError(f"nnnon-JSON answer from {spec['url']}: {raw[:200]}") from None
    return data if isinstance(data, list) else [data]


def _rpc_stdio(spec: dict, calls: list[dict], timeout: int) -> list[dict]:
    """JSON-RPC over a child process: one session, every message in `calls`, then close.

    One-shot on purpose: the voice calls a server a few times a conversation, and a
    spawn-per-call cannot leak a half-initialised session into the next turn.
    """
    cmd = [spec["command"], *(spec.get("args") or [])]
    if shutil.which(cmd[0]) is None and not Path(cmd[0]).exists():
        raise McpError(f"the {cmd[0]} binary is not on PATH")
    env = dict(os.environ)
    env.update({k: str(v) for k, v in (spec.get("env") or {}).items()})
    try:
        proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, text=True, bufsize=1, env=env,
                                cwd=str(spec.get("cwd") or ROOT))
    except Exception as exc:
        raise McpError(f"could not start {cmd[0]}: {exc}") from None
    out: list[dict] = []
    try:
        for msg in calls:
            proc.stdin.write(json.dumps(msg) + "\n")
            proc.stdin.flush()
            want = msg.get("id")
            if want is None:       # a notification: no answer expected
                continue
            while True:
                line = proc.stdout.readline()
                if not line:
                    err = (proc.stderr.read() or "")[:300] if proc.stderr else ""
                    raise McpError(f"{spec.get('command')} closed the pipe: {err.strip() or 'no detail'}")
                line = line.strip()
                if not line:
                    continue
                try:
                    reply = json.loads(line)
                except Exception:
                    continue
                if reply.get("id") == want:
                    out.append(reply)
                    break
    finally:
        try:
            proc.stdin.close()
        except Exception:
            pass
        try:
            proc.terminate()
            proc.wait(timeout=5)
        except Exception:
            try:
                proc.kill()
            except Exception:
                pass
    return out


def _session(spec: dict, timeout: int) -> list[dict]:
    """initialize → initialized → tools/list."""
    init = {"jsonrpc": "2.0", "id": 1, "method": "initialize",
            "params": {"protocolVersion": PROTOCOL_VERSION,
                       "capabilities": {"roots": {"listChanged": False}, "sampling": {}},
                       "clientInfo": {"name": "rodd", "version": "1.0"}}}
    ready = {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}}
    lst = {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}
    return _rpc_http(spec, [init], timeout) + _rpc_http(spec, [lst], timeout) if _remote(spec) \
        else _rpc_stdio(spec, [init, ready, lst], timeout)


_CACHE: dict[str, list[dict]] = {}


def tools(server: str, timeout: int = DEFAULT_TIMEOUT) -> list[dict]:
    """The server's tool list, cached for this process (a list is stable per server)."""
    if server in _CACHE:
        return _CACHE[server]
    spec = servers().get(server)
    if not spec:
        raise McpError(f"no MCP server named {server!r} is declared on this seat")
    replies = _session(spec, timeout)
    found: list[dict] = []
    error = ""
    for reply in replies:
        if reply.get("error"):
            error = str(reply["error"])[:300]
        result = reply.get("result") or {}
        if isinstance(result.get("tools"), list):
            found = result["tools"]
    if not found and error:
        raise McpError(error)
    if error and "Authorization" in error:
        raise McpError(f"{server} wants an interactive sign-in (OAuth). Use the harness to grant it once; "
                       f"the voice cannot open a browser: {error}")
    _CACHE[server] = found
    return found


def call(server: str, tool: str, arguments: dict | None = None, timeout: int = DEFAULT_TIMEOUT) -> str:
    """One tool call, flattened to the words a voice can read out."""
    spec = servers().get(server)
    if not spec:
        raise McpError(f"no MCP server named {server!r} is declared on this seat")
    init = {"jsonrpc": "2.0", "id": 1, "method": "initialize",
            "params": {"protocolVersion": PROTOCOL_VERSION,
                       "capabilities": {}, "clientInfo": {"name": "rodd", "version": "1.0"}}}
    ready = {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}}
    do = {"jsonrpc": "2.0", "id": 2, "method": "tools/call",
          "params": {"name": tool, "arguments": arguments or {}}}
    if _remote(spec):
        _rpc_http(spec, [init], timeout)
        replies = _rpc_http(spec, [do], timeout)
    else:
        replies = _rpc_stdio(spec, [init, ready, do], timeout)
    for reply in replies:
        if reply.get("error"):
            raise McpError(str(reply["error"])[:400])
        result = reply.get("result")
        if not isinstance(result, dict):
            continue
        # the initialize reply carries no content: skip it, never report it as an empty
        # result (the first call through this door said "empty" for a tool that answered)
        if "content" not in result and not result.get("isError") and "structuredContent" not in result:
            continue
        chunks = []
        for item in result.get("content") or []:
            if item.get("type") == "text":
                chunks.append(str(item.get("text") or ""))
            elif item.get("type") == "image":
                chunks.append("[an image came back — say so, do not describe what you cannot see]")
            elif item.get("type") == "resource":
                res = item.get("resource") or {}
                chunks.append(str(res.get("text") or res.get("uri") or "[a resource]"))
        text = "\n".join(c for c in chunks if c).strip()
        if result.get("isError"):
            return f"{server}/{tool} refused: {text or 'no reason given'}"
        return text or f"{server}/{tool} returned an empty result."
    raise McpError(f"{server}/{tool} produced no result")


# ── the CLI, for a shell and for a test ──────────────────────────────────────

def main(argv: list[str]) -> int:
    cmd = argv[1] if len(argv) > 1 else "servers"
    try:
        if cmd == "servers":
            table = servers()
            print(f"servers[{len(table)}]{{name,transport,where}}:")
            for name, spec in table.items():
                where = spec.get("url") or f"{spec.get('command')} {' '.join(spec.get('args') or [])[:40]}"
                print(f'  "{name}","{"http" if _remote(spec) else "stdio"}","{where}"')
            return 0
        if cmd == "tools":
            if len(argv) < 3:
                print("usage: voice_mcp.py tools <server>", file=sys.stderr)
                return 2
            found = tools(argv[2])
            print(f"tools[{len(found)}]{{name,description}}:")
            for t in found:
                print(f'  "{t.get("name")}","{(t.get("description") or "").splitlines()[0][:90]}"')
            return 0
        if cmd == "call":
            if len(argv) < 4:
                print("usage: voice_mcp.py call <server> <tool> '<json args>'", file=sys.stderr)
                return 2
            args = json.loads(argv[4]) if len(argv) > 4 and argv[4].strip() else {}
            print(call(argv[2], argv[3], args))
            return 0
    except McpError as exc:
        print(f"voice_mcp: {exc}", file=sys.stderr)
        return 1
    print("usage: voice_mcp.py [servers|tools <server>|call <server> <tool> '<json>']", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

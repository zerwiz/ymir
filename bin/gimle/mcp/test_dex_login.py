#!/usr/bin/env python3
"""test_dex_login.py — the door against a REAL Dex, raised from this directory's own config (plan 149).

test_oauth_door.py proves the door against a stand-in issuer. This one proves the shipped Dex config and the
door together: it raises `ghcr.io/dexidp/dex` from dex/config.example.yaml (with the stand-in connector
switched on, because the Google and GitHub apps are the operator's to create), walks a real authorization-code
login with PKCE as the public client `gimle-mcp-cli`, and hands the access token to a door started with
`--oauth-issuer`. It then proves a token Dex issued to another client is refused.

Everything is torn down by name and PID on exit. No docker → a clean skip (exit 0, said plainly).

    python3 bin/gimle/mcp/test_dex_login.py
"""
from __future__ import annotations

import base64
import hashlib
import json
import os
import secrets
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
IMAGE = "ghcr.io/dexidp/dex:v2.41.1"
FAILS: list[str] = []


def free_port() -> int:
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


def check(title, cond, detail=""):
    print(("PASS  " if cond else "FAIL  ") + title + ("" if cond else f" — {detail}"))
    if not cond:
        FAILS.append(title)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None


OPENER = urllib.request.build_opener(NoRedirect)


def login(base: str, client: str, secret: str, redirect: str) -> dict:
    """A real authorization-code + PKCE login through Dex's stand-in connector; returns the token response."""
    verifier = secrets.token_urlsafe(48)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    url = base + "/auth?" + urllib.parse.urlencode({
        "client_id": client, "redirect_uri": redirect, "response_type": "code",
        "scope": "openid profile email groups", "state": "s1", "connector_id": "mock",
        "code_challenge": challenge, "code_challenge_method": "S256"})
    for _ in range(10):
        try:
            OPENER.open(url, timeout=10)
            raise RuntimeError(f"Dex stopped redirecting at {url}")
        except urllib.error.HTTPError as e:
            if e.code not in (301, 302, 303, 307):
                raise RuntimeError(f"Dex answered {e.code} at {url}: {e.read()[:200]!r}")
            url = urllib.parse.urljoin(url, e.headers["Location"])
        if url.startswith(redirect):
            break
    code = urllib.parse.parse_qs(urllib.parse.urlparse(url).query)["code"][0]
    form = {"grant_type": "authorization_code", "code": code, "redirect_uri": redirect,
            "code_verifier": verifier, "client_id": client}
    req = urllib.request.Request(base + "/token", data=urllib.parse.urlencode(form).encode(), method="POST")
    if secret:
        req.add_header("Authorization", "Basic " + base64.b64encode(f"{client}:{secret}".encode()).decode())
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.loads(r.read())


def door_tool(port: int, token: str, name: str):
    body = {"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": name, "arguments": {}}}
    req = urllib.request.Request(f"http://127.0.0.1:{port}/mcp", data=json.dumps(body).encode(), method="POST",
                                 headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            out = json.loads(r.read())["result"]
            return 200, json.loads(out["content"][0]["text"])
    except urllib.error.HTTPError as e:
        return e.code, {"www": e.headers.get("WWW-Authenticate", "")}


def main() -> int:
    if not shutil.which("docker") or subprocess.run(["docker", "info"], capture_output=True).returncode:
        print("skip  docker is not available here — the stand-in issuer test (test_oauth_door.py) still stands")
        return 0
    tmp = tempfile.mkdtemp(prefix="gimle-dex-test-")
    name = f"gimle-dex-test-{secrets.token_hex(4)}"
    dex_port, door_port = free_port(), free_port()
    issuer = f"http://127.0.0.1:{dex_port}/dex"
    door = None
    try:
        cfg = open(os.path.join(HERE, "dex", "config.example.yaml"), encoding="utf-8").read()
        cfg = cfg.replace("  # - type: mockCallback\n  #   id: mock\n  #   name: Stand-in (testing only)\n",
                          "  - type: mockCallback\n    id: mock\n    name: Stand-in (testing only)\n")
        cfg = cfg.replace("staticClients:\n", "staticClients:\n  - id: other-app\n    name: Another app\n"
                                              "    public: true\n", 1)
        assert "type: mockCallback\n    id: mock" in cfg, "the stand-in connector block moved; update this test"
        cfg = cfg.replace("https://id.example.org/dex", issuer)
        open(os.path.join(tmp, "config.yaml"), "w").write(cfg)
        secret = secrets.token_hex(16)
        open(os.path.join(tmp, "dex.env"), "w").write(
            f"GITHUB_CLIENT_ID=placeholder\nGITHUB_CLIENT_SECRET=placeholder\n"
            f"GOOGLE_CLIENT_ID=placeholder\nGOOGLE_CLIENT_SECRET=placeholder\nGIMLE_MCP_CLIENT_SECRET={secret}\n")
        state = os.path.join(tmp, "state")
        os.mkdir(state)
        os.chmod(state, 0o777)
        run = subprocess.run(["docker", "run", "-d", "--rm", "--name", name, "-p", f"127.0.0.1:{dex_port}:5556",
                              "--env-file", os.path.join(tmp, "dex.env"),
                              "-v", f"{tmp}/config.yaml:/etc/dex/config.yaml:ro", "-v", f"{state}:/var/dex",
                              IMAGE, "dex", "serve", "/etc/dex/config.yaml"], capture_output=True, text=True)
        if run.returncode:
            check("Dex starts from the shipped config", False, run.stderr.strip()[:300])
            return 1
        up = False
        for _ in range(100):
            try:
                with urllib.request.urlopen(issuer + "/.well-known/openid-configuration", timeout=1) as r:
                    up = json.loads(r.read()).get("issuer") == issuer
                    break
            except Exception:  # noqa: BLE001
                time.sleep(0.2)
        logs = subprocess.run(["docker", "logs", name], capture_output=True, text=True)
        check("Dex starts from the shipped config, issuer answers", up, (logs.stdout + logs.stderr)[-600:])
        if not up:
            return 1

        open(os.path.join(tmp, "groups"), "w").write("")  # filled once Dex has named its stand-in user
        open(os.path.join(tmp, "tokens"), "w").write("")
        door = subprocess.Popen([sys.executable, os.path.join(HERE, "gimle-mcp.py"), "--port", str(door_port),
                                 "--data", os.path.join(tmp, "meetings.json"), "--tokens", os.path.join(tmp, "tokens"),
                                 "--audit", os.path.join(tmp, "access.jsonl"), "--oauth-issuer", issuer,
                                 "--oauth-audience", "gimle-mcp,gimle-mcp-cli",
                                 "--oauth-groups", os.path.join(tmp, "groups")],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(100):
            with socket.socket() as s:
                if s.connect_ex(("127.0.0.1", door_port)) == 0:
                    break
            time.sleep(0.05)

        tok = login(issuer, "gimle-mcp-cli", "", "http://localhost:8976/callback")
        # who the stand-in connector says the person is — asked of Dex itself, never written here. Dex gives
        # it no preferred_username, so the door's subject is the email (its fallback before the opaque sub).
        req = urllib.request.Request(issuer + "/userinfo", headers={"Authorization": f"Bearer {tok['access_token']}"})
        with urllib.request.urlopen(req, timeout=10) as r:
            info = json.loads(r.read())
        who = info.get("preferred_username") or info.get("email") or info.get("sub")
        with open(os.path.join(tmp, "groups"), "w") as fh:  # granted by the opaque sub, the key no one can guess
            fh.write(f"{info['sub']} gimle-place-Ymir,gimle-write\n")
        code, me = door_tool(door_port, tok["access_token"], "who_am_i")
        rows = [json.loads(line) for line in open(os.path.join(tmp, "access.jsonl"))]
        check("a real Dex login (PKCE, public client) is admitted with the right subject and road",
              code == 200 and who and me.get("subject") == who and me.get("road") == "oauth"
              and me.get("places_granted") == ["Ymir"]
              and rows[-1]["subject"] == who and rows[-1]["road"] == "oauth", f"{code} {me}")

        tok_conf = login(issuer, "gimle-mcp", secret, "https://claude.ai/api/mcp/auth_callback")
        code, me = door_tool(door_port, tok_conf["access_token"], "who_am_i")
        check("the confidential client gimle-mcp (a connector's id + secret) is admitted too",
              code == 200 and me.get("subject") == who, f"{code} {me}")

        tok_other = login(issuer, "other-app", "", "http://localhost:8977/callback")
        code, me = door_tool(door_port, tok_other["access_token"], "who_am_i")
        rows = [json.loads(line) for line in open(os.path.join(tmp, "access.jsonl"))]
        check("a token Dex issued to another app is refused, reason logged",
              code == 401 and "other-app" in rows[-1]["why"] and rows[-1]["verdict"] == "refused", f"{code} {rows[-1]}")
    finally:
        if door is not None:
            door.terminate()
            try:
                door.wait(timeout=5)
            except subprocess.TimeoutExpired:
                door.kill()
        subprocess.run(["docker", "rm", "-f", name], capture_output=True)
        gone = subprocess.run(["docker", "ps", "-q", "--filter", f"name={name}"], capture_output=True, text=True)
        print("ok    Dex container removed" if not gone.stdout.strip() else f"FAIL  container {name} still runs")
        subprocess.run(["docker", "run", "--rm", "-v", f"{tmp}:/t", "--entrypoint", "sh", IMAGE, "-c",
                        "rm -rf /t/state"], capture_output=True)  # the container's files are not ours to unlink
        shutil.rmtree(tmp, ignore_errors=True)
    print(f"{'all green' if not FAILS else str(len(FAILS)) + ' failed'}")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())

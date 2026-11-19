#!/usr/bin/env python3
"""test_oauth_door.py — plan 149's eight tests, in ONE script, against a stand-in issuer.

The reviewer's first two runs died on leftover servers holding fixed ports, so this script:
  * picks its own free ports at run time, and records every child it starts by PID;
  * kills only those PIDs on exit (also on Ctrl-C and on a failed assertion) and checks the ports are free;
  * writes every file under one temp directory it removes afterwards.

The stand-in issuer is a real OIDC issuer in miniature (standard library): discovery, a JWKS with a freshly
generated RSA key, RS256-signed access tokens, `userinfo` and RFC 7662 introspection. Nothing here touches a
real identity provider, a real board, or a real token file; every name is invented.

    python3 bin/gimle/mcp/test_oauth_door.py          # exit 0: all green · 1: a failure, named
"""
from __future__ import annotations

import base64
import hashlib
import json
import os
import secrets
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
DOOR = os.path.join(HERE, "gimle-mcp.py")
sys.path.insert(0, HERE)
import gimle_oauth  # noqa: E402

CHILDREN: list[subprocess.Popen] = []
FAILS: list[str] = []
PASSES: list[str] = []


# ── a pure-python RSA key: the test takes no dependency the door does not ────────────────
def _probable_prime(bits: int) -> int:
    small = [p for p in range(3, 2000, 2) if all(p % q for q in range(3, int(p ** 0.5) + 1, 2))]
    while True:
        c = secrets.randbits(bits) | (1 << (bits - 1)) | 1
        if any(c % p == 0 for p in small):
            continue
        d, r = c - 1, 0
        while d % 2 == 0:
            d //= 2
            r += 1
        for _ in range(24):
            a = secrets.randbelow(c - 3) + 2
            x = pow(a, d, c)
            if x in (1, c - 1):
                continue
            for _ in range(r - 1):
                x = pow(x, 2, c)
                if x == c - 1:
                    break
            else:
                break
        else:
            return c


def rsa_key(bits: int = 2048):
    e = 65537
    while True:
        p, q = _probable_prime(bits // 2), _probable_prime(bits // 2)
        phi = (p - 1) * (q - 1)
        if p != q and phi % e:
            n = p * q
            if n.bit_length() == bits:
                return n, e, pow(e, -1, phi)


def b64i(i: int) -> str:
    return gimle_oauth.b64url_encode(i.to_bytes((i.bit_length() + 7) // 8, "big"))


def sign_jwt(key, kid: str, claims: dict) -> str:
    n, e, d = key
    h = gimle_oauth.b64url_encode(json.dumps({"alg": "RS256", "kid": kid, "typ": "JWT"}).encode())
    p = gimle_oauth.b64url_encode(json.dumps(claims).encode())
    k = (n.bit_length() + 7) // 8
    t = bytes.fromhex("3031300d060960864801650304020105000420") + hashlib.sha256(f"{h}.{p}".encode()).digest()
    em = b"\x00\x01" + b"\xff" * (k - len(t) - 3) + b"\x00" + t
    sig = pow(int.from_bytes(em, "big"), d, n).to_bytes(k, "big")
    return f"{h}.{p}.{gimle_oauth.b64url_encode(sig)}"


# ── the stand-in issuer ──────────────────────────────────────────────────────────────────
class Issuer:
    def __init__(self, port: int):
        self.port = port
        self.url = f"http://127.0.0.1:{port}"
        self.key = rsa_key()
        self.kid = "standin-1"
        self.users: dict[str, dict] = {}   # access token → userinfo claims
        self.introspect_secret = secrets.token_hex(16)
        self.calls = {"userinfo": 0, "introspect": 0, "jwks": 0}

    def mint(self, client: str, username: str, groups: list[str], email: str = "", ttl: int = 600) -> str:
        now = int(time.time())
        sub = "Cg" + gimle_oauth.b64url_encode(username.encode())  # opaque, the way Dex shapes a sub
        claims = {"iss": self.url, "sub": sub, "aud": client, "azp": client, "exp": now + ttl, "iat": now}
        token = sign_jwt(self.key, self.kid, claims)
        self.users[token] = {"sub": sub, "preferred_username": username, "groups": groups,
                             "email": email or f"{username}@example.org", "client": client, "exp": now + ttl}
        return token

    def serve(self):
        issuer = self

        class H(BaseHTTPRequestHandler):
            def _j(self, code, obj):
                b = json.dumps(obj).encode()
                self.send_response(code)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(b)))
                self.end_headers()
                self.wfile.write(b)

            def do_GET(self):  # noqa: N802
                if self.path == "/.well-known/openid-configuration":
                    return self._j(200, {"issuer": issuer.url, "jwks_uri": issuer.url + "/keys",
                                         "userinfo_endpoint": issuer.url + "/userinfo",
                                         "introspection_endpoint": issuer.url + "/introspect",
                                         "authorization_endpoint": issuer.url + "/auth",
                                         "token_endpoint": issuer.url + "/token"})
                if self.path == "/keys":
                    issuer.calls["jwks"] += 1
                    n, e, _ = issuer.key
                    return self._j(200, {"keys": [{"kty": "RSA", "kid": issuer.kid, "alg": "RS256",
                                                   "use": "sig", "n": b64i(n), "e": b64i(e)}]})
                if self.path == "/userinfo":
                    issuer.calls["userinfo"] += 1
                    tok = (self.headers.get("Authorization") or "")[7:]
                    u = issuer.users.get(tok)
                    if not u:
                        return self._j(401, {"error": "invalid_token"})
                    return self._j(200, {k: u[k] for k in ("sub", "preferred_username", "groups", "email")})
                self._j(404, {})

            def do_POST(self):  # noqa: N802
                if self.path == "/introspect":
                    issuer.calls["introspect"] += 1
                    basic = (self.headers.get("Authorization") or "")[6:]
                    cid, _, sec = base64.b64decode(basic).decode().partition(":")
                    if sec != issuer.introspect_secret:
                        return self._j(401, {"error": "invalid_client"})
                    form = urllib.parse.parse_qs(self.rfile.read(int(self.headers["Content-Length"])).decode())
                    u = issuer.users.get(form.get("token", [""])[0])
                    if not u:
                        return self._j(200, {"active": False})
                    return self._j(200, {"active": True, "iss": issuer.url, "sub": u["sub"],
                                         "client_id": u["client"], "aud": [u["client"]],
                                         "username": u["preferred_username"], "exp": u["exp"]})
                self._j(404, {})

            def log_message(self, *a):
                pass

        self.httpd = ThreadingHTTPServer(("127.0.0.1", self.port), H)
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()


# ── plumbing ─────────────────────────────────────────────────────────────────────────────
def free_port() -> int:
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


def port_open(port: int) -> bool:
    with socket.socket() as s:
        s.settimeout(0.2)
        return s.connect_ex(("127.0.0.1", port)) == 0


def start_door(port: int, tmp: str, extra: list[str]) -> subprocess.Popen:
    log = open(os.path.join(tmp, f"door-{port}.log"), "w")
    proc = subprocess.Popen([sys.executable, DOOR, "--port", str(port),
                             "--data", os.path.join(tmp, "meetings.json"),
                             "--tokens", os.path.join(tmp, "tokens"),
                             "--audit", os.path.join(tmp, "access.jsonl"), *extra],
                            stdout=log, stderr=subprocess.STDOUT, env=dict(os.environ, GIMLE_BOARD_AGENT="/nonexistent"))
    CHILDREN.append(proc)
    for _ in range(100):
        if port_open(port):
            return proc
        if proc.poll() is not None:
            break
        time.sleep(0.05)
    raise SystemExit(f"the door on {port} did not start: {open(log.name).read()}")


def http(method: str, url: str, token: str = "", body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.status, dict(r.headers), json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            doc = json.loads(raw or b"{}")
        except ValueError:
            doc = {"raw": raw.decode(errors="replace")}
        return e.code, dict(e.headers), doc


def rpc(port: int, token: str, method: str, params=None):
    return http("POST", f"http://127.0.0.1:{port}/mcp", token,
                {"jsonrpc": "2.0", "id": 1, "method": method, "params": params or {}})


def tool(port: int, token: str, name: str, args=None):
    code, _, doc = rpc(port, token, "tools/call", {"name": name, "arguments": args or {}})
    res = doc.get("result") or {}
    text = (res.get("content") or [{}])[0].get("text", "{}")
    return code, bool(res.get("isError")), json.loads(text)


def ledger(tmp: str) -> list[dict]:
    try:
        with open(os.path.join(tmp, "access.jsonl"), encoding="utf-8") as fh:
            return [json.loads(line) for line in fh if line.strip()]
    except OSError:
        return []


def check(n, title, cond, detail=""):
    line = f"  {n} · {title}"
    if cond:
        PASSES.append(line)
        print(f"PASS{line}")
    else:
        FAILS.append(line + (f" — {detail}" if detail else ""))
        print(f"FAIL{line}" + (f" — {detail}" if detail else ""))


def cleanup(*_):
    for p in CHILDREN:
        if p.poll() is None:
            p.terminate()
    for p in CHILDREN:
        try:
            p.wait(timeout=5)
        except subprocess.TimeoutExpired:
            p.kill()


def main() -> int:
    signal.signal(signal.SIGTERM, lambda *a: (cleanup(), sys.exit(1)))
    tmp = tempfile.mkdtemp(prefix="gimle-oauth-test-")
    ports = {"issuer": free_port(), "ro": free_port(), "rw": free_port(), "intro": free_port()}
    try:
        issuer = Issuer(ports["issuer"])
        issuer.serve()
        static_ro = secrets.token_hex(16)
        static_rw = secrets.token_hex(16)
        with open(os.path.join(tmp, "tokens"), "w") as fh:
            fh.write(f"# a comment line is ignored\n")
            fh.write(f"{static_ro} ada *\n")
            fh.write(f'{static_rw} brann "acme/Field Notes,Ymir" fleet=guest-house\n')
        with open(os.path.join(tmp, "meetings.json"), "w") as fh:
            json.dump({"meetings": [{"id": "m1", "title": "Ymir", "actions": [], "questions": []}]}, fh)
        with open(os.path.join(tmp, "secret"), "w") as fh:
            fh.write(issuer.introspect_secret)
        with open(os.path.join(tmp, "groups"), "w") as fh:
            fh.write("# local grants for issuers that carry no groups\ncarys@example.org gimle-place-Ymir\n")

        common = ["--oauth-issuer", issuer.url, "--oauth-audience", "gimle-mcp,gimle-mcp-cli",
                  "--oauth-groups", os.path.join(tmp, "groups")]
        start_door(ports["ro"], tmp, common + ["--oauth-resource", "https://mcp.example.org/mcp"])
        start_door(ports["rw"], tmp, common + ["--allow-write"])
        start_door(ports["intro"], tmp, ["--oauth-issuer", issuer.url, "--oauth-audience", "gimle-mcp",
                                         "--oauth-mode", "introspect", "--oauth-client-id", "gimle-mcp",
                                         "--oauth-secret-file", os.path.join(tmp, "secret")])
        ro, rw, intro = ports["ro"], ports["rw"], ports["intro"]

        # 1 · no token → 401 WITH WWW-Authenticate
        code, hdr, doc = rpc(ro, "", "tools/list")
        www = hdr.get("WWW-Authenticate", "")
        check(1, "no token → 401 with WWW-Authenticate",
              code == 401 and 'resource_metadata="https://mcp.example.org/.well-known/oauth-protected-resource"' in www,
              f"{code} {www!r}")

        # 2 · metadata names the issuer
        code, _, meta = http("GET", f"http://127.0.0.1:{ro}/.well-known/oauth-protected-resource")
        code2, _, meta2 = http("GET", f"http://127.0.0.1:{ro}/.well-known/oauth-protected-resource/mcp")
        check(2, "metadata served, issuer named",
              code == 200 and meta.get("authorization_servers") == [issuer.url]
              and meta.get("resource") == "https://mcp.example.org/mcp" and code2 == 200, json.dumps(meta))

        # 3 · the static token, unchanged — and the comma-only places column
        code, _, listed = rpc(ro, static_ro, "tools/list")
        _, err, me = tool(ro, static_ro, "who_am_i")
        _, _, me2 = tool(rw, static_rw, "who_am_i")
        row = [r for r in ledger(tmp) if r.get("subject") == "ada" and r.get("tool") == "who_am_i"]
        check(3, "static token unchanged (200, tools listed, road=bearer-file, a spaced place survives)",
              code == 200 and len(listed["result"]["tools"]) > 0 and not err and me["subject"] == "ada"
              and row and row[-1]["road"] == "bearer-file"
              and me2.get("places_granted") == ["acme/Field Notes", "Ymir"]
              and [r for r in ledger(tmp) if r.get("subject") == "brann"][-1].get("fleet") == "guest-house",
              f"{code} {me} {me2}")

        # 4 · an OAuth login → accepted, the right subject in the ledger
        tok_writer = issuer.mint("gimle-mcp", "dagny", ["gimle-all", "gimle-write"])
        _, err, me = tool(ro, tok_writer, "who_am_i")
        row = [r for r in ledger(tmp) if r.get("road") == "oauth" and r.get("tool") == "who_am_i"]
        check(4, "an OAuth login accepted, the right subject in access.jsonl",
              not err and me.get("subject") == "dagny" and me.get("road") == "oauth"
              and row and row[-1]["subject"] == "dagny" and row[-1]["verdict"] == "allowed"
              and row[-1].get("client") == "gimle-mcp", f"{me} {row[-1:] }")

        # 5 · a token another app was given on the same issuer → refused, reason logged
        tok_other = issuer.mint("other-app", "egil", ["gimle-all", "gimle-write"])
        code, hdr, doc = rpc(ro, tok_other, "tools/list")
        # the refused token is never taken to userinfo, so the ledger names it by its own `sub`
        egil_sub = issuer.users[tok_other]["sub"]
        row = [r for r in ledger(tmp) if r.get("subject") == egil_sub]
        check(5, "a token from another app refused, reason logged",
              code == 401 and 'error="invalid_token"' in hdr.get("WWW-Authenticate", "")
              and row and row[-1]["verdict"] == "refused" and "other-app" in row[-1]["why"]
              and row[-1]["road"] == "oauth", f"{code} {row[-1:]}")

        # 6 · a login without gimle-write → a canvas write refused on a WRITABLE door, reason logged
        tok_reader = issuer.mint("gimle-mcp-cli", "frida", ["gimle-place-Ymir"])
        _, err, out = tool(rw, tok_reader, "add_elements", {"room": "r1", "nodes": [{"id": "a"}]})
        row = [r for r in ledger(tmp) if r.get("subject") == "frida" and r.get("tool") == "add_elements"]
        _, err_w, out_w = tool(rw, tok_writer, "add_elements", {"room": "r1", "nodes": [{"id": "a"}]})
        check(6, "a login without gimle-write refused on a canvas write, reason logged",
              err and "gimle-write" in out.get("error", "") and row and row[-1]["verdict"] == "refused"
              and "gimle-write" in row[-1]["why"]
              # and the gate is the grant, not a blanket: a writer passes it (the board agent, absent here, answers)
              and "gimle-write" not in out_w.get("error", "") and "read-only" not in out_w.get("error", ""),
              f"{out} {row[-1:]} / writer: {out_w}")

        # 7 · a STATIC token on a read-only door → the same canvas write refused (the gap plan 149 closes)
        results = {}
        for verb, args in (("add_elements", {"room": "r1", "nodes": [{"id": "a"}]}),
                           ("update_elements", {"room": "r1", "updates": [{"id": "a"}]}),
                           ("save_room", {"room": "r1"}), ("share_room", {"room": "r1"})):
            _, err, out = tool(ro, static_ro, verb, args)
            results[verb] = err and "read-only" in out.get("error", "")
        rows = [r for r in ledger(tmp) if r.get("subject") == "ada" and r.get("tool") in results]
        check(7, "a static token on a read-only door refused on every canvas write, logged",
              all(results.values()) and len(rows) == 4 and all(r["verdict"] == "refused" and "read-only" in r["why"]
                                                                for r in rows), f"{results} {rows}")

        # 8 · GET /mcp → 405
        code, hdr, _ = http("GET", f"http://127.0.0.1:{ro}/mcp")
        check(8, "GET /mcp → 405", code == 405 and hdr.get("Allow") == "POST", f"{code}")

        # ── beyond the eight: the roads the plan also names ─────────────────────────
        tok_intro = issuer.mint("gimle-mcp", "gudrun", ["gimle-place-Ymir"])
        _, err, me = tool(intro, tok_intro, "who_am_i")
        check("9", "introspection mode (the Authelia shape) admits the same login",
              not err and me.get("subject") == "gudrun" and issuer.calls["introspect"] >= 1, f"{me}")
        before = issuer.calls["userinfo"]
        for _ in range(5):
            tool(ro, tok_writer, "who_am_i")
        check("10", "a verified identity is cached (no userinfo call for five repeat calls)",
              issuer.calls["userinfo"] == before, f"{before} → {issuer.calls['userinfo']}")
        forged = tok_writer.rsplit(".", 1)[0] + "." + gimle_oauth.b64url_encode(b"\x00" * 256)
        code, _, _ = rpc(ro, forged, "tools/list")
        check("11", "a forged signature is refused", code == 401, f"{code}")
        tok_none = issuer.mint("gimle-mcp", "carys", [], email="carys@example.org")
        _, _, me = tool(ro, tok_none, "who_am_i")
        tok_nothing = issuer.mint("gimle-mcp", "hakon", [])
        _, _, me_n = tool(ro, tok_nothing, "who_am_i")
        check("12", "the local groups file grants by email; no place group means no places",
              me.get("places_granted") == ["Ymir"] and me_n.get("places_granted") == [], f"{me} / {me_n}")
        code, hdr, _ = http("GET", f"http://127.0.0.1:{ro}/.well-known/oauth-authorization-server")
        check("13", "the issuer's metadata is reachable from the door (older-spec clients)", code == 200)
    finally:
        cleanup()
        time.sleep(0.1)
        leftover = [p for k, p in ports.items() if k != "issuer" and port_open(p)]
        try:
            issuer.httpd.shutdown()
        except Exception:  # noqa: BLE001
            pass
        if leftover:
            FAILS.append(f"  leftover servers on ports {leftover}")
            print(f"FAIL  leftover servers on ports {leftover}")
        else:
            print(f"ok    no door left listening (pids {[p.pid for p in CHILDREN]} all exited)")
        if FAILS:
            print("door logs kept in", tmp)
        else:
            import shutil
            shutil.rmtree(tmp, ignore_errors=True)
    print(f"{len(PASSES)} passed, {len(FAILS)} failed")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())

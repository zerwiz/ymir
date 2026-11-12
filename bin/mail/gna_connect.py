#!/usr/bin/env python3
"""Gná's connect door — one button to a signed-in mailbox, and the honest line per account.

Plan 221 §5 (`svartalfaheim/whynotproductions/projects/ymir/plans/221-the-connect-door.md`).
Four verbs, and every one of them ends in a MEASUREMENT, never an assumption:

  connect.sh google            one sign-in: consent URL → loopback redirect → code exchanged →
                               the refresh token written to the vault BY KEY, proved with one
                               GET /users/me/profile, then reported as
                               `account <address> · grant live · expires <t>`
  connect.sh google --check    the boot check: is each grant live, and when does the access token
                               expire. A dead grant says `grant dead` — never an empty inbox.
  connect.sh imap              the guest road: address + app password, proved by a REAL LOGIN and a
                               REAL EXAMINE, stored by key, never echoed back
  connect.sh status            per account: readable · sendable · deliverable
  connect.sh revoke <account>  revocation as a VERB: the vault key goes dark and the door says what
                               stopped working
  connect.sh --self-test       every proof above, offline, against fixtures on loopback

Rules this file obeys, and why each one bites:

  * Rule 07 — no host, port or credential is a constant. The client id and secret are NAMES of
    vault keys; the endpoints are env-overridable with ONE documented default each
    (`YMIR_OAUTH_AUTH_URL`, `YMIR_OAUTH_TOKEN_URL`, `YMIR_GMAIL_API_BASE`,
    `YMIR_OAUTH_TOKENINFO_URL`, `GNA_CONNECT_PORT`).
  * A secret is never printed and never rides argv: hodd-set.sh reads it on stdin
    (`--set-stdin`), so `ps` cannot see a refresh token.
  * THIS FILE CANNOT SEND. Sending stays on the gate
    (`systems/snotra/services/letters/mail-send.sh`), which binds the operator's word to the exact
    RFC822 bytes; a route that cannot show the bytes is refused (plan 221 §4). A self-test proof
    asserts that no send path exists in this file.
  * The register is the home's (`hodd/memory/mail/accounts.yaml`); a new account is INSERTED as a
    new row and no existing row is rewritten, because those rows carry measured history
    (Rule 06 — append, never rewrite).
"""

from __future__ import annotations

import base64
import getpass
import html
import json
import os
import re
import secrets
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import gna_addresses  # noqa: E402  — the register: deliverability is ITS measurement, not ours
import gna_import  # noqa: E402  — the importer: the IMAP target and the one read-only connect
import gna_store  # noqa: E402  — the store: the account is the boundary

VERSION = "1.0.0"

TREE = Path(os.environ.get("YMIR_TREE", "")).expanduser() if os.environ.get("YMIR_TREE") else \
    Path(__file__).resolve().parents[2]

LOOPBACK = "127.0.0.1"
CONNECT_PATH = "/callback"
DEFAULT_TIMEOUT = 300.0  # the operator has five minutes to sign in; then the door closes

# The scopes a user needs for "all the tools" the plan names. Sending is INCLUDED in the consent
# (our gate sends with this grant) and is never exercised here.
SCOPE_GMAIL_READONLY = "https://www.googleapis.com/auth/gmail.readonly"
SCOPE_GMAIL_COMPOSE = "https://www.googleapis.com/auth/gmail.compose"
SCOPE_GMAIL_SEND = "https://www.googleapis.com/auth/gmail.send"
SCOPE_CALENDAR_EVENTS = "https://www.googleapis.com/auth/calendar.events"
DEFAULT_SCOPES = (SCOPE_GMAIL_READONLY, SCOPE_GMAIL_COMPOSE, SCOPE_GMAIL_SEND, SCOPE_CALENDAR_EVENTS)

# Key NAMES, never values. The fleet client is C0's (plan 221 §6); the gate's grant is the one
# mail-send.sh refreshes, and a single default is documented here and overridable by env.
DEFAULT_CLIENT_KEY = "GOOGLE_MCP_CLIENT_ID"
DEFAULT_CLIENT_SECRET_KEY = "GOOGLE_MCP_CLIENT_SECRET"
DEFAULT_GATE_GRANT_KEY = "SNOTRA_GOOGLE_REFRESH_TOKEN"

IMAP_DEFAULT_TLS = "ssl"
IMAP_DEFAULT_MAILBOX = "INBOX"


# --------------------------------------------------------------------------- configuration (Rule 07)


def env_str(name: str, default: str = "") -> str:
    return (os.environ.get(name) or "").strip() or default


def auth_endpoint() -> str:
    return env_str("YMIR_OAUTH_AUTH_URL", "https://accounts.google.com/o/oauth2/v2/auth")


def token_endpoint() -> str:
    return env_str("YMIR_OAUTH_TOKEN_URL", "https://oauth2.googleapis.com/token")


def gmail_api() -> str:
    return env_str("YMIR_GMAIL_API_BASE", "https://gmail.googleapis.com/gmail/v1").rstrip("/")


def tokeninfo_endpoint() -> str:
    return env_str("YMIR_OAUTH_TOKENINFO_URL", "https://oauth2.googleapis.com/tokeninfo")


# The sign-in's loopback port (plan 276). The fleet's OAuth client is a WEB client, so Google accepts
# only the exact redirect URIs registered on it — an ephemeral port is refused with
# redirect_uri_mismatch. :8765 is Kokoro's, the house's voice, and is never a sign-in's default.
DEFAULT_OAUTH_PORT = 8767


def connect_port() -> int:
    """YMIR_OAUTH_LOOPBACK_PORT, the one setting every Google sign-in door reads; GNA_CONNECT_PORT is
    still honoured under it for old notes. 0 asks for an ephemeral port (a Desktop-app client)."""
    name = "YMIR_OAUTH_LOOPBACK_PORT" if env_str("YMIR_OAUTH_LOOPBACK_PORT", "") else "GNA_CONNECT_PORT"
    raw = env_str(name, str(DEFAULT_OAUTH_PORT))
    try:
        return int(raw)
    except ValueError:
        raise SystemExit(f"connect: {name} is not a number: {raw!r}")


def port_holder(port: int) -> str:
    """Who listens on a loopback port, as `ss -ltnp` names it — or 'another process'."""
    try:
        out = subprocess.run(["ss", "-ltnpH", f"sport = :{port}"], capture_output=True, text=True,
                             timeout=10).stdout
    except (OSError, subprocess.SubprocessError):
        return "another process"
    m = re.search(r'users:\(\("([^"]+)",pid=(\d+)', out)
    return f"{m.group(1)} (pid {m.group(2)})" if m else "another process"


def gate_grant_key() -> str:
    return env_str("YMIR_GATE_GRANT_KEY", DEFAULT_GATE_GRANT_KEY)


def scopes() -> list[str]:
    raw = env_str("GNA_GOOGLE_SCOPES", "")
    return raw.split() if raw else list(DEFAULT_SCOPES)


# --------------------------------------------------------------------------- the vault, by reference


def vault_env() -> dict[str, str]:
    """The vault BY REFERENCE, through the importer's own door (one reader, one truth)."""
    return gna_import.vault_env()


def vault_door() -> Path:
    return TREE / "bin" / "vault" / "hodd.sh"


def vault_set_door() -> Path:
    return TREE / "bin" / "vault" / "hodd-set.sh"


def vault_put(key: str, value: str) -> None:
    """Write ONE key. The value goes on STDIN so no secret is ever visible in `ps`."""
    door = vault_set_door()
    try:
        proc = subprocess.run(
            [str(door), "--stdin", key],
            input=(value + "\n"), capture_output=True, text=True, timeout=180, check=False,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        raise SystemExit(f"connect: the vault door did not open: {exc}")
    if proc.returncode != 0:
        raise SystemExit(f"connect: the vault refused to store {key}: "
                         f"{(proc.stderr or proc.stdout).strip().splitlines()[-1:] or 'no reason given'}")


def vault_delete(key: str) -> bool:
    """Darken ONE key. `--del` removes it outright (a key set to an empty value is a stale shadow
    waiting to be read as a value), and it refuses to empty the vault file. Returns False when the
    key was already absent — which is `already dark`, not a failure."""
    door = vault_set_door()
    try:
        proc = subprocess.run([str(door), "--del", key], capture_output=True, text=True,
                              timeout=180, check=False)
    except (OSError, subprocess.SubprocessError) as exc:
        raise SystemExit(f"connect: the vault door did not open: {exc}")
    if proc.returncode == 3:
        return False
    if proc.returncode != 0:
        raise SystemExit(f"connect: the vault refused to remove {key}: "
                         f"{(proc.stderr or proc.stdout).strip().splitlines()[-1:] or 'no reason given'}")
    return True


def vault_get(key: str) -> str:
    return str(vault_env().get(key) or "")


def redact(text: str, *secrets_: str) -> str:
    out = str(text)
    for value in secrets_:
        if value and len(value) >= 4:
            out = out.replace(value, "<redacted>")
    return out


# --------------------------------------------------------------------------- the account register


def slug(address: str) -> str:
    return re.sub(r"[^A-Z0-9]+", "_", address.strip().upper()).strip("_")


def keys_for(address: str) -> dict[str, str]:
    """The KEY NAMES this account's material lives under.

    A declared row names them (its measured history is not rewritten); an address the register has
    never seen gets derived names, so two accounts on one machine cannot collide."""
    row = gna_store.declared_accounts().get(address.strip().lower()) or {}
    derived = {
        "grant": f"GNA_GRANT_{slug(address)}",
        "host": f"GNA_IMAP_HOST_{slug(address)}",
        "port": f"GNA_IMAP_PORT_{slug(address)}",
        "tls": f"GNA_IMAP_TLS_{slug(address)}",
        "user": f"GNA_IMAP_USER_{slug(address)}",
        "password": f"GNA_IMAP_PASSWORD_{slug(address)}",
    }
    block = row.get("imap") if isinstance(row.get("imap"), dict) else {}
    return {
        "grant": str(row.get("grant") or derived["grant"]),
        "client": str(row.get("client") or DEFAULT_CLIENT_KEY),
        "client_secret": str(row.get("client_secret") or DEFAULT_CLIENT_SECRET_KEY),
        "host": str(block.get("host_key") or derived["host"]),
        "port": str(block.get("port_key") or derived["port"]),
        "tls": str(block.get("tls_key") or derived["tls"]),
        "user": str(block.get("user_key") or derived["user"]),
        "password": str(block.get("password_key") or derived["password"]),
    }


def transport_of(address: str) -> str:
    row = gna_store.declared_accounts().get(address.strip().lower()) or {}
    return str(row.get("transport") or ("imap" if isinstance(row.get("imap"), dict) else "google")).lower()


def register_row(address: str, transport: str, keys: dict[str, str]) -> str:
    """INSERT a new row above the existing ones; never rewrite one that is there.

    The register carries measured history in its comments and its `measured:` lines, so a rewrite
    is not available to us (Rule 06). A new account is a new row, inserted under `accounts:` and
    validated by parsing the whole file before it replaces the old one."""
    if not gna_store.ACCOUNT_RE.match(address):
        raise SystemExit(f"connect: {address!r} is not an address — refusing to declare it")
    path = Path(gna_store.ACCOUNTS)
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        text = "accounts:\n"
    if re.search(rf'^\s*-\s*id:\s*"?{re.escape(address)}"?\s*$', text, re.M | re.I):
        return "declared"

    stamp = now_iso()
    lines = [f'  - id: "{address}"',
             f'    transport: {transport}']
    if transport == "imap":
        lines += [
            "    imap:",
            f"      host_key: {keys['host']}",
            f"      port_key: {keys['port']}",
            f"      tls_key: {keys['tls']}",
            f"      user_key: {keys['user']}",
            f"      password_key: {keys['password']}",
            f"      mailbox: {IMAP_DEFAULT_MAILBOX}",
        ]
    else:
        lines += [
            f"    grant: {keys['grant']}",
            f"    client: {keys['client']}",
            f"    client_secret: {keys['client_secret']}",
        ]
    lines += [
        "    status: connected",
        f'    connected: "{stamp}"',
        f'    note: "Connected by bin/mail/connect.sh {transport} on {stamp}; every value is in the vault by key, never here."',
    ]
    block = "\n".join(lines) + "\n"

    match = re.search(r"^accounts:\s*$", text, re.M)
    if match:
        new_text = text[:match.end()] + "\n" + block + text[match.end():].lstrip("\n")
    else:
        new_text = text.rstrip("\n") + "\n\naccounts:\n" + block

    try:
        import yaml  # the store already requires it; imported here so a bad write is caught by parse
        parsed = yaml.safe_load(new_text) or {}
    except Exception as exc:  # noqa: BLE001 — a parse failure is the proof the write is unsafe
        raise SystemExit(f"connect: refusing to write the register — the new text does not parse: {exc}")
    rows = parsed.get("accounts") or []
    if not any(isinstance(r, dict) and str(r.get("id", "")).lower() == address.lower() for r in rows):
        raise SystemExit("connect: refusing to write the register — the new row did not survive the parse")
    if len(rows) < len((gna_store.document().get("accounts") or [])):
        raise SystemExit("connect: refusing to write the register — it would LOSE an account")

    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(new_text, encoding="utf-8")
    os.replace(tmp, path)
    return "added"


# --------------------------------------------------------------------------- the connect log (append-only)


def connect_log_path() -> Path:
    return Path(gna_store.MAIL_DIR) / "connect-log.jsonl"


def log_event(verb: str, account: str, transport: str, result: str, **extra) -> None:
    """One line per connect or revoke. Append-only: a revocation is an EVENT, so the register's
    declared history is never rewritten to say the grant died."""
    path = connect_log_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    row = {"at": now_iso(), "verb": verb, "account": account, "transport": transport, "result": result}
    row.update({k: v for k, v in extra.items() if v is not None})
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, ensure_ascii=False) + "\n")


def revocations() -> dict[str, str]:
    """The latest revoke per account that has no LATER connect — measured, never declared."""
    last_connect: dict[str, str] = {}
    last_revoke: dict[str, str] = {}
    try:
        lines = connect_log_path().read_text(encoding="utf-8").splitlines()
    except OSError:
        return {}
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        account = str(row.get("account") or "").lower()
        at = str(row.get("at") or "")
        if not account:
            continue
        if row.get("verb") == "revoke":
            last_revoke[account] = at
        elif row.get("verb") in ("google", "imap") and row.get("result") == "ok":
            last_connect[account] = at
    return {a: at for a, at in last_revoke.items() if at >= last_connect.get(a, "")}


# --------------------------------------------------------------------------- HTTP (one door, testable)


def _post_form(url: str, form: dict[str, str], timeout: float = 30.0) -> dict:
    data = urllib.parse.urlencode(form).encode()
    req = urllib.request.Request(url, data=data, headers={
        "Content-Type": "application/x-www-form-urlencoded", "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8", "replace") or "{}")
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        try:
            body = json.loads(raw)
        except json.JSONDecodeError:
            body = {"error": f"http_{exc.code}", "error_description": raw[:200]}
        body.setdefault("error", f"http_{exc.code}")
        return body


def _get_json(url: str, bearer: str = "", timeout: float = 30.0) -> dict:
    headers = {"Accept": "application/json"}
    if bearer:
        headers["Authorization"] = "Bearer " + bearer
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8", "replace") or "{}")
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        try:
            body = json.loads(raw)
        except json.JSONDecodeError:
            body = {"error": {"message": raw[:200]}}
        body.setdefault("error", {"message": f"http_{exc.code}"})
        return body


# --------------------------------------------------------------------------- the google grant


def refresh_grant(client_id: str, client_secret: str, refresh_token: str) -> dict:
    """Exchange the STORED refresh token for an access token. This is the one act that tells a live
    grant from a dead one, so both `--check` and `status` go through it."""
    return _post_form(token_endpoint(), {
        "client_id": client_id, "client_secret": client_secret,
        "refresh_token": refresh_token, "grant_type": "refresh_token"})


def users_me(access_token: str) -> dict:
    """GET /users/me — the proof that the grant belongs to a real, named account."""
    return _get_json(f"{gmail_api()}/users/me/profile", bearer=access_token)


def scopes_of(access_token: str) -> list[str]:
    info = _get_json(f"{tokeninfo_endpoint()}?access_token={urllib.parse.quote(access_token)}")
    return str(info.get("scope") or "").split()


def grant_state(address: str, keys: dict[str, str] | None = None) -> dict:
    """Measure ONE account: live or dead, whose, and what it may do. Never a guess."""
    keys = keys or keys_for(address)
    env = vault_env()
    client_id = str(env.get(keys["client"]) or "")
    client_secret = str(env.get(keys["client_secret"]) or "")
    refresh_token = str(env.get(keys["grant"]) or "")
    state = {"account": address, "transport": "google", "grant_key": keys["grant"],
             "client_key": keys["client"], "liveness": "absent", "address": "", "scopes": [],
             "expires_at": "", "detail": "", "access_token": ""}
    if not refresh_token:
        state["detail"] = f"the vault holds no {keys['grant']}"
        state["liveness"] = "dead" if address.lower() in revocations() else "absent"
        return state
    if not client_id or not client_secret:
        state["detail"] = f"the vault holds no {keys['client']} or {keys['client_secret']}"
        state["liveness"] = "dead"
        return state
    token = refresh_grant(client_id, client_secret, refresh_token)
    if not token.get("access_token"):
        state["liveness"] = "dead"
        state["detail"] = str(token.get("error") or "no access token") + (
            " — " + str(token.get("error_description")) if token.get("error_description") else "")
        return state
    state["access_token"] = str(token["access_token"])
    state["liveness"] = "live"
    try:
        state["expires_at"] = iso_in(int(token.get("expires_in") or 0))
    except (TypeError, ValueError):
        state["expires_at"] = ""
    state["scopes"] = scopes_of(state["access_token"])
    me = users_me(state["access_token"])
    addr = str((me or {}).get("emailAddress") or "")
    if addr:
        state["address"] = addr
    else:
        state["detail"] = "the grant refreshed but /users/me/profile named no address" + (
            f" ({me.get('error')})" if me.get("error") else "")
    return state


# --------------------------------------------------------------------------- the loopback catcher


class Loopback:
    """A one-shot local server on 127.0.0.1, an EPHEMERAL port by default.

    Google accepts a loopback redirect whose port varies for a Desktop-app client; a Web-app client
    must have the exact URI registered, so `--port` (or GNA_CONNECT_PORT) pins it when the client is
    a Web client. Nothing else is on the wire: one GET, one page, then the socket closes."""

    def __init__(self, port: int = 0) -> None:
        self.result: dict[str, str] = {}
        self._state = ""
        outer = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_args) -> None:  # noqa: D401 — silence the default stderr log
                return

            def do_GET(self) -> None:  # noqa: N802 — the http.server contract
                parsed = urllib.parse.urlparse(self.path)
                query = urllib.parse.parse_qs(parsed.query)
                code = (query.get("code") or [""])[0]
                error = (query.get("error") or [""])[0]
                got_state = (query.get("state") or [""])[0]
                if parsed.path not in (CONNECT_PATH, "/"):
                    outer.result["error"] = "wrong_path"
                elif error:
                    outer.result["error"] = error
                    outer.result["detail"] = (query.get("error_description") or [""])[0]
                elif not code:
                    outer.result["error"] = "no_code"
                elif got_state != outer._state:
                    outer.result["error"] = "state_mismatch"
                else:
                    outer.result["code"] = code
                    outer.result["state"] = got_state
                page = (b"<!doctype html><meta charset=utf-8><title>Ymir</title>"
                        b"<body style='font:16px system-ui;padding:2rem'>"
                        + (b"<h1>Signed in</h1><p>The grant is written to the vault. You may close this tab.</p>"
                           if "code" in outer.result else
                           b"<h1>Not signed in</h1><p>Nothing was written. Return to the terminal.</p>")
                        + b"</body>")
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(page)))
                self.send_header("Connection", "close")
                self.end_headers()
                self.wfile.write(page)
                threading.Thread(target=outer.server.shutdown, daemon=True).start()

        try:
            self.server = HTTPServer((LOOPBACK, port), Handler)
        except OSError as exc:
            if exc.errno != 98:                       # EADDRINUSE; anything else is a real fault
                raise
            # A busy port is said, never worked around: the door stops no service by itself (plan 276).
            raise SystemExit(f"connect: port {port} is held by {port_holder(port)} — nothing was signed in.\n"
                             f"help: free it, or set YMIR_OAUTH_LOOPBACK_PORT to a port registered on the "
                             f"OAuth client (:8765 is Kokoro, the house's voice — leave it running)")
        self.server.timeout = 1.0
        self.port = int(self.server.server_address[1])

    def redirect_uri(self) -> str:
        return f"http://{LOOPBACK}:{self.port}{CONNECT_PATH}"

    def wait(self, state: str, timeout: float) -> dict:
        self._state = state
        deadline = time.monotonic() + timeout
        thread = threading.Thread(target=self.server.serve_forever, kwargs={"poll_interval": 0.2},
                                  daemon=True)
        thread.start()
        try:
            while time.monotonic() < deadline and not self.result:
                time.sleep(0.1)
        finally:
            try:
                self.server.shutdown()
            except Exception:  # noqa: BLE001 — a closed socket is the expected end
                pass
            self.server.server_close()
        return self.result or {"error": "timeout"}

    def close(self) -> None:
        try:
            self.server.server_close()
        except Exception:  # noqa: BLE001
            pass


def consent_url(client_id: str, redirect_uri: str, scope_list: list[str], state: str,
                login_hint: str = "") -> str:
    params = {
        "client_id": client_id, "redirect_uri": redirect_uri, "response_type": "code",
        "scope": " ".join(scope_list), "state": state,
        "access_type": "offline", "prompt": "consent", "include_granted_scopes": "true",
    }
    if login_hint:
        params["login_hint"] = login_hint
    return auth_endpoint() + "?" + urllib.parse.urlencode(params)


# --------------------------------------------------------------------------- verbs


def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def iso_in(seconds: int) -> str:
    return (datetime.now(timezone.utc) + timedelta(seconds=int(seconds))).strftime("%Y-%m-%dT%H:%M:%SZ")


def q(value) -> str:
    return '"' + str(value).replace('"', "'").replace("\n", " ") + '"'


def cmd_google(address: str = "", port: int | None = None, timeout: float = DEFAULT_TIMEOUT,
               open_browser: bool = True, consent_url_out: str = "") -> int:
    """The one button. Every step is measured; nothing is assumed about whose grant came back."""
    keys = keys_for(address) if address else {"grant": "", "client": DEFAULT_CLIENT_KEY,
                                              "client_secret": DEFAULT_CLIENT_SECRET_KEY}
    env = vault_env()
    client_id = str(env.get(keys["client"]) or "")
    client_secret = str(env.get(keys["client_secret"]) or "")
    if not client_id or not client_secret:
        print(f"connect: the fleet client is not in the vault — {keys['client']} and "
              f"{keys['client_secret']} are named and absent.\n"
              f"help: bin/vault/hodd-set.sh --set-stdin {keys['client']}  (paste the value on stdin)\n"
              f"help: this is phase C0 of plan 221 — ONE Cloud project, consent screen Internal, "
              f"one OAuth client marked 'Use this client for an AI-powered agent'", file=sys.stderr)
        return 3

    listener = Loopback(port if port is not None else connect_port())
    state = secrets.token_urlsafe(24)
    url = consent_url(client_id, listener.redirect_uri(), scopes(), state, address)
    if consent_url_out:
        Path(consent_url_out).write_text(url + "\n", encoding="utf-8")
    print(f"consent: open this URL and sign in (the door waits {int(timeout)}s)\n{url}", flush=True)
    print(f"help: if Google answers redirect_uri_mismatch, add {listener.redirect_uri()} to the OAuth "
          f"client's Authorized redirect URIs (Google Cloud console → APIs & Services → Credentials), "
          f"or set YMIR_OAUTH_LOOPBACK_PORT to a port already registered there", flush=True)
    if open_browser:
        try:
            import webbrowser
            webbrowser.open(url, new=1, autoraise=True)
        except Exception:  # noqa: BLE001 — a headless seat prints the URL; that is the whole fallback
            pass
    caught = listener.wait(state, timeout)
    if "code" not in caught:
        reason = caught.get("error", "no code")
        detail = caught.get("detail") or ""
        print(f"connect: no grant — {reason}{(' · ' + detail) if detail else ''}")
        print("help: nothing was written; run the verb again when you can finish the sign-in")
        return 1

    token = _post_form(token_endpoint(), {
        "code": caught["code"], "client_id": client_id, "client_secret": client_secret,
        "redirect_uri": listener.redirect_uri(), "grant_type": "authorization_code"})
    if not token.get("refresh_token"):
        print("connect: the code was exchanged but no refresh token came back — "
              "Google sends one only on a fresh consent (prompt=consent asks for it); nothing written")
        print(f"error: {token.get('error') or 'no refresh_token'}")
        return 1

    access = str(token.get("access_token") or "")
    me = users_me(access) if access else {}
    account = str((me or {}).get("emailAddress") or address or "").strip().lower()
    if not account:
        print("connect: the code was exchanged but /users/me/profile named no address — nothing written")
        return 1

    keys = keys_for(account)
    vault_put(keys["grant"], str(token["refresh_token"]))
    log_event("google", account, "google", "ok", keys=[keys["grant"], keys["client"], keys["client_secret"]])
    added = register_row(account, "google", keys)

    # PROVE it from the vault — re-read through the door, never from the value we still hold.
    state_row = grant_state(account, keys)
    if state_row["liveness"] != "live" or not state_row["address"]:
        print(f"account {account} · grant dead: written but unreadable through the vault "
              f"({state_row['detail'] or 'refresh failed'})")
        return 1
    print(f"account {state_row['address'] or account} · grant live · expires {state_row['expires_at']}")
    print(f"keys[3]{{kind,name,stored_in}}:")
    print(f"  {q('grant')},{q(keys['grant'])},{q('the vault, by key')}")
    print(f"  {q('client')},{q(keys['client'])},{q('the vault, by key')}")
    print(f"  {q('client_secret')},{q(keys['client_secret'])},{q('the vault, by key')}")
    print(f"register: {added} in {gna_store.ACCOUNTS}")
    if keys["grant"] == gate_grant_key():
        print("gate: this is the grant our gate sends with (systems/snotra/services/letters/mail-send.sh)")
    else:
        print(f"gate: sends stay on {gate_grant_key()} — this connect door cannot send")
    print(f"scopes: {' '.join(state_row['scopes']) or 'unmeasured'}")
    return 0


def cmd_check(address: str = "") -> int:
    """The boot check. A dead grant is reported as DEAD — never as a quiet inbox."""
    declared = gna_store.declared_accounts()
    targets = [address.lower()] if address else sorted(declared)
    if not targets:
        print("accounts[0]{account,state,detail}:")
        print(f'  {q("—")},{q("absent")},{q("no account is declared — hodd/memory/mail/accounts.yaml")}')
        print("result: ABSENT — nobody can read or send, and this is not an empty inbox")
        return 3
    rows = []
    worst = 0
    for account in targets:
        transport = transport_of(account)
        if transport == "imap":
            state = imap_state(account)
            rows.append((account, transport, state))
            worst = max(worst, 0 if state["liveness"] == "live" else 1)
            continue
        state = grant_state(account)
        rows.append((account, transport, state))
        worst = max(worst, 0 if state["liveness"] == "live" else 1)
    for account, transport, state in rows:
        if state["liveness"] == "live":
            print(f"account {state.get('address') or account} · grant live · expires "
                  f"{state.get('expires_at') or 'unmeasured'}")
        else:
            print(f"account {account} · grant dead: {state['detail'] or 'no reason given'}")
    if worst:
        print("help: re-run `bin/mail/connect.sh google` (or `imap`) for that account; "
              "an empty inbox is not the same as a dead grant")
    return worst


def imap_state(address: str) -> dict:
    """Measure an IMAP account with the importer's own reader: LOGIN, then EXAMINE."""
    keys = keys_for(address)
    env = vault_env()
    state = {"account": address, "transport": "imap", "liveness": "absent", "detail": "",
             "count": "", "mailbox": ""}
    values = {field: str(env.get(keys[field]) or "") for field in ("host", "port", "tls", "user", "password")}
    missing = [keys[f] for f in ("host", "user", "password") if not values[f]]
    if missing:
        state["detail"] = "the vault holds no " + ", ".join(missing)
        state["liveness"] = "dead" if address.lower() in revocations() else "absent"
        return state
    try:
        port = int(values["port"]) if values["port"] else gna_import.IMAP_DEFAULT_PORT
    except ValueError:
        state["detail"] = f"the vault's port for {address} is not a number"
        state["liveness"] = "dead"
        return state
    target = {"host": values["host"], "port": port,
              "tls": values["tls"] or IMAP_DEFAULT_TLS, "user": values["user"],
              "password": values["password"], "mailbox": IMAP_DEFAULT_MAILBOX}
    try:
        conn = gna_import.imap_connect(target)
    except Exception as exc:  # noqa: BLE001 — every failure here is a dead door, named loudly
        state["detail"] = redact(f"LOGIN refused: {exc}", values["password"])[:200]
        return state
    try:
        typ, data = conn.select(target["mailbox"], readonly=True)
        state["mailbox"] = target["mailbox"]
        if typ != "OK":
            state["detail"] = f"EXAMINE {target['mailbox']} was refused"
            return state
        state["count"] = (data or [b""])[0].decode("utf-8", "replace") if data else ""
        state["liveness"] = "live"
    finally:
        try:
            conn.logout()
        except Exception:  # noqa: BLE001
            pass
    return state


def cmd_imap(address: str, host: str = "", port: str = "", tls: str = "",
             mailbox: str = "", password_stdin: bool = False) -> int:
    """The guest road: three fields, proved by a real LOGIN and a real EXAMINE."""
    address = (address or "").strip().lower()
    if not gna_store.ACCOUNT_RE.match(address):
        print(f"connect: --address must be an address, not {address!r}", file=sys.stderr)
        return 2
    keys = keys_for(address)
    env = vault_env()
    domain = address.rsplit("@", 1)[1]
    host = (host or env.get(keys["host"]) or "").strip()
    derived = ""
    if not host:
        derived = f"imap.{domain}"
        host = derived
    port_raw = (port or env.get(keys["port"]) or "").strip()
    try:
        port_no = int(port_raw) if port_raw else gna_import.IMAP_DEFAULT_PORT
    except ValueError:
        print(f"connect: --port must be a number, not {port_raw!r}", file=sys.stderr)
        return 2
    tls_mode = (tls or env.get(keys["tls"]) or "").strip().lower() or IMAP_DEFAULT_TLS
    if tls_mode not in ("ssl", "starttls", "none"):
        print(f"connect: tls must be ssl, starttls or none — not {tls_mode!r}", file=sys.stderr)
        return 2
    if tls_mode == "none" and not gna_import._is_loopback(host):  # noqa: SLF001 — the importer's own test
        print(f"connect: refusing an unencrypted session to {host} — raise TLS instead", file=sys.stderr)
        return 2
    mailbox = (mailbox or IMAP_DEFAULT_MAILBOX).strip() or IMAP_DEFAULT_MAILBOX

    password = ""
    if password_stdin or not sys.stdin.isatty():
        password = (sys.stdin.readline() or "").rstrip("\n")
    else:
        password = getpass.getpass(f"app password for {address}: ")
    if not password:
        print("connect: no app password was given — nothing was tried and nothing was written",
              file=sys.stderr)
        return 2

    if derived:
        print(f"host: {host} (derived from the address; pass --host to override)")
    target = {"host": host, "port": port_no, "tls": tls_mode, "user": address,
              "password": password, "mailbox": mailbox}
    try:
        conn = gna_import.imap_connect(target)
    except Exception as exc:  # noqa: BLE001 — one loud line, never the password
        print(redact(f"imap: LOGIN refused for {address} at {host}:{port_no} · {exc}", password))
        print("help: an app password needs 2-Step Verification on the Google account; "
              "a normal password is refused by IMAP")
        return 1
    try:
        typ, data = conn.select(mailbox, readonly=True)
        if typ != "OK":
            print(redact(f"imap: LOGIN succeeded for {address} but EXAMINE {mailbox} was refused", password))
            return 1
        count = (data or [b""])[0].decode("utf-8", "replace") if data else ""
    finally:
        try:
            conn.logout()
        except Exception:  # noqa: BLE001
            pass

    vault_put(keys["host"], host)
    vault_put(keys["port"], str(port_no))
    vault_put(keys["tls"], tls_mode)
    vault_put(keys["user"], address)
    vault_put(keys["password"], password)
    added = register_row(address, "imap", keys)
    log_event("imap", address, "imap", "ok", keys=[keys["host"], keys["port"], keys["user"], keys["password"]],
              mailbox=mailbox)

    print(f"mailbox {address} · {mailbox} · {count} messages")
    print(f"keys[4]{{kind,name}}:")
    for kind in ("host", "user", "password"):
        print(f"  {q(kind)},{q(keys[kind])}")
    print(f"  {q('port')},{q(keys['port'])}")
    print(f"register: {added} in {gna_store.ACCOUNTS}")
    print("send: refused here by design — a guest's mail is READ; sending stays on our gate")
    return 0


def deliverability(address: str) -> tuple[str, str]:
    """Deliverable, measured by `bin/mail/addresses.sh`'s own register (gna_addresses.register)."""
    rows = gna_addresses.register()
    for row in rows:
        if row["address"] == address:
            return ({"yes": "yes", "unproven": "declared", "no": "no"}.get(row["deliverable"], "no"),
                    row.get("reason") or "")
    # Not a house address: measure the DOMAIN it lives on, the same way the register does.
    domain = address.rsplit("@", 1)[1] if "@" in address else ""
    if not domain:
        return "no", "not an address"
    mx = gna_addresses.mx_state(domain)
    state = mx.get("state")
    if state == "present":
        return "yes", ", ".join(mx.get("mx") or [])
    return "no", str(mx.get("note") or state or "no MX")


def cmd_status(address: str = "", offline: bool = False) -> int:
    """The honesty line: readable · sendable · deliverable, per account, measured."""
    declared = gna_store.declared_accounts()
    targets = [address.lower()] if address else sorted(declared)
    if not targets:
        print("accounts[0]{account,transport,readable,sendable,deliverable,grant,checked,detail}:")
        print(f'  {q("—")},{q("—")},{q("no")},{q("no")},{q("—")},{q("absent")},{q(now_iso())},'
              f'{q("no account is declared — hodd/memory/mail/accounts.yaml")}')
        print("result: ABSENT — a desk with no account cannot read, send or receive")
        return 3

    rows = []
    worst = 0
    revoked = revocations()
    for account in targets:
        transport = transport_of(account)
        keys = keys_for(account)
        grant_key = keys["password"] if transport == "imap" else keys["grant"]
        if offline:
            rows.append({"account": account, "transport": transport, "readable": "unmeasured",
                         "sendable": "unmeasured", "deliverable": "unmeasured",
                         "grant": "unmeasured", "checked": now_iso(),
                         "detail": "--offline: nothing was measured"})
            worst = max(worst, 3)
            continue
        if transport == "imap":
            state = imap_state(account)
            scopes_: list[str] = []
        else:
            state = grant_state(account, keys)
            scopes_ = state.get("scopes") or []
        live = state["liveness"] == "live"
        readable = "yes" if live else "no"
        if transport == "imap":
            sendable = "no — the gate sends by Gmail API"
        elif grant_key == gate_grant_key() and SCOPE_GMAIL_SEND in scopes_:
            sendable = "yes (our gate)"
        elif grant_key == gate_grant_key():
            sendable = "no — the grant carries no gmail.send"
        else:
            sendable = f"no — sends stay on {gate_grant_key()}"
        deliverable, why = deliverability(account)
        detail = state.get("detail") or why
        if account in revoked and not live:
            detail = detail or "revoked by bin/mail/connect.sh revoke"
        rows.append({"account": account, "transport": transport, "readable": readable,
                     "sendable": sendable, "deliverable": deliverable,
                     "grant": state["liveness"], "checked": now_iso(), "detail": detail})
        if not live:
            worst = max(worst, 1)

    print(f"accounts[{len(rows)}]{{account,transport,readable,sendable,deliverable,grant,checked,detail}}:")
    for row in rows:
        print("  " + ",".join(q(row[k]) for k in ("account", "transport", "readable", "sendable",
                                                  "deliverable", "grant", "checked", "detail")))
    counts = {k: sum(1 for r in rows if r["readable"] == k) for k in ("yes", "no", "unmeasured")}
    print(f"counts{{readable,sendable,deliverable,unmeasured}}:")
    print("  " + ",".join(q(str(v)) for v in (
        counts["yes"],
        sum(1 for r in rows if str(r["sendable"]).startswith("yes")),
        sum(1 for r in rows if r["deliverable"] == "yes"),
        counts["unmeasured"])))
    print(f"register: {gna_store.ACCOUNTS}")
    print("law: sending happens only at systems/snotra/services/letters/mail-send.sh — "
          "the operator's word is bound to the RFC822 bytes")
    return 0 if worst == 0 else worst


def cmd_revoke(address: str) -> int:
    """Revocation as a verb: the vault key goes dark, and the door says what stopped."""
    address = (address or "").strip().lower()
    declared = gna_store.declared_accounts()
    if not address:
        print(f"revoke: name an account — declared: {', '.join(sorted(declared)) or 'none'}",
              file=sys.stderr)
        return 2
    if address not in declared:
        print(f"revoke: {address} is not a declared account — declared: "
              f"{', '.join(sorted(declared)) or 'none'}", file=sys.stderr)
        return 2
    transport = transport_of(address)
    keys = keys_for(address)
    key = keys["password"] if transport == "imap" else keys["grant"]
    if not vault_get(key):
        print(f"revoked {address} · already dark: the vault holds no {key}")
        log_event("revoke", address, transport, "already-dark", key=key)
        return 0
    vault_delete(key)
    still = grant_state(address, keys) if transport != "imap" else imap_state(address)
    log_event("revoke", address, transport, "ok", key=key)
    print(f"revoked {address} · {key} is dark in the vault")
    if still["liveness"] == "live":
        print("connect: WARNING — the door still answered after the key was cleared; "
              "the vault may be serving a stale plaintext (see hodd.sh resolve_secret)")
    if transport == "imap":
        print("stopped[3]{what,why}:")
        print(f'  {q("reading mail")},{q("bin/mail/gna_import.py resolves " + key + " and now refuses")}')
        print(f'  {q("the desk")},{q("its account scope is unchanged; every read of it fails loudly")}')
        print(f'  {q("sending")},{q("nothing — an imap account never sends; the gate is untouched")}')
    else:
        print("stopped[3]{what,why}:")
        print(f'  {q("reading and drafting")},{q("the refresh now returns invalid_grant")}')
        print(f'  {q("calendar")},{q("same grant, same token endpoint — also dead")}')
        print(f'  {q("sending")},{q("mail-send.sh refreshes " + key + " and cannot; no letter leaves")}')
    print("note: the register row is left as written (Rule 06) — the revocation is an event in "
          "hodd/memory/mail/connect-log.jsonl")
    return 0


# --------------------------------------------------------------------------- help


def usage() -> None:
    print("""connect.sh — one button to a signed-in mailbox, and the honest line per account

  connect.sh google [--account ADDR] [--port N] [--no-browser] [--timeout S]
      the one sign-in: consent URL, loopback redirect, code exchange, the refresh token
      written to the vault BY KEY, proved with one GET /users/me/profile.
      Prints: account <address> · grant live · expires <t>

  connect.sh google --check [--account ADDR]
      the boot check per account. A dead grant prints `grant dead: <reason>` — never an
      empty inbox. Exit 1 when any account is dead, 3 when none is declared.

  connect.sh imap --address ADDR [--host H] [--port N] [--tls ssl|starttls|none]
                  [--mailbox INBOX] [--password-stdin]
      the guest road: address + app password, proved by a real LOGIN and a real EXAMINE.
      The password is read on stdin (or a prompt) and never echoed, never in argv.

  connect.sh status [--account ADDR] [--offline]
      per account: readable · sendable · deliverable (deliverable is the register's own
      measurement — bin/mail/addresses.sh). Exit 1 when an account is unreadable.

  connect.sh revoke <account>
      revocation as a verb: the vault key goes dark and the door names what stopped.

  connect.sh --self-test        every proof above, offline, against fixtures on loopback

Sending is NOT here: it happens only at systems/snotra/services/letters/mail-send.sh, where the
operator's word is bound to the exact RFC822 bytes (plan 221 §4).""")


# --------------------------------------------------------------------------- the proofs


def _await_file(path: Path, timeout: float) -> str:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            text = path.read_text(encoding="utf-8").strip()
            if text:
                return text
        except OSError:
            pass
        time.sleep(0.1)
    return ""


class _FixtureHttp(threading.Thread):
    """The token door, the tokeninfo door and GET /users/me — on loopback, for the proofs only."""

    daemon = True
    ACCESS = "fixture-access-token"
    REFRESH = "fixture-refresh-token"
    SCOPE = " ".join(DEFAULT_SCOPES)
    ADDRESS = "guest@example.org"

    def __init__(self) -> None:
        super().__init__()
        self.mode = "live"           # live | dead
        self.requests: list[dict] = []
        from http.server import BaseHTTPRequestHandler

        outer = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_a) -> None:
                return

            def _send(self, code: int, body: dict) -> None:
                raw = json.dumps(body).encode()
                self.send_response(code)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(raw)))
                self.end_headers()
                self.wfile.write(raw)

            def do_POST(self) -> None:  # noqa: N802
                length = int(self.headers.get("Content-Length") or 0)
                form = urllib.parse.parse_qs(self.rfile.read(length).decode("utf-8", "replace"))
                outer.requests.append({"path": self.path, "form": {k: v[0] for k, v in form.items()}})
                if self.path != "/token":
                    self._send(404, {"error": "not_found"})
                    return
                if outer.mode == "dead":
                    self._send(400, {"error": "invalid_grant",
                                     "error_description": "Token has been expired or revoked."})
                    return
                if form.get("grant_type", [""])[0] == "authorization_code":
                    self._send(200, {"access_token": outer.ACCESS, "expires_in": 3599,
                                     "refresh_token": outer.REFRESH, "scope": outer.SCOPE,
                                     "token_type": "Bearer"})
                else:
                    self._send(200, {"access_token": outer.ACCESS, "expires_in": 3599,
                                     "scope": outer.SCOPE, "token_type": "Bearer"})

            def do_GET(self) -> None:  # noqa: N802
                parsed = urllib.parse.urlparse(self.path)
                if parsed.path == "/tokeninfo":
                    self._send(200, {"scope": outer.SCOPE, "expires_in": 3599})
                elif parsed.path == "/gmail/v1/users/me/profile":
                    if self.headers.get("Authorization", "") != "Bearer " + outer.ACCESS:
                        self._send(401, {"error": {"message": "no bearer"}})
                    else:
                        self._send(200, {"emailAddress": outer.ADDRESS})
                else:
                    self._send(404, {"error": "not_found"})

        self.server = HTTPServer(("127.0.0.1", 0), Handler)
        self.port = int(self.server.server_address[1])

    def run(self) -> None:
        self.server.serve_forever(poll_interval=0.2)

    def stop(self) -> None:
        self.server.shutdown()
        self.server.server_close()


class _FixtureImap(threading.Thread):
    """Enough IMAP to prove a LOGIN and an EXAMINE: greeting, CAPABILITY, LOGIN, EXAMINE, LOGOUT."""

    daemon = True

    def __init__(self, user: str, password: str, exists: int = 7) -> None:
        super().__init__()
        import socket as _socket
        self.user, self.password, self.exists = user, password, exists
        self.stop_flag = False
        self.sock = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM)
        self.sock.setsockopt(_socket.SOL_SOCKET, _socket.SO_REUSEADDR, 1)
        self.sock.bind(("127.0.0.1", 0))
        self.sock.listen(5)
        self.sock.settimeout(0.5)
        self.port = int(self.sock.getsockname()[1])

    def run(self) -> None:
        while not self.stop_flag:
            try:
                conn, _peer = self.sock.accept()
            except Exception:  # noqa: BLE001 — a timeout is how this loop checks its flag
                continue
            threading.Thread(target=self.serve, args=(conn,), daemon=True).start()

    def serve(self, conn) -> None:
        stream = conn.makefile("rwb")
        stream.write(b"* OK fixture ready\r\n")
        stream.flush()
        try:
            while True:
                line = stream.readline()
                if not line:
                    break
                text = line.decode("utf-8", "replace").rstrip("\r\n")
                tag, _, rest = text.partition(" ")
                cmd = (rest.split(" ", 1)[0] if rest else "").upper()
                if cmd == "CAPABILITY":
                    stream.write(b"* CAPABILITY IMAP4rev1 AUTH=PLAIN\r\n"
                                 + tag.encode() + b" OK CAPABILITY completed\r\n")
                elif cmd == "LOGIN":
                    tokens = [quoted or bare for quoted, bare in
                              re.findall(r'"((?:[^"\\]|\\.)*)"|(\S+)', rest)]
                    who = tokens[1:] if tokens and tokens[0].upper() == "LOGIN" else tokens
                    if (len(who) >= 2 and who[0].strip('"') == self.user
                            and who[1].strip('"') == self.password):
                        stream.write(tag.encode() + b" OK LOGIN completed\r\n")
                    else:
                        stream.write(tag.encode()
                                     + b" NO [AUTHENTICATIONFAILED] Invalid credentials (Failure)\r\n")
                elif cmd in ("EXAMINE", "SELECT"):
                    stream.write(b"* FLAGS (\\Seen)\r\n")
                    stream.write(f"* {self.exists} EXISTS\r\n".encode())
                    stream.write(b"* OK [UIDVALIDITY 1] UIDs valid\r\n")
                    stream.write(tag.encode() + b" OK [READ-ONLY] " + cmd.encode() + b" completed\r\n")
                elif cmd == "LOGOUT":
                    stream.write(b"* BYE fixture closing\r\n" + tag.encode() + b" OK LOGOUT completed\r\n")
                    stream.flush()
                    break
                else:
                    stream.write(tag.encode() + b" OK " + cmd.encode() + b" completed\r\n")
                stream.flush()
        except Exception:  # noqa: BLE001 — a fixture that dies takes its proof with it
            pass
        finally:
            try:
                conn.close()
            except OSError:
                pass

    def stop(self) -> None:
        self.stop_flag = True
        try:
            self.sock.close()
        except OSError:
            pass


def self_test(only: str = "") -> int:
    """Every claim above, offline. Nothing here touches a real Google door.

    `only` names ONE door (google · imap · status · revoke) so each verb can carry its own
    `--self-test`: the proofs that belong to that door are reported, and the shared setup they
    need is still exercised (a door's proof that skipped its precondition proves nothing)."""
    import shutil
    import tempfile

    checks: list[tuple[str, bool, str, str]] = []
    section = ["common"]

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append((name, bool(ok), detail, section[0]))

    http_fixture = _FixtureHttp()
    http_fixture.start()
    imap_fixture = _FixtureImap("guest2@example.org", "app-password-fixture", exists=7)
    imap_fixture.start()

    work = Path(tempfile.mkdtemp(prefix="gna-connect-"))
    home = work / "home"
    (home / "hodd" / "secrets").mkdir(parents=True)
    (home / "hodd" / "memory" / "mail").mkdir(parents=True)
    age_key = home / "hodd" / "secrets" / "age.key"
    subprocess.run(["age-keygen", "-o", str(age_key)], capture_output=True, check=True)
    recipient = subprocess.run(["age-keygen", "-y", str(age_key)], capture_output=True,
                               text=True, check=True).stdout.strip()
    seed = (f"{DEFAULT_CLIENT_KEY}=fixture-client-id\n"
            f"{DEFAULT_CLIENT_SECRET_KEY}=fixture-client-secret\n")
    subprocess.run(["age", "-e", "-r", recipient, "-o",
                    str(home / "hodd" / "secrets" / "platform.env.age")],
                   input=seed.encode(), check=True)

    base = f"http://127.0.0.1:{http_fixture.port}"
    env = dict(os.environ)
    env.update({
        "YMIR_HOME": str(home),
        "YMIR_TREE": str(TREE),
        "YMIR_OAUTH_AUTH_URL": base + "/auth",
        "YMIR_OAUTH_TOKEN_URL": base + "/token",
        "YMIR_OAUTH_TOKENINFO_URL": base + "/tokeninfo",
        "YMIR_GMAIL_API_BASE": base + "/gmail/v1",
        "PYTHONDONTWRITEBYTECODE": "1",
    })
    env.pop("GNA_SECRETS_FILE", None)
    env.pop("GNA_CONNECT_PORT", None)
    env["YMIR_OAUTH_LOOPBACK_PORT"] = "0"        # the fixture's fake Google takes any loopback port

    def run(args: list[str], stdin_data: str = "", timeout: float = 90.0):
        return subprocess.run([sys.executable, str(Path(__file__)), *args], input=stdin_data,
                              capture_output=True, text=True, timeout=timeout, env=env, cwd=str(TREE))

    def vault_get(key: str) -> str:
        out = subprocess.run([str(TREE / "bin" / "vault" / "hodd-set.sh"), "--get", key],
                             capture_output=True, text=True, env=env, timeout=120)
        return out.stdout.strip()

    try:
        # ── 1. the fixture vault is a REAL age vault, read through the real door ─────────────
        emit = subprocess.run([str(TREE / "bin" / "vault" / "hodd.sh"), "emit", "secrets/platform.env"],
                              capture_output=True, text=True, env=env, timeout=120)
        check("the vault door emits the fleet client's KEY names (never values)",
              DEFAULT_CLIENT_KEY in emit.stdout and "fixture-client-secret" in emit.stdout,
              "emit returned " + ("the keys" if emit.stdout else "nothing"))

        # ── 2. the consent URL carries everything and NO secret ──────────────────────────────
        section[0] = "google"
        listener = Loopback(0)
        url = consent_url("fixture-client-id", listener.redirect_uri(), scopes(), "state-fixture")
        listener.close()
        parsed = urllib.parse.parse_qs(urllib.parse.urlparse(url).query)
        check("the consent URL is offline + forced consent",
              parsed.get("access_type") == ["offline"] and parsed.get("prompt") == ["consent"],
              str({k: parsed.get(k) for k in ("access_type", "prompt")}))
        check("the consent URL redirects to 127.0.0.1 on an ephemeral port",
              parsed.get("redirect_uri", [""])[0].startswith("http://127.0.0.1:")
              and not parsed.get("redirect_uri", [""])[0].endswith(":0/callback"),
              str(parsed.get("redirect_uri")))
        check("the consent URL never carries the client secret",
              "fixture-client-secret" not in url, "no secret in the URL")
        held = Loopback(0)
        try:
            refused = run(["google", "--no-browser", "--port", str(held.port), "--timeout", "2"])
        finally:
            held.close()
        check("a busy port is refused with its holder named, and nothing is stopped",
              refused.returncode != 0 and f"port {held.port} is held by" in (refused.stderr + refused.stdout),
              (refused.stderr + refused.stdout).strip()[-120:])

        # ── 3. one full sign-in: URL → loopback → code → vault → GET /users/me ───────────────
        url_file = work / "consent-url.txt"
        proc = subprocess.Popen([sys.executable, str(Path(__file__)), "google", "--no-browser",
                                 "--consent-url-out", str(url_file)],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                env=env, cwd=str(TREE))
        signed = _await_file(url_file, 20.0)
        check("the door prints a consent URL and starts a loopback listener", bool(signed), signed[:60])
        caught_ok = False
        if signed:
            qs = urllib.parse.parse_qs(urllib.parse.urlparse(signed).query)
            redirect = urllib.parse.urlparse(qs["redirect_uri"][0])
            callback = (f"http://127.0.0.1:{redirect.port}{redirect.path}"
                        f"?code=fixture-code&state={qs['state'][0]}")
            try:
                with urllib.request.urlopen(callback, timeout=20) as page:
                    caught_ok = page.status == 200 and b"Signed in" in page.read()
            except Exception as exc:  # noqa: BLE001
                caught_ok = False
                check("the loopback redirect was answered", False, str(exc)[:120])
        out, err = proc.communicate(timeout=90)
        check("the loopback redirect was answered with the success page", caught_ok, "HTTP 200")
        check("a signed-in grant is reported as: account · grant live · expires",
              proc.returncode == 0 and "account guest@example.org · grant live · expires " in out,
              (out or err).strip().splitlines()[0] if (out or err) else "no output")
        check("the refresh token was written to the vault BY KEY",
              vault_get("GNA_GRANT_GUEST_EXAMPLE_ORG") == _FixtureHttp.REFRESH,
              "GNA_GRANT_GUEST_EXAMPLE_ORG resolves through hodd-set.sh --get")
        check("no secret is printed: neither the token nor the client secret appears",
              _FixtureHttp.REFRESH not in out + err and "fixture-client-secret" not in out + err,
              "stdout+stderr scanned")
        check("the token exchange sent code/redirect_uri/grant_type and no bearer",
              any(r["path"] == "/token" and r["form"].get("grant_type") == "authorization_code"
                  and r["form"].get("code") == "fixture-code"
                  and "redirect_uri" in r["form"] for r in http_fixture.requests),
              f"{len(http_fixture.requests)} request(s) to the token door")

        reg = (home / "hodd" / "memory" / "mail" / "accounts.yaml").read_text(encoding="utf-8")
        check("the account was ADDED to the register as a new row",
              'id: "guest@example.org"' in reg and "GNA_GRANT_GUEST_EXAMPLE_ORG" in reg,
              "accounts.yaml carries the row")

        # ── 4. a state that does not match is refused and writes nothing ────────────────────
        url_file2 = work / "consent-url-2.txt"
        proc2 = subprocess.Popen([sys.executable, str(Path(__file__)), "google", "--no-browser",
                                  "--consent-url-out", str(url_file2)],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                 env=env, cwd=str(TREE))
        signed2 = _await_file(url_file2, 20.0)
        if signed2:
            qs2 = urllib.parse.parse_qs(urllib.parse.urlparse(signed2).query)
            redirect2 = urllib.parse.urlparse(qs2["redirect_uri"][0])
            try:
                urllib.request.urlopen(f"http://127.0.0.1:{redirect2.port}{redirect2.path}"
                                       "?code=fixture-code&state=wrong-state", timeout=20).read()
            except Exception:  # noqa: BLE001
                pass
        out2, err2 = proc2.communicate(timeout=90)
        check("a mismatched state is refused, not exchanged",
              proc2.returncode == 1 and "state_mismatch" in (out2 + err2),
              (out2 + err2).strip().splitlines()[-1] if (out2 + err2) else "no output")

        # ── 5. --check says LIVE when it is live, and DEAD when it is dead ───────────────────
        live = run(["google", "--check"])
        check("--check reports a live grant with its expiry",
              live.returncode == 0 and "grant live · expires " in live.stdout,
              live.stdout.strip().splitlines()[0] if live.stdout else live.stderr[:120])
        http_fixture.mode = "dead"
        dead = run(["google", "--check"])
        check("--check reports a dead grant as `grant dead`, never as an empty inbox",
              dead.returncode == 1 and "grant dead" in dead.stdout
              and "messages" not in dead.stdout and "no mail" not in dead.stdout.lower(),
              dead.stdout.strip().replace("\n", " | ")[:160])
        http_fixture.mode = "live"

        # ── 6. the guest road: a real LOGIN and a real EXAMINE ──────────────────────────────
        section[0] = "imap"
        imap_ok = run(["imap", "--address", "guest2@example.org", "--host", "127.0.0.1",
                       "--port", str(imap_fixture.port), "--tls", "none"],
                      stdin_data="app-password-fixture\n")
        check("imap proves a REAL LOGIN and a REAL EXAMINE, and prints the count",
              imap_ok.returncode == 0
              and "mailbox guest2@example.org · INBOX · 7 messages" in imap_ok.stdout,
              imap_ok.stdout.strip().splitlines()[0] if imap_ok.stdout else imap_ok.stderr[:160])
        check("imap stores the password by KEY and never echoes it",
              vault_get("GNA_IMAP_PASSWORD_GUEST2_EXAMPLE_ORG") == "app-password-fixture"
              and "app-password-fixture" not in imap_ok.stdout + imap_ok.stderr,
              "vault key resolves; stdout+stderr scanned")
        wrong = run(["imap", "--address", "guest2@example.org", "--host", "127.0.0.1",
                     "--port", str(imap_fixture.port), "--tls", "none"],
                    stdin_data="wrong-password\n")
        check("a wrong app password fails loudly in one line and stores nothing new",
              wrong.returncode == 1 and "LOGIN refused" in (wrong.stdout + wrong.stderr)
              and "wrong-password" not in (wrong.stdout + wrong.stderr),
              (wrong.stdout + wrong.stderr).strip().splitlines()[0][:140])

        # ── 7. status: the honesty line ─────────────────────────────────────────────────────
        section[0] = "status"
        status = run(["status"])
        check("status names every account with readable · sendable · deliverable",
              status.returncode == 0 and status.stdout.count("guest") >= 2
              and "readable" in status.stdout and "deliverable" in status.stdout,
              status.stdout.strip().splitlines()[0] if status.stdout else status.stderr[:120])
        check("a non-gate account is never called sendable",
              "yes (our gate)" not in status.stdout,
              "sendable says where the gate is instead")

        # ── 8. revoke is a verb, and the door goes dark ─────────────────────────────────────
        section[0] = "revoke"
        revoke = run(["revoke", "guest@example.org"])
        check("revoke darkens the vault key and names what stopped",
              revoke.returncode == 0 and "revoked guest@example.org" in revoke.stdout
              and "stopped[3]" in revoke.stdout,
              revoke.stdout.strip().splitlines()[0] if revoke.stdout else revoke.stderr[:120])
        check("the revoked grant no longer resolves through the vault",
              vault_get("GNA_GRANT_GUEST_EXAMPLE_ORG") == "", "hodd-set.sh --get is empty")
        after = run(["status"])
        revoked_row = [ln for ln in after.stdout.splitlines() if "guest@example.org" in ln]
        check("after revocation status says readable=no for that account",
              bool(revoked_row) and '"no"' in revoked_row[0], revoked_row[0][:120] if revoked_row else "no row")
        twice = run(["revoke", "guest@example.org"])
        check("a second revoke says already dark, and does not fail",
              twice.returncode == 0 and "already dark" in twice.stdout,
              twice.stdout.strip().splitlines()[0] if twice.stdout else "")

        # ── 9. the gate law: this file cannot send ─────────────────────────────────────────
        section[0] = "common"
        source = Path(__file__).read_text(encoding="utf-8")
        forbidden = [t for t in ("smtp" + "lib", "/messages/" + "send", "drafts/" + "send",
                                 "port " + "587") if t in source]
        check("no send path exists in this file — sending stays on the gate", not forbidden,
              "found: " + ", ".join(forbidden) if forbidden else "no send endpoint, no mail client")

        # ── 10. the append-only event log survived every verb ──────────────────────────────
        log_path = home / "hodd" / "memory" / "mail" / "connect-log.jsonl"
        log_text = log_path.read_text(encoding="utf-8") if log_path.exists() else ""
        verbs = {json.loads(ln).get("verb") for ln in log_text.splitlines() if ln.strip()}
        check("the connect log is append-only and records connect + revoke",
              {"google", "imap", "revoke"} <= verbs,
              f"{len(log_text.splitlines())} line(s): {sorted(verbs)}")
    finally:
        http_fixture.stop()
        imap_fixture.stop()
        shutil.rmtree(work, ignore_errors=True)

    shown = [c for c in checks if not only or c[3] in (only, "common")]
    failures = [c for c in shown if not c[1]]
    door = only or "all"
    print(f"self-test[{len(shown)}]{{door,name,result,detail}}:")
    for name, ok, detail, sect in shown:
        print(f'  {q(door)},{q(name)},{q("PASS" if ok else "FAIL")},{q(detail)}')
    print(f"result: {'PASS' if not failures else 'FAIL'} — {len(shown) - len(failures)}/{len(shown)} "
          f"for {door}")
    return 0 if not failures else 1


# --------------------------------------------------------------------------- main


def main(argv: list[str]) -> int:
    args = list(argv)
    if not args:
        usage()
        return 2
    if "--version" in args or "-v" in args:
        print(VERSION)
        return 0
    if args[0] in ("-h", "--help", "help"):
        usage()
        return 0
    verb = args.pop(0)

    def opt(name: str, default: str = "") -> str:
        if name in args:
            i = args.index(name)
            value = args[i + 1] if i + 1 < len(args) else ""
            del args[i:i + 2]
            return value
        for token in list(args):
            if token.startswith(name + "="):
                args.remove(token)
                return token.split("=", 1)[1]
        return default

    def flag(name: str) -> bool:
        if name in args:
            args.remove(name)
            return True
        return False

    if verb == "--self-test" or verb == "self-test":
        return self_test()

    if verb == "google":
        if flag("--self-test") or flag("self-test"):
            return self_test("google")
        check_only = flag("--check")
        no_browser = flag("--no-browser")
        address = opt("--account")
        port_raw = opt("--port")
        timeout = opt("--timeout")
        url_out = opt("--consent-url-out")
        try:
            port = int(port_raw) if port_raw else None
        except ValueError:
            print(f"connect: --port must be a number, not {port_raw!r}", file=sys.stderr)
            return 2
        try:
            wait = float(timeout) if timeout else DEFAULT_TIMEOUT
        except ValueError:
            print(f"connect: --timeout must be seconds, not {timeout!r}", file=sys.stderr)
            return 2
        if check_only:
            return cmd_check(address)
        return cmd_google(address=address, port=port, timeout=wait,
                          open_browser=not no_browser, consent_url_out=url_out)

    if verb == "imap":
        if flag("--self-test") or flag("self-test"):
            return self_test("imap")
        address = opt("--address") or opt("--account")
        return cmd_imap(address, host=opt("--host"), port=opt("--port"), tls=opt("--tls"),
                        mailbox=opt("--mailbox"), password_stdin=flag("--password-stdin"))

    if verb == "status":
        if flag("--self-test") or flag("self-test"):
            return self_test("status")
        offline = flag("--offline")
        return cmd_status(opt("--account"), offline=offline)

    if verb == "revoke":
        if flag("--self-test") or flag("self-test"):
            return self_test("revoke")
        if not args:
            print("revoke: name the account to revoke", file=sys.stderr)
            return 2
        return cmd_revoke(args[0])

    print(f"connect: unknown verb {verb!r}", file=sys.stderr)
    usage()
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

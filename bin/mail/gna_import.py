#!/usr/bin/env python3
"""Gná's importer: one account, read-only, every message once.

  gna_import.py --account operator@example.com --days 7 --dry-run
  gna_import.py --account operator@example.com --days 2
  gna_import.py --account team@example.org --transport imap --days 3

TWO TRANSPORTS, ONE RECORD SHAPE (plan 116 §15.3.2). An account row names how it is
read — `transport: google` (the default; the Gmail grant) or `transport: imap` — so a
mailbox the house runs itself, or a store it adopts later, needs no rewrite and the
Google path keeps working unchanged.

  imap:
    host_key:     GNA_IMAP_HOST       # these are NAMES of keys in the vault
    port_key:     GNA_IMAP_PORT       # optional — 993 (IMAPS, the IANA default) when absent
    tls_key:      GNA_IMAP_TLS        # optional — ssl (default) · starttls · none (loopback only)
    user_key:     GNA_IMAP_USER
    password_key: GNA_IMAP_PASSWORD
    mailbox:      INBOX               # optional, not a secret

A value is never written here: the row names the key and the vault holds the value
(Rule 07). An account whose row declares no `imap:` block is refused — "disabled when
no IMAP account is declared" is a refusal, not a silent fallback to Gmail.

READ-ONLY, BOTH WAYS. The IMAP reader opens the mailbox with EXAMINE (`readonly=True`)
and never issues STORE, COPY, EXPUNGE, APPEND or DELETE. There is no send path in this
file: it never calls the Gmail sending endpoint, creates no draft, and speaks no SMTP.
"""

from __future__ import annotations

import argparse
import base64
import email
import email.policy
import json
import os
import re
import subprocess
import sys
import time
from datetime import timedelta
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from html import unescape
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import gna_judge
import gna_store

TREE = Path(os.environ.get("YMIR_TREE", Path.home() / "ymir"))
BODY_LIMIT = 20000


def vault_env() -> dict[str, str]:
    """The vault BY REFERENCE: bin/vault/hodd.sh emit secrets/platform.env.

    GNA_SECRETS_FILE points at a KEY=value file instead, and exists only so the
    proofs can show key resolution without a vault. Nothing else sets it, and no
    value is ever written into this repository."""
    override = os.environ.get("GNA_SECRETS_FILE", "").strip()
    if override:
        values: dict[str, str] = {}
        try:
            text = Path(override).read_text(encoding="utf-8")
        except OSError as exc:
            raise SystemExit(f"gna: GNA_SECRETS_FILE is set but unreadable: {exc}")
        for line in text.splitlines():
            m = re.match(r"^(?:export\s+)?([A-Za-z0-9_]+)=(.*)$", line.strip())
            if m:
                values[m.group(1)] = m.group(2).strip().strip("'\"")
        return values
    door = TREE / "bin" / "vault" / "hodd.sh"
    try:
        out = subprocess.run(
            [str(door), "emit", "secrets/platform.env"],
            capture_output=True, text=True, timeout=60, check=False,
        ).stdout
    except (OSError, subprocess.SubprocessError) as exc:
        raise SystemExit(f"gna: the vault door did not open: {exc}")
    values: dict[str, str] = {}
    for line in out.splitlines():
        m = re.match(r"^(?:export\s+)?([A-Z0-9_]+)=(.*)$", line.strip())
        if m:
            values[m.group(1)] = m.group(2).strip().strip("'\"")
    return values


def token_for(account_row: dict) -> str:
    env = vault_env()
    client_key = account_row.get("client") or "GOOGLE_MCP_CLIENT_ID"
    secret_key = account_row.get("client_secret") or "GOOGLE_MCP_CLIENT_SECRET"
    grant_key = account_row.get("grant") or "SNOTRA_GOOGLE_REFRESH_TOKEN"
    cid, csec, rt = env.get(client_key), env.get(secret_key), env.get(grant_key)
    if not (cid and csec and rt):
        raise SystemExit(f"gna: credentials missing ({client_key} · {secret_key} · {grant_key})")
    data = urllib.parse.urlencode(
        {"client_id": cid, "client_secret": csec, "refresh_token": rt, "grant_type": "refresh_token"}
    ).encode()
    req = urllib.request.Request("https://oauth2.googleapis.com/token", data=data)
    with urllib.request.urlopen(req, timeout=30) as r:
        token = json.load(r).get("access_token", "")
    if not token:
        raise SystemExit("gna: token refresh failed")
    return token


def api(token: str, path: str, params: dict | None = None) -> dict:
    url = "https://gmail.googleapis.com/gmail/v1" + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"Authorization": "Bearer " + token})
    last = None
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except urllib.error.HTTPError as exc:
            last = exc
            if exc.code not in (403, 429, 500, 502, 503):
                raise
            wait = float(exc.headers.get("retry-after") or 0) or min(30.0, 2.0 ** attempt)
            time.sleep(wait)
    raise SystemExit(f"gna: the Gmail API refused after 5 attempts: {last}")


def header(payload: dict, name: str) -> str:
    for h in payload.get("headers", []):
        if h.get("name", "").lower() == name.lower():
            return h.get("value", "")
    return ""


def addresses(value: str) -> list[dict]:
    out = []
    for part in re.split(r",(?![^<]*>)", value or ""):
        part = part.strip()
        if not part:
            continue
        m = re.match(r"^(.*?)<([^>]+)>$", part)
        if m:
            name = m.group(1).strip().strip('"')
            email = m.group(2).strip().lower()
        else:
            name, email = "", part.lower()
        out.append({"name": name, "email": email})
    return out


def _walk(payload: dict):
    yield payload
    for part in payload.get("parts", []) or []:
        yield from _walk(part)


def body_text(payload: dict) -> str:
    plain, html = "", ""
    for part in _walk(payload):
        mime = part.get("mimeType", "")
        data = (part.get("body") or {}).get("data")
        if not data:
            continue
        try:
            chunk = base64.urlsafe_b64decode(data + "===").decode("utf-8", "replace")
        except (ValueError, TypeError):
            continue
        if mime == "text/plain" and not plain:
            plain = chunk
        elif mime == "text/html" and not html:
            html = chunk
    text = plain or re.sub(r"<[^>]+>", " ", unescape(html))
    text = re.sub(r"\r\n?", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text).strip()
    return text[:BODY_LIMIT]


# --------------------------------------------------------------------------- IMAP


IMAP_DEFAULT_PORT = 993  # the IANA IMAPS port — the ONE documented default (Rule 07)
IMAP_DEFAULT_TLS = "ssl"
IMAP_DEFAULT_MAILBOX = "INBOX"
IMAP_TIMEOUT = 30


def imap_target(row: dict) -> dict:
    """Resolve an account's IMAP settings through the VAULT, by key name only.

    The row says `host_key: GNA_IMAP_HOST`; the vault holds the value. A key that is
    named but absent from the vault is a refusal with the key's name in it — never a
    silent fallback to a default host, because a mailbox read from the wrong host is
    worse than a mailbox not read."""
    cfg = row.get("imap") or {}
    account = row.get("id")
    if not isinstance(cfg, dict) or not cfg:
        raise SystemExit(
            f"gna: {account} is declared transport imap but has no imap: block — "
            "no IMAP account is declared, so this reader stays closed rather than guessing a host"
        )
    env = vault_env()

    def need(field: str, what: str) -> str:
        key = str(cfg.get(field) or "").strip()
        if not key:
            raise SystemExit(f"gna: the imap block of {account} names no {what} key ({field})")
        value = str(env.get(key) or "").strip()
        if not value:
            raise SystemExit(
                f"gna: the vault holds no {key} — {what} for {account} is named by reference and absent, "
                "so nothing is read (a name without a value is a refusal, not a default)"
            )
        return value

    host = need("host_key", "host")
    user = need("user_key", "user")
    password = need("password_key", "password")
    port_key = str(cfg.get("port_key") or "").strip()
    port_raw = str(env.get(port_key) or "").strip() if port_key else ""
    try:
        port = int(port_raw) if port_raw else int(cfg.get("port") or IMAP_DEFAULT_PORT)
    except ValueError:
        raise SystemExit(f"gna: the IMAP port for {account} is not a number: {port_raw!r}")
    tls_key = str(cfg.get("tls_key") or "").strip()
    tls = (str(env.get(tls_key) or "").strip() if tls_key else "") or str(cfg.get("tls") or IMAP_DEFAULT_TLS)
    tls = tls.strip().lower()
    if tls not in ("ssl", "starttls", "none"):
        raise SystemExit(f"gna: {account} asks for tls {tls!r}; ssl, starttls or none are the only reads this file has")
    if tls == "none" and not _is_loopback(host):
        raise SystemExit(
            f"gna: {account} asks for an unencrypted IMAP session to {host} — refused. "
            "Plaintext credentials leave the machine; raise the store's TLS instead"
        )
    return {
        "host": host,
        "port": port,
        "tls": tls,
        "user": user,
        "password": password,
        "mailbox": str(cfg.get("mailbox") or IMAP_DEFAULT_MAILBOX),
    }


def _is_loopback(host: str) -> bool:
    host = host.strip().strip("[]").lower()
    return host in ("localhost", "::1") or host.startswith("127.")


def imap_connect(target: dict):
    """Open the mailbox READ-ONLY. `select(readonly=True)` is EXAMINE: the server is
    told this client will not change flags, and nothing here ever asks it to."""
    import imaplib
    import ssl

    if target["tls"] == "ssl":
        conn = imaplib.IMAP4_SSL(target["host"], target["port"], timeout=IMAP_TIMEOUT)
    else:
        conn = imaplib.IMAP4(target["host"], target["port"], timeout=IMAP_TIMEOUT)
        if target["tls"] == "starttls":
            conn.starttls(ssl.create_default_context())
    conn.login(target["user"], target["password"])
    return conn


def _hdr(message, name: str) -> str:
    from email.header import decode_header, make_header

    raw = message.get(name, "") or ""
    try:
        return str(make_header(decode_header(raw)))
    except (UnicodeDecodeError, LookupError):
        return str(raw)


def _message_text(message) -> str:
    plain = html = ""
    for part in message.walk():
        if part.get_content_maintype() == "multipart":
            continue
        disposition = str(part.get("Content-Disposition") or "").lower()
        if "attachment" in disposition:
            continue
        try:
            chunk = part.get_content()
        except (LookupError, ValueError, UnicodeDecodeError):
            payload = part.get_payload(decode=True) or b""
            chunk = payload.decode(part.get_content_charset() or "utf-8", "replace")
        if not isinstance(chunk, str):
            continue
        if part.get_content_type() == "text/plain" and not plain:
            plain = chunk
        elif part.get_content_type() == "text/html" and not html:
            html = chunk
    text = plain or re.sub(r"<[^>]+>", " ", unescape(html))
    text = re.sub(r"\r\n?", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text).strip()
    return text[:BODY_LIMIT]


def _imap_records(account: str, raws: list[tuple[bytes, str]]) -> list[dict]:
    """Turn fetched RFC822 bytes into the SAME record the Gmail path builds."""
    from email.utils import parsedate_to_datetime

    by_email, _by_id = people_book()
    out: list[dict] = []
    for data, fallback_id in raws:
        message = email.message_from_bytes(data, policy=email.policy.default)
        sender = addresses(_hdr(message, "From"))
        when = _hdr(message, "Date")
        try:
            received = parsedate_to_datetime(when).astimezone(timezone.utc).isoformat(timespec="seconds")
        except (TypeError, ValueError):
            received = datetime.now(timezone.utc).isoformat(timespec="seconds")
        message_id = _hdr(message, "Message-ID").strip()
        references = _hdr(message, "In-Reply-To").strip() or _hdr(message, "References").strip()
        record = {
            "id": message_id.strip("<>") or fallback_id,
            "account": account,
            "direction": "out" if (sender and sender[0]["email"] == account) else "in",
            "thread_key": (references.split()[0].strip("<>") if references else (message_id.strip("<>") or fallback_id)),
            "from": sender[0] if sender else {"name": "", "email": ""},
            "to": addresses(_hdr(message, "To")),
            "to_header": _hdr(message, "To"),
            "cc": addresses(_hdr(message, "Cc")),
            "subject": _hdr(message, "Subject"),
            "body_text": _message_text(message),
            "received_at": received,
            "labels": [str(label) for label in (message.get_all("X-Gmail-Labels") or [])][:20],
            "list_unsubscribe": _hdr(message, "List-Unsubscribe")[:200],
            "precedence": _hdr(message, "Precedence")[:40],
            "auto_submitted": _hdr(message, "Auto-Submitted")[:40],
            "attachments": [
                {"name": part.get_filename(), "mime": part.get_content_type(), "size": len(part.get_payload(decode=True) or b"")}
                for part in message.walk()
                if part.get_filename()
            ],
        }
        out.append(_finish(record, by_email, out))
    return out


def collect_imap(account: str, row: dict, days: int, max_messages: int, to_address: str = "") -> list[dict]:
    target = imap_target(row)
    since = (datetime.now(timezone.utc) - timedelta(days=max(days, 1))).strftime("%d-%b-%Y")
    criteria: list[str] = ["SINCE", since]
    if to_address:
        criteria += ["TO", to_address]
    conn = imap_connect(target)
    try:
        conn.select(target["mailbox"], readonly=True)
        status, data = conn.uid("search", None, *criteria)
        if status != "OK":
            raise SystemExit(f"gna: the IMAP store refused the search on {account}: {status}")
        uids = (data[0] or b"").split() if data else []
        wanted = uids[-max(1, max_messages):]
        raws: list[tuple[bytes, str]] = []
        for uid in reversed(wanted):  # newest first, as the Gmail path returns them
            status, payload = conn.uid("fetch", uid, "(RFC822)")
            if status != "OK":
                continue
            label = uid.decode() if isinstance(uid, (bytes, bytearray)) else str(uid)
            data = _fetched_bytes(payload or [])
            if data:
                raws.append((data, f"imap:{account}:{label}"))
    finally:
        try:
            conn.logout()
        except Exception:  # a socket already gone is not a read failure
            pass
    return _imap_records(account, raws)


def _fetched_bytes(payload: list) -> bytes:
    """The RFC822 bytes out of an imaplib FETCH answer, whichever shape it took.

    imaplib returns a literal as a (prefix, bytes) tuple; some servers answer without
    the literal framing, so the joined bytes are used when they hold a message."""
    for part in payload:
        if isinstance(part, tuple) and len(part) >= 2 and isinstance(part[1], (bytes, bytearray)):
            return bytes(part[1])
    joined = b"".join(part for part in payload if isinstance(part, (bytes, bytearray)))
    return joined if b"\r\n\r\n" in joined else b""


def search_address(account: str, address: str, days: int = 2) -> list[dict]:
    """Every message ADDRESSED to `address` in the last `days`, from whichever transport
    the account's row names. This is the search the arrival proof asks and the desk never does."""
    return collect(account, days=days, max_messages=50, to_address=address)


def people_book() -> tuple[dict[str, dict], dict[str, dict]]:
    path = gna_store.HOME / "hodd" / "identity" / "collaborators.yaml"
    try:
        import yaml
        with path.open(encoding="utf-8") as fh:
            rows = (yaml.safe_load(fh) or {}).get("people") or []
    except (OSError, ImportError):
        rows = []
    by_email: dict[str, dict] = {}
    by_id: dict[str, dict] = {}
    for person in rows:
        by_id[person.get("id", "")] = person
        for address in person.get("emails") or []:
            if address:
                by_email[address.strip().lower()] = person
    return by_email, by_id


def transport_of(row: dict) -> str:
    """How this account is read. `google` is the default the 2026-10 page wrote."""
    transport = str(row.get("transport") or "google").strip().lower()
    if transport in ("google", "gmail"):
        return "google"
    if transport == "imap":
        return "imap"
    raise SystemExit(
        f"gna: account {row.get('id')} declares transport {transport!r}; only google and imap are reads this file has"
    )


def collect(account: str, days: int, max_messages: int, to_address: str = "") -> list[dict]:
    """Read one account. The transport is a property of the ACCOUNT's row, never a guess."""
    row = gna_store.declared_accounts()[account]
    transport = transport_of(row)
    if transport == "imap":
        return collect_imap(account, row, days, max_messages, to_address=to_address)
    return collect_google(account, row, days, max_messages, to_address=to_address)


def collect_google(account: str, row: dict, days: int, max_messages: int, to_address: str = "") -> list[dict]:
    token = token_for(row)
    profile = api(token, "/users/me/profile")
    owner = (profile.get("emailAddress") or "").lower()
    if owner and owner != account:
        raise SystemExit(f"gna: the grant belongs to {owner}, not {account} — refused")
    query = f"newer_than:{days}d -in:chats"
    if to_address:
        query += f" to:{to_address}"
    listing = api(token, "/users/me/messages", {"q": query, "maxResults": max_messages})
    ids = [m["id"] for m in listing.get("messages", [])][:max_messages]
    by_email, by_id = people_book()
    out: list[dict] = []
    for mid in ids:
        full = api(token, f"/users/me/messages/{mid}", {"format": "full"})
        time.sleep(0.25)
        payload = full.get("payload", {})
        sender = addresses(header(payload, "From"))
        record = {
            "id": full.get("id"),
            "account": account,
            "direction": "out" if (sender and sender[0]["email"] == account) else "in",
            "thread_key": full.get("threadId"),
            "from": sender[0] if sender else {"name": "", "email": ""},
            "to": addresses(header(payload, "To")),
            "to_header": header(payload, "To"),
            "cc": addresses(header(payload, "Cc")),
            "subject": header(payload, "Subject"),
            "body_text": body_text(payload),
            "received_at": datetime.fromtimestamp(
                int(full.get("internalDate", "0")) / 1000, timezone.utc
            ).isoformat(timespec="seconds"),
            "labels": full.get("labelIds", []),
            "list_unsubscribe": header(payload, "List-Unsubscribe")[:200],
            "precedence": header(payload, "Precedence")[:40],
            "auto_submitted": header(payload, "Auto-Submitted")[:40],
            "attachments": [
                {"name": p.get("filename"), "mime": p.get("mimeType"), "size": (p.get("body") or {}).get("size")}
                for p in _walk(payload)
                if p.get("filename")
            ],
        }
        out.append(_finish(record, by_email, out))
    return out


def _finish(record: dict, by_email: dict[str, dict], seen: list[dict]) -> dict:
    """Judge one record and stamp it. The tail both transports share, so a message read
    over IMAP and one read over the Gmail API arrive as the SAME shape."""
    sender_email = (record.get("from") or {}).get("email", "")
    person = by_email.get(sender_email)
    thread = next((r for r in reversed(seen) if r.get("thread_key") == record.get("thread_key")), None)
    verdict = gna_judge.judge(record, by_email, thread, house=gna_store.house_addresses())
    record.update(verdict)
    record.setdefault("person_id", (person or {}).get("id"))
    record.setdefault("project_id", (person or {}).get("project") or None)
    record["read_at"] = None
    record["handled_at"] = None
    record["actor"] = "gna-import"
    return record


def self_test() -> int:
    """The refusals and the parse, proven without a network.

    The end-to-end proof against a real socket lives in bin/mail/tests/test_gna.py
    (a fixture IMAP server on loopback); this is the door's own fast check."""
    checks: list[tuple[str, bool, str]] = []
    tmp = Path(os.environ.get("TMPDIR", "/tmp")) / f"gna-import-selftest-{os.getpid()}"
    tmp.mkdir(parents=True, exist_ok=True)
    secrets = tmp / "secrets.env"
    secrets.write_text(
        "GNA_IMAP_HOST=127.0.0.1\nGNA_IMAP_PORT=1143\nGNA_IMAP_TLS=none\n"
        "GNA_IMAP_USER=reader@example.org\nGNA_IMAP_PASSWORD=fixture\n",
        encoding="utf-8",
    )
    os.environ["GNA_SECRETS_FILE"] = str(secrets)
    row = {"id": "reader@example.org", "transport": "imap", "imap": {
        "host_key": "GNA_IMAP_HOST", "port_key": "GNA_IMAP_PORT", "tls_key": "GNA_IMAP_TLS",
        "user_key": "GNA_IMAP_USER", "password_key": "GNA_IMAP_PASSWORD", "mailbox": "INBOX"}}
    try:
        target = imap_target(row)
        checks.append(("the vault names resolve a host and port",
                       target["host"] == "127.0.0.1" and target["port"] == 1143, str(target)))
        checks.append(("read-only is the only mode offered", target["tls"] == "none", str(target["tls"])))
        checks.append(("transport is read from the row", transport_of(row) == "imap", "imap"))
        try:
            imap_target({"id": "x@example.org", "transport": "imap"})
            checks.append(("an imap account with no imap block is refused", False, "no refusal"))
        except SystemExit as exc:
            checks.append(("an imap account with no imap block is refused", "no imap" in str(exc), str(exc)))
        broken = {"id": "y@example.org", "transport": "imap",
                  "imap": {"host_key": "GNA_IMAP_HOST", "user_key": "GNA_ABSENT_KEY",
                           "password_key": "GNA_IMAP_PASSWORD"}}
        try:
            imap_target(broken)
            checks.append(("a named-but-absent key is a refusal, not a default", False, "no refusal"))
        except SystemExit as exc:
            checks.append(("a named-but-absent key is a refusal, not a default",
                           "GNA_ABSENT_KEY" in str(exc), str(exc)))
        secrets.write_text(secrets.read_text(encoding="utf-8").replace(
            "GNA_IMAP_HOST=127.0.0.1", "GNA_IMAP_HOST=mail.example.com"), encoding="utf-8")
        offbox = {"id": "z@example.org", "transport": "imap",
                  "imap": {"host_key": "GNA_IMAP_HOST", "user_key": "GNA_IMAP_USER",
                           "password_key": "GNA_IMAP_PASSWORD", "tls_key": "GNA_IMAP_TLS"}}
        try:
            imap_target(offbox)
            checks.append(("plaintext off loopback is refused", False, "no refusal"))
        except SystemExit as exc:
            checks.append(("plaintext off loopback is refused", "unencrypted" in str(exc), str(exc)))
        raw = (
            b"From: Craig Example <craig@example.com>\r\n"
            b"To: gimle@example.org\r\n"
            b"Subject: Faktura 2026-10\r\n"
            b"Message-ID: <fixture-1@example.com>\r\n"
            b"Date: Fri, 23 Oct 2026 10:00:00 +0000\r\n"
            b"Content-Type: text/plain; charset=utf-8\r\n\r\n"
            b"Bifogad faktura for oktober.\r\n"
        )
        records = _imap_records("reader@example.org", [(raw, "imap:fixture:1")])
        first = records[0] if records else {}
        checks.append(("a fetched message keeps its To: header intact",
                       first.get("to_header") == "gimle@example.org", str(first.get("to_header"))))
        checks.append(("a fetched message carries the id its Message-ID names",
                       first.get("id") == "fixture-1@example.com", str(first.get("id"))))
        checks.append(("a fetched message is judged like any other",
                       first.get("classification") in gna_judge.CLASSES and bool(first.get("evidence")),
                       str(first.get("classification"))))
    finally:
        os.environ.pop("GNA_SECRETS_FILE", None)
        for path in sorted(tmp.rglob("*"), reverse=True):
            path.unlink() if path.is_file() else path.rmdir()
    failures = [name for name, ok, _ in checks if not ok]
    for name, ok, detail in checks:
        print(f"{'PASS' if ok else 'FAIL'}  {name}")
        if not ok:
            print(f"      {detail}")
    print(f"self-test: {len(checks) - len(failures)}/{len(checks)} passed")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Gná's read-only importer")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--account", required=False)
    ap.add_argument("--days", type=int, default=7)
    ap.add_argument("--max", type=int, default=200)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        return self_test()
    if not args.account:
        ap.error("--account is required")

    account = gna_store.require_account(args.account)
    records = collect(account, args.days, args.max)

    classes: dict[str, int] = {}
    columns = {"needs_you": 0, "unsure": 0, "waiting": 0, "done": 0}
    for r in records:
        classes[r["classification"]] = classes.get(r["classification"], 0) + 1
        columns[column_of(r)] += 1

    written = {"written": 0, "skipped": 0}
    if not args.dry_run:
        written = gna_store.append(records)

    summary = {
        "account": account,
        "transport": transport_of(gna_store.declared_accounts()[account]),
        "window_days": args.days,
        "read": len(records),
        "classes": classes,
        "columns": columns,
        "store": written,
        "dry_run": args.dry_run,
        "unknown_sender": sum(1 for r in records if not r.get("person_id") and r.get("direction") == "in"),
        "send_capability": "none",
    }
    if args.json:
        print(json.dumps(summary, indent=1, ensure_ascii=False))
        return 0

    print(f"gna · {account} · last {args.days}d · read {len(records)}")
    print("  classes  " + (" · ".join(f"{k}={v}" for k, v in sorted(classes.items())) or "none"))
    print("  desk     " + " · ".join(f"{k}={v}" for k, v in columns.items()))
    print("  unknown  " + str(summary["unknown_sender"]) + " sender(s) with no person record")
    if args.dry_run:
        print("  store    dry run — nothing written")
    else:
        print(f"  store    {written['written']} written · {written['skipped']} unchanged · {written.get('spine', '')}")
    return 0


def column_of(record: dict) -> str:
    if record.get("handled_at"):
        return "done"
    if record.get("direction") == "out":
        return "waiting"
    if float(record.get("confidence") or 0) < 0.6:
        return "unsure"
    if record.get("proposed_action") == "archive":
        return "done"
    return "needs_you"


if __name__ == "__main__":
    raise SystemExit(main())

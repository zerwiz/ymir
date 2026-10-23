#!/usr/bin/env python3
"""Gná's importer: one account, read-only, every message once.

  gna_import.py --account operator@example.com --days 7 --dry-run
  gna_import.py --account operator@example.com --days 2

It reads through the Gmail API with the grant the account's row names. There is
no send path in this file: it never calls the Gmail sending endpoint, creates no
draft, and speaks no SMTP.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import time
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


def collect(account: str, days: int, max_messages: int) -> list[dict]:
    row = gna_store.declared_accounts()[account]
    token = token_for(row)
    profile = api(token, "/users/me/profile")
    owner = (profile.get("emailAddress") or "").lower()
    if owner and owner != account:
        raise SystemExit(f"gna: the grant belongs to {owner}, not {account} — refused")
    query = f"newer_than:{days}d -in:chats"
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
        sender_email = record["from"].get("email", "")
        person = by_email.get(sender_email)
        thread = next((r for r in reversed(out) if r.get("thread_key") == record["thread_key"]), None)
        verdict = gna_judge.judge(record, by_email, thread, house=gna_store.house_addresses())
        record.update(verdict)
        record.setdefault("person_id", (person or {}).get("id"))
        record.setdefault("project_id", (person or {}).get("project") or None)
        record["read_at"] = None
        record["handled_at"] = None
        record["actor"] = "gna-import"
        out.append(record)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Gná's read-only importer")
    ap.add_argument("--account", required=True)
    ap.add_argument("--days", type=int, default=7)
    ap.add_argument("--max", type=int, default=200)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

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

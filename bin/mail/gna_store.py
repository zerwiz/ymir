"""Gná's store: one message once, and the account is the boundary.

Every read takes an account. An account that is not declared in
hodd/memory/mail/accounts.yaml is refused, not defaulted. A message is never
returned through another account's scope, and nothing here can send.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    raise SystemExit("gna_store: PyYAML is required") from exc


class ScopeError(Exception):
    """A read that named no account, or an account the store does not serve."""


def ymir_home() -> Path:
    env = os.environ.get("YMIR_HOME")
    if env:
        return Path(env).expanduser()
    record = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "ymir" / "home"
    try:
        first = record.read_text(encoding="utf-8").splitlines()[0].strip()
        if first:
            return Path(first).expanduser()
    except (OSError, IndexError):
        pass
    return Path.home() / "Documents" / "ymirhome"


HOME = ymir_home()
MAIL_DIR = HOME / "hodd" / "memory" / "mail"
SPINE = MAIL_DIR / "messages.jsonl"
ACCOUNTS = MAIL_DIR / "accounts.yaml"
RETENTION = MAIL_DIR / "retention.yaml"
STATE_DIR = HOME / "hodd" / "state"
TOKEN_FILE = STATE_DIR / "gna-desk.token"

ACCOUNT_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def _yaml(path: Path) -> dict:
    try:
        with path.open(encoding="utf-8") as fh:
            return yaml.safe_load(fh) or {}
    except FileNotFoundError:
        return {}


def declared_accounts() -> dict[str, dict]:
    rows = _yaml(ACCOUNTS).get("accounts") or []
    out: dict[str, dict] = {}
    for row in rows:
        if isinstance(row, dict) and row.get("id"):
            out[str(row["id"]).strip().lower()] = row
    return out


def house_addresses() -> set[str]:
    rows = _yaml(ACCOUNTS).get("house") or []
    return {str(a).strip().lower() for a in rows if str(a).strip()}


def require_account(account: str | None) -> str:
    if not account or not str(account).strip():
        raise ScopeError("account scope required: every query names one account")
    key = str(account).strip().lower()
    if not ACCOUNT_RE.match(key):
        raise ScopeError(f"not an address: {account!r}")
    known = declared_accounts()
    if key not in known:
        raise ScopeError(f"account not declared in {ACCOUNTS}: {key}")
    return key


def retention() -> dict:
    return _yaml(RETENTION)


def _sha(record: dict) -> str:
    payload = json.dumps(
        {k: record.get(k) for k in ("subject", "from", "to", "received_at", "body_text",
                                    "classification", "confidence", "proposed_action", "evidence")},
        sort_keys=True,
        ensure_ascii=False,
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _iter(account: str):
    account = require_account(account)
    if not SPINE.exists():
        return
    with SPINE.open(encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("account") != account:
                continue
            yield row


def latest(account: str, hours: int | None = None) -> list[dict]:
    account = require_account(account)
    cutoff = None
    if hours:
        cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
    by_id: dict[str, dict] = {}
    for row in _iter(account):
        rid = row.get("id")
        if not rid:
            continue
        if cutoff:
            stamp = row.get("received_at") or ""
            try:
                when = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
            except ValueError:
                when = None
            if when and when < cutoff:
                continue
        by_id[rid] = row
    rows = list(by_id.values())
    rows.sort(key=lambda r: r.get("received_at") or "", reverse=True)
    return rows


def get_message(account: str, message_id: str) -> dict:
    account = require_account(account)
    if not message_id:
        raise ScopeError("message id required")
    found = None
    for row in _iter(account):
        if row.get("id") == message_id:
            if row.get("account") != account:
                raise ScopeError("message belongs to another account")
            found = row
    if not found:
        raise ScopeError(f"message {message_id} is not in account {account}")
    return found


def append(records: list[dict]) -> dict:
    if not records:
        return {"written": 0, "skipped": 0}
    MAIL_DIR.mkdir(parents=True, exist_ok=True)
    seen: dict[tuple[str, str], str] = {}
    if SPINE.exists():
        for row in (_json_loads(line) for line in SPINE.read_text(encoding="utf-8").splitlines() if line.strip()):
            if row.get("id"):
                seen[(row.get("account", ""), row["id"])] = row.get("body_sha", "")
    written = skipped = 0
    with SPINE.open("a", encoding="utf-8") as fh:
        for record in records:
            account = require_account(record.get("account"))
            record["account"] = account
            record["body_sha"] = _sha(record)
            key = (account, str(record.get("id")))
            if seen.get(key) == record["body_sha"]:
                skipped += 1
                continue
            record.setdefault("ingested_at", datetime.now(timezone.utc).isoformat(timespec="seconds"))
            fh.write(json.dumps(record, ensure_ascii=False) + "\n")
            seen[key] = record["body_sha"]
            written += 1
    return {"written": written, "skipped": skipped, "spine": str(SPINE)}


def _json_loads(line: str) -> dict:
    try:
        return json.loads(line)
    except json.JSONDecodeError:
        return {}


def stats() -> dict:
    out: dict = {"accounts": {}, "versions": 0, "spine": str(SPINE), "exists": SPINE.exists()}
    if not SPINE.exists():
        return out
    ids: dict[str, set[str]] = {}
    last = ""
    lines = 0
    for line in SPINE.read_text(encoding="utf-8").splitlines():
        row = _json_loads(line)
        account = row.get("account")
        if not account:
            continue
        lines += 1
        ids.setdefault(account, set()).add(str(row.get("id")))
        last = max(last, row.get("ingested_at") or "")
    out["accounts"] = {a: len(v) for a, v in ids.items()}
    out["versions"] = lines
    out["last_ingest"] = last
    out["declared"] = sorted(declared_accounts())
    return out


def last_run() -> dict:
    """The importer's last scheduled run, if it left one. An unchanged store is a success."""
    import json as _json
    path = STATE_DIR / "gna-mail-last-run.json"
    try:
        return _json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def prune_report(account: str) -> dict:
    account = require_account(account)
    months = int((retention().get("bodies_months") or 24))
    cutoff = datetime.now(timezone.utc) - timedelta(days=months * 30)
    stale = []
    counts: dict[str, int] = {}
    for row in latest(account):
        counts[row.get("classification") or "other"] = counts.get(row.get("classification") or "other", 0) + 1
        try:
            when = datetime.fromisoformat((row.get("received_at") or "").replace("Z", "+00:00"))
        except ValueError:
            continue
        if when < cutoff:
            stale.append(row.get("id"))
    return {
        "account": account,
        "retention_months": months,
        "older_than_cutoff": len(stale),
        "classes": counts,
        "mode": "report-only: the spine is append-only, a human decides a redaction",
    }

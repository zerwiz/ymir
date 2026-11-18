#!/usr/bin/env python3
"""dispatcher.py — incoming work becomes a bounded errand or a line on the Allfather's list.

    dispatch.sh run [--dry-run] [--json] [--max N] [--hours H]
    dispatch.sh --check [--json]
    dispatch.sh --help

WHAT IT READS. Two sources, and nothing else is trusted:

  1. THE DESK'S NEEDS-YOU QUEUE — the rows Gná's desk puts in `needs_you` and `unsure` for every
     account the home declares (`hodd/memory/mail/accounts.yaml`). Two roads reach the same rows:
     the desk over loopback (`GNA_DESK_URL`, token from `hodd/state/gna-desk.token`) and, when the
     desk does not answer, the store it reads (`hodd/memory/mail/messages.jsonl`), through Gná's own
     `column_of` so the classification is never a second opinion. The run names the road that
     answered — a borrowed answer says so.
  2. THE DURABLE WAKE QUEUE — `<home>/state/.wake-queue`. Only the last `DISPATCH_WAKE_TAIL` lines,
     only the ones inside `DISPATCH_HOURS`, and only a `needs-decision` — a worker saying it cannot go
     on without his word. A `lock-ask` is addressed to whoever holds the ARM and the arm drains it, so
     proposing it would duplicate a queue that already has an owner; a notice is not an ask at all.
     A decision's identity is its words with the clock and the numbers folded, so a worker asking the
     same thing twice is ONE decision.

WHAT IT WRITES. Two paths, and nothing else:

  * `hodd/life/personal/me/todo.md` — a proposal block between two markers, inside the house-kept
    half. His own half is never touched. A proposal is a line the house believes wants him, never an
    act: nothing is sent, nothing is spawned, nothing is closed.
  * `hodd/state/dispatch/runs.jsonl` — append-only. One row per state-changing event (a proposal, a
    refusal, a failure) and ONE row per run saying `work` or `no-op` and why.

THE THREE LAWS, each proved in bin/dispatch/tests/test_dispatch.py:

  1. IDEMPOTENT BY KEY. The key is `sha256(source|id)`. A key already proposed — found either in the
     to-do or in the ledger — is a no-op, so a second pass over unchanged input writes no second line.
  2. THE ATTEMPT CAP. Three failed attempts for one key and the fourth is REFUSED, recorded once as
     terminal-failed; every run after that is a no-op naming the terminal state.
  3. AN UNREADABLE INPUT IS AN ERROR, NEVER AN EMPTY LIST. A store that cannot be read, an accounts
     file that parses to nothing, a queue that cannot be opened: the run records `failed` and exits 3.
     `0 items` is a claim, and this door refuses to make it about a file it did not read.

NEVER: sends mail · writes his half · spawns an errand · takes the arm · rewrites the ledger. The arm
spends a proposal; this door only names it (and names its shape: `errand` when the house can carry
it, `line` when the judgement is his alone).

    `sources` names the road that answered, and how many
     queue lines were older than the window.

Environment (Rule 07 — every one has one documented default):

    YMIR_HOME              the private home (else bin/vault/hoard-lib.sh resolves it)
    DISPATCH_STATE_DIR     <home>/hodd/state/dispatch
    DISPATCH_TODO          <home>/hodd/life/personal/me/todo.md
    DISPATCH_WAKE_QUEUE    <home>/state/.wake-queue
    GNA_DESK_URL           http://127.0.0.1:8494   (empty: read the store only)
    GNA_DESK_TOKEN_FILE    <home>/hodd/state/gna-desk.token
    DISPATCH_HOURS         48      the window for mail rows AND for a wake-queue ask
    DISPATCH_MAX           5       proposals written by one run
    DISPATCH_ATTEMPT_CAP   3       failed attempts before a key is terminal
    DISPATCH_WAKE_TAIL     200     how far back the wake queue is read
    DISPATCH_DESK_TIMEOUT  5       seconds before the store road is taken
    DISPATCH_NOW           unset; pins the clock (a test only)

Exit: 0 ran · 2 usage · 3 an input is unreadable · 4 the record cannot be read or written.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
MAIL_LIB = ROOT / "bin" / "mail"

INBOX_OPEN = ("<!-- dispatch:inbox — proposals only (bin/dispatch, kept by the house). "
              "The house writes between these two markers and never in his half. -->")
INBOX_CLOSE = "<!-- /dispatch:inbox -->"

EXIT_RAN = 0
EXIT_USAGE = 2
EXIT_INPUT = 3
EXIT_STATE = 4


class InputError(Exception):
    """A source that could not be read. An error, never an empty list."""


class StateError(Exception):
    """The record — the to-do or the run ledger — cannot be read or written."""


# ── the home and the clock ────────────────────────────────────────────────────

def home() -> Path:
    env = os.environ.get("YMIR_HOME")
    if env:
        return Path(env).expanduser()
    lib = ROOT / "bin" / "vault" / "hoard-lib.sh"
    try:
        out = subprocess.run(
            ["bash", "-c",
             f'. "{lib}" >/dev/null 2>&1; r=""; ymir_home_root r 2>/dev/null; printf "%s" "$r"'],
            capture_output=True, text=True, timeout=10).stdout.strip()
    except Exception:
        out = ""
    if out and os.path.isdir(out):
        return Path(out)
    raise InputError("the home is unresolved — set YMIR_HOME")


def now() -> dt.datetime:
    fixed = os.environ.get("DISPATCH_NOW")
    if fixed:
        try:
            stamp = dt.datetime.fromisoformat(fixed.replace("Z", "+00:00"))
            return stamp if stamp.tzinfo else stamp.replace(tzinfo=dt.timezone.utc)
        except ValueError:
            pass
    return dt.datetime.now(dt.timezone.utc)


def iso(instant: dt.datetime) -> str:
    return instant.astimezone(dt.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def state_dir(H: Path) -> Path:
    env = os.environ.get("DISPATCH_STATE_DIR")
    return Path(env).expanduser() if env else H / "hodd" / "state" / "dispatch"


def todo_path(H: Path) -> Path:
    env = os.environ.get("DISPATCH_TODO")
    return Path(env).expanduser() if env else H / "hodd" / "life" / "personal" / "me" / "todo.md"


def wake_queue(H: Path) -> Path:
    env = os.environ.get("DISPATCH_WAKE_QUEUE")
    return Path(env).expanduser() if env else H / "state" / ".wake-queue"


def runs_path(H: Path) -> Path:
    return state_dir(H) / "runs.jsonl"


def number(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if raw is None or raw.strip() == "":
        return default
    try:
        return int(raw)
    except ValueError:
        raise InputError(f"{name}={raw!r} is not a whole number")


def key_of(source: str, ident: str) -> str:
    """The idempotency key: sha256(source|id). One formula, one place."""
    return hashlib.sha256(f"{source}|{ident}".encode("utf-8")).hexdigest()


# ── the ledger (append-only) ─────────────────────────────────────────────────

def read_runs(path: Path) -> list[dict]:
    if not path.exists():
        return []
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise StateError(f"{path} cannot be read ({exc.__class__.__name__}: {exc})")
    rows, bad = [], []
    for n, line in enumerate(text.splitlines(), 1):
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            bad.append(n)
            continue
        if isinstance(row, dict):
            rows.append(row)
        else:
            bad.append(n)
    if bad:
        raise StateError(f"{path} holds {len(bad)} line(s) that are not a record (first: line {bad[0]})")
    return rows


def fold(rows: list[dict]) -> dict[str, dict]:
    """Per key: how many failed attempts, whether a proposal was written, whether it is terminal."""
    out: dict[str, dict] = {}
    for row in rows:
        key = row.get("key")
        if not key or row.get("kind") != "event":
            continue
        slot = out.setdefault(key, {"failed": 0, "proposed": False, "refused": False})
        verdict = row.get("verdict")
        if verdict == "failed":
            slot["failed"] += 1
        elif verdict == "proposed":
            slot["proposed"] = True
        elif verdict == "refused":
            slot["refused"] = True
    return out


def append_runs(path: Path, rows: list[dict]) -> None:
    if not rows:
        return
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as fh:
            for row in rows:
                fh.write(json.dumps(row, ensure_ascii=False, sort_keys=False) + "\n")
    except OSError as exc:
        raise StateError(f"{path} cannot be appended to ({exc.__class__.__name__}: {exc})")


# ── the inputs ───────────────────────────────────────────────────────────────

def _mail_modules(H: Path):
    """Gná's own store and desk rule — never a second classifier."""
    os.environ.setdefault("YMIR_HOME", str(H))
    if str(MAIL_LIB) not in sys.path:
        sys.path.insert(0, str(MAIL_LIB))
    try:
        import gna_desk  # noqa: F401
        import gna_store  # noqa: F401
    except SystemExit as exc:                      # gna_store raises SystemExit on a missing parser
        raise InputError(f"the mail store cannot be loaded ({exc})")
    except Exception as exc:
        raise InputError(f"the mail store cannot be imported ({exc.__class__.__name__}: {exc})")
    return gna_store, gna_desk


def _accounts(gna_store) -> list[str]:
    """The declared accounts. An absent file is a NAMED SKIP (mail is not configured on this seat);
    a file that parses to nothing is an error, because unreadable is not empty."""
    path = gna_store.ACCOUNTS
    if not path.exists():
        return []
    try:
        declared = gna_store.declared_accounts()
    except Exception as exc:
        raise InputError(f"{path} cannot be read ({exc.__class__.__name__}: {exc})")
    names = sorted(declared) if isinstance(declared, dict) else sorted(declared or [])
    if not names:
        raise InputError(f"{path} declares no usable account — the desk is unconfigured, not idle")
    return names


def _desk_token(H: Path) -> str:
    env = os.environ.get("GNA_DESK_TOKEN")
    if env:
        return env.strip()
    path = Path(os.environ.get("GNA_DESK_TOKEN_FILE") or (H / "hodd" / "state" / "gna-desk.token"))
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def _desk_columns(url: str, token: str, account: str, hours: int) -> dict:
    query = urllib.parse.urlencode({"account": account, "hours": hours})
    request = urllib.request.Request(
        f"{url.rstrip('/')}/queue?{query}", headers={"Authorization": f"Bearer {token}"})
    timeout = float(os.environ.get("DISPATCH_DESK_TIMEOUT", "5"))
    with urllib.request.urlopen(request, timeout=timeout) as handle:
        document = json.loads(handle.read().decode("utf-8"))
    return document.get("columns") or {}


def _store_columns(gna_store, gna_desk, account: str, hours: int) -> dict:
    """The desk's own three calls, without its honesty line (which needs DNS): same rows, same rule."""
    try:
        every = gna_store.latest(account, hours)
    except gna_store.ScopeError as exc:
        raise InputError(f"the mail store refused account {account}: {exc}")
    except OSError as exc:
        raise InputError(f"{gna_store.SPINE} cannot be read ({exc.__class__.__name__}: {exc})")
    except Exception as exc:
        raise InputError(f"the mail store could not be read for {account} "
                         f"({exc.__class__.__name__}: {exc})")
    gna_desk.mark_answered(every)
    columns: dict[str, list] = {"needs_you": [], "unsure": [], "waiting": [], "done": []}
    for record in every:
        if (record.get("direction") or "in") != "in":
            continue
        columns[gna_desk.column_of(record)].append(gna_desk.row(record))
    return columns


def _mail_item(account: str, row: dict) -> dict:
    sender = row.get("from") or {}
    who = (sender.get("name") or "").strip() or (sender.get("email") or "").strip() or "someone"
    subject = re.sub(r"\s+", " ", str(row.get("subject") or "")).strip() or "(no subject)"
    column = row.get("column") or "needs_you"
    action = str(row.get("proposed_action") or "").strip()
    ident = str(row.get("id") or "")
    source = f"mail:{account}"
    shape = "errand" if column == "needs_you" else "line"
    unblocks = {
        "reply_needed": "the reply he owes",
        "schedule_meeting": "the meeting that waits on a time",
        "create_card": "the work the letter asks for",
    }.get(action, "his read")
    # A needs-you row is work the house can carry; an unsure row is his read first. Both are lines.
    title = f"Answer {who} — {subject}" if action in ("reply_needed", "schedule_meeting") \
        else f"{who} — {subject}"
    return {
        "source": source,
        "id": ident,
        "key": key_of(source, ident),
        "shape": shape,
        "title": title[:160],
        "why": f"mail:{column} · {action or 'unclassified'} · unblocks: {unblocks}"
               + (f" · their last word {row.get('received_at')}" if row.get("received_at") else ""),
        "sort": str(row.get("received_at") or ""),
        "column": column,
        "action": action,
    }


def mail_items(H: Path, hours: int) -> tuple[list[dict], dict]:
    """Every needs-you/unsure row across the declared accounts, and which road answered."""
    gna_store, gna_desk = _mail_modules(H)
    accounts = _accounts(gna_store)
    if not accounts:
        return [], {"state": "not configured", "road": "-", "accounts": [],
                    "why": f"no {gna_store.ACCOUNTS.name} in the home — mail is not configured on this seat"}
    url = os.environ.get("GNA_DESK_URL", "http://127.0.0.1:8494").strip()
    token = _desk_token(H) if url else ""
    desk_state, roads, items = "not asked", {}, []
    if not url:
        desk_state = "disabled (GNA_DESK_URL is empty)"
    elif not token:
        desk_state = "no token (hodd/state/gna-desk.token)"
    for account in accounts:
        columns, road = None, "store"
        if url and token:
            try:
                columns, road = _desk_columns(url, token, account, hours), "desk"
                desk_state = "answered"
            except Exception as exc:
                desk_state = f"did not answer ({exc.__class__.__name__})"
        if columns is None:
            columns = _store_columns(gna_store, gna_desk, account, hours)
            road = "store" + ("" if desk_state.startswith(("disabled", "no token", "answered")) else "")
        roads[account] = road
        for column in ("needs_you", "unsure"):
            for row in columns.get(column) or []:
                if not row.get("id"):
                    raise InputError(f"a mail row in {account} carries no id — the key cannot be built")
                items.append(_mail_item(account, row | {"column": column}))
    used = sorted(set(roads.values())) or ["-"]
    road = "desk" if used == ["desk"] else ("store" if used == ["store"] else "mixed")
    return items, {"state": "read", "road": road, "accounts": accounts,
                   "desk": desk_state, "roads": roads}


ASK = re.compile(r"\bneeds-decision\b")
LOCK_ASK = re.compile(r"\block-ask\b")
QUESTION = re.compile(r"\bq=(.*)$")
AT_STAMP = re.compile(r"\bat=(\d{4}-\d{2}-\d{2}T[0-9:.+-]+Z?)")
LEAD_STAMP = re.compile(r"^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})(?::\d{2})?")
LEAD_PREFIX = re.compile(r"^\d{4}-\d{2}-\d{2}[ T][0-9:]{5,8}\s*[A-Z]{0,5}\s*[—-]?\s*")
CLOCK = re.compile(r"\d{1,}")


def _parse_stamp(text: str) -> dt.datetime | None:
    try:
        stamp = dt.datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        return None
    return stamp if stamp.tzinfo else stamp.replace(tzinfo=dt.timezone.utc)


def _lead_stamp(line: str) -> dt.datetime | None:
    """The queue's human clock (`2026-11-16 16:20 EET — …`), read as UTC.

    A two-hour skew can only widen the window slightly during daylight saving, which is the safe
    direction: the alternative was reading a ten-day-old decision as incoming work."""
    match = LEAD_STAMP.match(line)
    if not match:
        return None
    return _parse_stamp(f"{match.group(1)}T{match.group(2)}:00+00:00")


def decision_identity(line: str) -> tuple[str, str]:
    """A decision's identity: its words with the clock and the numbers folded.

    The same worker asking the same question twice is ONE decision, and a lock-ask's id is a poll
    timestamp, never an identity — using it would make every poll a new item, which is exactly the
    duplicate proposal the key exists to prevent."""
    stable = re.sub(r"\s+", " ", CLOCK.sub("#", line)).strip()
    return "ask-" + hashlib.sha256(stable.encode("utf-8")).hexdigest()[:12], stable


def wake_items(path: Path, tail: int, hours: int) -> tuple[list[dict], dict]:
    """The decisions the durable wake queue is holding, inside the window.

    ONLY `needs-decision` is proposed. A `lock-ask` is addressed to whoever holds the arm and the arm
    drains it; putting it on the Allfather's list would duplicate a queue that already has an owner
    and bury his own work under a poll. Notices are not asks at all. And an ask older than the window
    is archaeology, not incoming work — the queue is append-only."""
    info = {"state": "absent", "path": str(path), "lines": 0, "asks": 0, "stale": 0,
            "lock_asks": 0, "notices": 0}
    if not path.exists():
        return [], info
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise InputError(f"{path} cannot be read ({exc.__class__.__name__}: {exc})")
    except UnicodeDecodeError as exc:
        raise InputError(f"{path} is not readable text ({exc.__class__.__name__})")
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()][-tail:]
    cutoff = now() - dt.timedelta(hours=hours)
    items: list[dict] = []
    seen: set[str] = set()
    info.update({"state": "read", "lines": len(lines)})
    for line in lines:
        if LOCK_ASK.search(line) and not ASK.search(line):
            info["lock_asks"] += 1
            continue
        if not ASK.search(line):
            info["notices"] += 1
            continue
        stamp = AT_STAMP.search(line)
        when = _parse_stamp(stamp.group(1)) if stamp else _lead_stamp(line)
        if when and when < cutoff:
            info["stale"] += 1
            continue
        ident, stable = decision_identity(line)
        if ident in seen:
            continue
        seen.add(ident)
        question = re.sub(r"\s+", " ", LEAD_PREFIX.sub("", line)).strip()
        if len(question) > 150:
            question = question[:149].rstrip() + "…"
        items.append({
            "source": "wake",
            "id": ident,
            "key": key_of("wake", ident),
            "shape": "line",
            "title": f"Decide: {question}",
            "why": "wake queue · needs-decision · unblocks: the errand that waits on his word",
            "sort": "",
            "column": "decision",
            "action": "decide",
        })
    info["asks"] = len(items)
    return items, info


# ── the to-do (his half is never touched) ────────────────────────────────────

def read_todo(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        raise StateError(f"{path} cannot be read ({exc.__class__.__name__}: {exc})")


def proposed_keys(text: str) -> set[str]:
    return set(re.findall(r"dispatch-([0-9a-f]{8})\b", text))


def write_proposals(path: Path, text: str, lines: list[str]) -> str:
    """Insert proposal lines between the markers (or open a block at the end). Returns the new text."""
    has_open, has_close = INBOX_OPEN in text, INBOX_CLOSE in text
    if has_open != has_close:
        raise StateError(f"{path} carries half of the dispatch markers — refusing to guess where the "
                         f"block ends")
    body = "".join(line + "\n" for line in lines)
    if has_open:
        at = text.index(INBOX_CLOSE)
        return text[:at] + body + text[at:]
    if not text.endswith("\n"):
        text += "\n"
    return text + "\n" + INBOX_OPEN + "\n" + body + INBOX_CLOSE + "\n"


def atomic_write(path: Path, text: str) -> None:
    tmp = path.with_name(path.name + ".dispatch-tmp")
    try:
        tmp.write_text(text, encoding="utf-8")
        tmp.replace(path)
    except OSError as exc:
        try:
            tmp.unlink()
        except OSError:
            pass
        raise StateError(f"{path} cannot be written ({exc.__class__.__name__}: {exc})")


def proposal_line(item: dict, day: str) -> str:
    return f"- [ ] {day} · proposal · {item['title']} — {item['why']} · dispatch-{item['key'][:8]}"


def already_on_the_list(text: str, item: dict) -> bool:
    """The letter is already asked for somewhere in the file (another door may have proposed it)."""
    needle = re.sub(r"\s+", " ", item["title"]).strip().lower()[:60]
    if not needle:
        return False
    flat = re.sub(r"\s+", " ", re.sub(r"[*`_]", "", text)).lower()
    return needle in flat


# ── the run ─────────────────────────────────────────────────────────────────

def run(args) -> tuple[int, dict]:
    H = home()
    todo_file, ledger_file = todo_path(H), runs_path(H)
    cap, maximum = number("DISPATCH_ATTEMPT_CAP", 3), number("DISPATCH_MAX", 5)
    hours, tail = number("DISPATCH_HOURS", 48), number("DISPATCH_WAKE_TAIL", 200)
    stamp = now()
    run_id = stamp.strftime("%Y%m%dT%H%M%SZ") + "-" + hashlib.sha256(
        f"{stamp.isoformat()}|{os.getpid()}".encode()).hexdigest()[:4]
    base = {"at": iso(stamp), "run": run_id}

    text = read_todo(todo_file)
    prior = fold(read_runs(ledger_file))
    present = proposed_keys(text)

    mail, wake, failure = [], None, ""
    mail_info, wake_info = {"state": "unreadable"}, {"state": "unreadable"}
    try:
        mail, mail_info = mail_items(H, hours)
        wake, wake_info = wake_items(wake_queue(H), tail, hours)
    except InputError as exc:
        failure = str(exc)
        row = base | {"kind": "run", "verdict": "failed", "why": failure, "dry_run": bool(args.dry_run),
                      "proposed": 0, "noop": 0, "refused": 0, "failed": 0}
        if not args.dry_run:
            append_runs(ledger_file, [row])
        return EXIT_INPUT, {
            "ok": False, "mode": "run", "run": run_id, "verdict": "failed", "why": failure,
            "dry_run": bool(args.dry_run),
            "counts": {"proposed": 0, "noop": 0, "refused": 0, "failed": 0},
            "reasons": {"input-unreadable": 1}, "items": [],
            "mail": mail_info if mail_info is not None else {"state": "unreadable"},
            "wake": wake_info if wake_info is not None else {"state": "unreadable"},
            "ledger": str(ledger_file), "to_do": str(todo_file),
        }

    items = sorted(wake + mail, key=lambda it: (it["source"] != "wake", it["sort"]))
    events, plan, counts, reasons = [], [], {"proposed": 0, "noop": 0, "refused": 0, "failed": 0}, {}
    decisions: list[dict] = []

    for item in items:
        key, key8 = item["key"], item["key"][:8]
        state = prior.get(key, {"failed": 0, "proposed": False, "refused": False})
        if state["refused"]:
            verdict, reason = "terminal-failed", "terminal-failed: the attempt cap was spent on this key"
        elif state["failed"] >= cap:
            verdict, reason = "refused", f"attempt-cap: {state['failed']} failed attempt(s), cap {cap}"
            events.append(base | {"kind": "event", "source": item["source"], "item": item["id"],
                                  "key": key, "key8": key8, "verdict": "refused", "reason": reason,
                                  "shape": item["shape"], "dry_run": bool(args.dry_run)})
            counts["refused"] += 1
        elif key8 in present or state["proposed"]:
            verdict, reason = "already-proposed", "already-proposed: the key is already on his list"
        elif already_on_the_list(text, item):
            verdict, reason = "already-proposed", "already-on-the-list: the same letter is already asked for"
        elif len(plan) >= maximum:
            verdict, reason = "deferred", f"cap: this run proposes at most {maximum} (raise with DISPATCH_MAX)"
        else:
            verdict, reason = "propose", "new work for him"
            plan.append(item)
        reasons[reason.split(":")[0]] = reasons.get(reason.split(":")[0], 0) + 1
        decisions.append({"item": item, "verdict": verdict, "reason": reason, "key": key, "key8": key8})

    fail_line = ""
    if plan and not args.dry_run:
        day = stamp.astimezone().strftime("%Y-%m-%d")
        new_text = text
        for item in plan:
            new_text = write_proposals(todo_file, new_text, [proposal_line(item, day)])
        try:
            atomic_write(todo_file, new_text)
        except StateError as exc:
            fail_line = str(exc)
            for item in plan:
                events.append(base | {"kind": "event", "source": item["source"], "item": item["id"],
                                      "key": item["key"], "key8": item["key"][:8],
                                      "verdict": "failed", "reason": fail_line,
                                      "shape": item["shape"], "dry_run": False})
                counts["failed"] += 1
            plan = []
    for item in plan:
        counts["proposed"] += 1
        events.append(base | {"kind": "event", "source": item["source"], "item": item["id"],
                              "key": item["key"], "key8": item["key"][:8], "verdict": "proposed",
                              "reason": "proposed: a line on his list", "shape": item["shape"],
                              "dry_run": bool(args.dry_run)})
    counts["noop"] = len(items) - counts["proposed"] - counts["refused"] - counts["failed"]
    verdict = "work" if counts["proposed"] else ("failed" if fail_line else "no-op")
    if not items:
        reasons.setdefault("no-candidates", 1)

    summary = base | {
        "kind": "run", "verdict": verdict, "dry_run": bool(args.dry_run),
        "proposed": counts["proposed"], "noop": counts["noop"], "refused": counts["refused"],
        "failed": counts["failed"], "reasons": reasons, "mail": mail_info, "wake": wake_info,
        "max": maximum, "cap": cap, "hours": hours,
    }
    if fail_line:
        summary["why"] = fail_line
    if not args.dry_run:
        append_runs(ledger_file, events + [summary])

    rows = [{"item": d["item"], "verdict": d["verdict"], "reason": d["reason"]} for d in decisions]
    return (EXIT_STATE if fail_line else EXIT_RAN), {
        "ok": not fail_line, "mode": "run", "run": run_id, "verdict": verdict,
        "dry_run": bool(args.dry_run), "why": fail_line,
        "counts": counts, "reasons": reasons, "items": rows,
        "mail": mail_info, "wake": wake_info, "ledger": str(ledger_file), "to_do": str(todo_file),
    }


def check(args) -> tuple[int, dict]:
    H = home()
    todo_file, ledger_file, queue = todo_path(H), runs_path(H), wake_queue(H)
    findings: list[dict] = []
    code = EXIT_RAN

    def finding(level: str, surface: str, detail: str, exit_code: int) -> None:
        nonlocal code
        findings.append({"level": level, "surface": surface, "detail": detail})
        if level != "ok" and code == EXIT_RAN:
            code = exit_code

    try:
        text = read_todo(todo_file)
        has_open, has_close = INBOX_OPEN in text, INBOX_CLOSE in text
        if has_open != has_close:
            finding("fail", "his-list", f"{todo_file} carries half of the dispatch markers", EXIT_STATE)
        else:
            finding("ok", "his-list", f"{todo_file} readable, block "
                                  f"{'present' if has_open else 'not yet opened'}, "
                                  f"{len(proposed_keys(text))} proposal(s)", EXIT_RAN)
    except StateError as exc:
        finding("fail", "his-list", str(exc), EXIT_STATE)

    try:
        rows = read_runs(ledger_file)
        runs = [r for r in rows if r.get("kind") == "run"]
        last = runs[-1] if runs else {}
        refused = len([r for r in rows if r.get("kind") == "event" and r.get("verdict") == "refused"])
        finding("ok", "ledger", f"{ledger_file} readable, {len(runs)} run(s), {refused} terminal refusals, "
                               f"last {last.get('at', 'never')} · {last.get('verdict', '-')}", EXIT_RAN)
    except StateError as exc:
        finding("fail", "ledger", str(exc), EXIT_STATE)

    try:
        dict_dir = state_dir(H)
        dict_dir.mkdir(parents=True, exist_ok=True)
        probe = dict_dir / ".write-probe"
        probe.write_text("ok", encoding="utf-8")
        probe.unlink()
        finding("ok", "state", f"{dict_dir} writable", EXIT_RAN)
    except OSError as exc:
        finding("fail", "state", f"{state_dir(H)} is not writable ({exc.__class__.__name__}: {exc})",
                EXIT_STATE)

    try:
        _gna_store, _gna_desk = _mail_modules(H)
        accounts = _accounts(_gna_store)
        if not accounts:
            finding("skip", "mail", "no accounts.yaml — mail is not configured on this seat", EXIT_RAN)
        else:
            rows = _store_columns(_gna_store, _gna_desk, accounts[0], number("DISPATCH_HOURS", 48))
            finding("ok", "mail", f"{len(accounts)} account(s) readable, "
                                  f"{len(rows.get('needs_you') or []) + len(rows.get('unsure') or [])} "
                                  f"needs-you row(s) in {accounts[0]}", EXIT_RAN)
    except InputError as exc:
        finding("fail", "mail", str(exc), EXIT_INPUT)

    try:
        _items, info = wake_items(queue, 1, number("DISPATCH_HOURS", 48))
        if info["state"] == "absent":
            finding("skip", "wake", f"{queue} does not exist (no wake has been queued yet)", EXIT_RAN)
        else:
            finding("ok", "wake", f"{queue} readable ({info['lines']} line(s) read, "
                                  f"{info['stale']} older than the window)", EXIT_RAN)
    except InputError as exc:
        finding("fail", "wake", str(exc), EXIT_INPUT)

    return code, {"ok": code == EXIT_RAN, "mode": "check", "findings": findings}


# ── output ───────────────────────────────────────────────────────────────────

def toon(name: str, fields: list[str], rows: list[list]) -> str:
    def cell(value) -> str:
        if isinstance(value, bool):
            return "true" if value else "false"
        if value is None:
            return '"-"'
        text = str(value).replace('"', "'").replace("\n", " ")
        return f'"{text}"'

    out = [f"{name}[{len(rows)}]{{{','.join(fields)}}}:"]
    for row in rows:
        out.append("  " + ",".join(cell(value) for value in row))
    return "\n".join(out)


def emit(result: dict, as_json: bool, mode: str) -> None:
    if as_json:
        print(json.dumps(result, indent=1, ensure_ascii=False))
        return
    if mode == "check":
        print(toon("dispatch-check", ["level", "surface", "detail"],
                   [[f["level"], f["surface"], f["detail"]] for f in result["findings"]]))
        print(f"verdict: {'ok' if result['ok'] else 'unhealthy'}")
        return
    print(toon("dispatch", ["mode", "run", "verdict", "proposed", "noop", "refused", "failed", "why"],
               [[result["mode"] + (" (dry run)" if result.get("dry_run") else ""), result["run"],
                 result["verdict"], result["counts"]["proposed"], result["counts"]["noop"],
                 result["counts"]["refused"], result["counts"]["failed"],
                 result.get("why") or ", ".join(f"{k} {v}" for k, v in sorted(result["reasons"].items()))]]))
    mail, wake = result["mail"], result["wake"]
    print(toon("sources", ["source", "state", "road", "detail"],
               [["mail", mail.get("state", "-"), mail.get("road", "-"),
                 ", ".join(mail.get("accounts") or []) or mail.get("why", "-")],
                ["wake", wake.get("state", "-"), wake.get("path", "-"),
                 f"{wake.get('lines', 0)} line(s), {wake.get('asks', 0)} decision(s), "
                 f"{wake.get('lock_asks', 0)} lock-ask(s) left to the arm, "
                 f"{wake.get('stale', 0)} older than the window"]]))
    shown = [i for i in result["items"] if i["verdict"] != "already-proposed"][:12]
    if shown:
        print(toon("items", ["verdict", "source", "id", "why"],
                   [[i["verdict"], i["item"]["source"], i["item"]["id"], i["reason"]] for i in shown]))
    if result["ledger"]:
        print(f"ledger: {result['ledger']}")
    if result.get("why"):
        print(f"why: {result['why']}")
    print(f"verdict: {result['verdict']}" + (" (dry run)" if result.get("dry_run") else ""))


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        prog="dispatch.sh", add_help=False,
        description="incoming work becomes a bounded errand or a line on his list")
    parser.add_argument("mode", nargs="?", default="run", choices=["run", "check", "help"])
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("-h", "--help", action="store_true")
    parser.add_argument("--max", type=int)
    parser.add_argument("--hours", type=int)
    args = parser.parse_args(argv)

    if args.help or args.mode == "help":
        print(__doc__.strip())
        return EXIT_RAN
    if args.max is not None:
        if args.max < 0:
            print("error: --max cannot be negative", file=sys.stderr)
            return EXIT_USAGE
        os.environ["DISPATCH_MAX"] = str(args.max)
    if args.hours is not None:
        if args.hours <= 0:
            print("error: --hours must be positive", file=sys.stderr)
            return EXIT_USAGE
        os.environ["DISPATCH_HOURS"] = str(args.hours)
    try:
        if args.check or args.mode == "check":
            code, result = check(args)
            emit(result, args.json, "check")
            return code
        code, result = run(args)
        emit(result, args.json, "run")
        return code
    except InputError as exc:
        detail = str(exc).replace('"', "'")
        print(f'dispatch[1]{{error,exit}}:\n  "input",{EXIT_INPUT}\n  "{detail}"', file=sys.stderr)
        return EXIT_INPUT
    except StateError as exc:
        detail = str(exc).replace('"', "'")
        print(f'dispatch[1]{{error,exit}}:\n  "state",{EXIT_STATE}\n  "{detail}"', file=sys.stderr)
        return EXIT_STATE


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""todo_board — the operator's to-do lives on a board, and this is the one door that writes it.

WHY: the to-do grew into one long Markdown file that several house writers (the voice, the desk agent, the
mail triage) appended to. A file has no states, no dates that sort, no owners and no history of a move, and
two writers fight over it. A board has all four. This door files each to-do as one card on the operator's
private board, through the board's MCP door (Gimlé), with a tool token — never a person's login, never an
admin key.

    todo.sh add "<what>" [--lane L] [--due YYYY-MM-DD] [--owner WHO] [--priority P]
                         [--source S] [--note TEXT] [--key K] [--json]
    todo.sh list [--lane L] [--json]
    todo.sh move <card> <lane>
    todo.sh flush                      # retry what was queued while the board was dark
    todo.sh lanes                      # which lanes are real board states, which ride on a label
    todo.sh migrate [--dry-run] [--json] [--file F]...   # the old list into cards, idempotent, counted
    todo.sh status

Lanes are `Inbox · Today · This week · Waiting · Someday · Done`. Where the board has a state of that name,
the card goes into it. Where it does not (a board still on its default states), the card goes to the
nearest state of the same group and carries the lane as a label — so nothing waits for the states to be
made. Once the states exist, `move` puts a card into its real state and drops the stand-in label.

Configuration (Rule 07, nothing about an installation is written here):
    $YMIR_HOME/config/todo-board.yaml   place, mcp_url, token_file (relative to the home), owners
    env YMIR_TODO_BOARD_PLACE / YMIR_TODO_BOARD_URL / YMIR_TODO_BOARD_TOKEN override it.
Unset means this seat has no board: every verb says `skip` and exits 0, and callers keep their old road.

Records (all under $YMIR_HOME/state/, ignored by the home's git):
    todo-board.jsonl        one line per card this door filed (key -> card): the cache, never the record
    todo-board-queue.jsonl  writes that could not reach the board; `flush` sends them, oldest first

Exit: 0 done (or a clean skip, or queued) · 1 the board refused · 2 usage.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import fcntl
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LANES = ("Inbox", "Today", "This week", "Waiting", "Someday", "Done")
# the board's state groups, so a lane with no state of its own still lands in the right column
LANE_GROUP = {"Inbox": "unstarted", "Today": "unstarted", "This week": "unstarted", "Waiting": "unstarted",
              "Someday": "backlog", "Done": "completed"}
HALF_LABELS = {"his": "his", "derived": "derived", "kept": "house-kept", "voice": "voice", "other": "inbox-other"}
TIMEOUT_S = float(os.environ.get("YMIR_TODO_BOARD_TIMEOUT", "20"))
RATE_TRIES = int(os.environ.get("YMIR_TODO_BOARD_RATE_TRIES", "6"))
META_TTL = float(os.environ.get("YMIR_TODO_BOARD_META_TTL", "600"))


class BoardError(Exception):
    """The board answered, and said no."""


class _RateLimited(Exception):
    def __init__(self, wait: float = 0):
        super().__init__("rate limited")
        self.wait = wait


class BoardDark(Exception):
    """The board did not answer at all (network, door down). A write is queued, never lost."""


# ── where things live ──────────────────────────────────────────────────────────────────────────────────

def home() -> Path:
    """The private home, through the one resolver (bin/vault/hoard-lib.sh ymir_home_root) — never guessed."""
    env = os.environ.get("YMIR_HOME")
    if env:
        return Path(env).expanduser()
    lib = ROOT / "bin" / "vault" / "hoard-lib.sh"
    if lib.exists():
        try:
            out = subprocess.run(["bash", "-c", f'. "{lib}" >/dev/null 2>&1; ymir_home_root H >/dev/null 2>&1; printf %s "$H"'],
                                 capture_output=True, text=True, timeout=10).stdout.strip()
            if out:
                return Path(out)
        except Exception:  # noqa: BLE001
            pass
    raise SystemExit("no home: set YMIR_HOME or run bin/engine/ymir-install.sh (the resolver found none)")


def state_dir() -> Path:
    return Path(os.environ.get("YMIR_STATE_DIR") or (home() / "state"))


def _yaml(path: Path) -> dict:
    if not path.is_file():
        return {}
    try:
        import yaml  # the house has it everywhere; a missing module degrades to "no config"
        return yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except Exception:
        return {}


def config() -> dict:
    cfg = _yaml(home() / "config" / "todo-board.yaml")
    place = os.environ.get("YMIR_TODO_BOARD_PLACE") or cfg.get("place") or ""
    url = os.environ.get("YMIR_TODO_BOARD_URL") or cfg.get("mcp_url") or ""
    token = os.environ.get("YMIR_TODO_BOARD_TOKEN") or ""
    if not token:
        tf = cfg.get("token_file") or "state/todo-board.token"
        tp = Path(tf) if os.path.isabs(tf) else home() / tf
        try:
            token = tp.read_text(encoding="utf-8").strip()
        except OSError:
            token = ""
    return {"place": place, "url": url, "token": token, "owners": cfg.get("owners") or {}}


def configured(cfg: dict) -> str:
    """'' when the door can write; otherwise why it cannot (a clean skip)."""
    if not cfg["place"] or not cfg["url"]:
        return "no board configured ($YMIR_HOME/config/todo-board.yaml: place, mcp_url)"
    if not cfg["token"]:
        return "no tool token (state/todo-board.token, or YMIR_TODO_BOARD_TOKEN)"
    return ""


# ── the board's door (MCP over HTTP, JSON-RPC) ─────────────────────────────────────────────────────────

class Board:
    def __init__(self, cfg: dict, call=None):
        self.cfg = cfg
        self.place = cfg["place"]
        self._call = call or self._http
        self._states = None
        self._labels = None

    def _http(self, name: str, args: dict) -> dict:
        body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                           "params": {"name": name, "arguments": args}}).encode()
        req = urllib.request.Request(self.cfg["url"], data=body, method="POST", headers={
            "Authorization": f"Bearer {self.cfg['token']}", "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            # the edge in front of the door refuses Python's default agent string with a 403 (measured
            # 2026-11-20); a plain client name is let through, and the audit can tell this door apart
            "User-Agent": "ymir-todo-board/1"})
        # Plane limits API calls per minute (HTTP 429, error 5900). A long migration meets it; the door waits
        # and tries again, backing off, instead of refusing the card (measured 2026-11-20: 42 of 129 refused).
        for attempt in range(RATE_TRIES):
            try:
                raw = self._http_once(req)
            except _RateLimited as exc:
                if attempt + 1 >= RATE_TRIES:
                    raise BoardError(f"the board kept refusing for rate (HTTP 429) after {RATE_TRIES} tries")
                time.sleep(exc.wait or min(60, 5 * 2 ** attempt))
                continue
            if "RATE_LIMIT_EXCEEDED" in raw and attempt + 1 < RATE_TRIES:   # the door relays it inside a 200
                time.sleep(min(60, 5 * 2 ** attempt))
                continue
            return self._parse(raw)
        raise BoardError("unreachable")

    def _http_once(self, req):
        try:
            raw = urllib.request.urlopen(req, timeout=TIMEOUT_S).read().decode("utf-8", "replace")
        except urllib.error.HTTPError as exc:
            if exc.code == 429:
                try:
                    wait = float(exc.headers.get("Retry-After") or 0)
                except (TypeError, ValueError):
                    wait = 0
                raise _RateLimited(wait)
            if exc.code in (401, 403):
                raise BoardError(f"the board door refused the token (HTTP {exc.code})")
            if exc.code >= 500:
                raise BoardDark(f"the board door failed (HTTP {exc.code})")
            raise BoardError(f"the board door said HTTP {exc.code}")
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            raise BoardDark(f"the board did not answer: {exc}")
        return raw

    def _parse(self, raw: str) -> dict:
        if raw.startswith("event:") or raw.startswith("data:"):
            raw = next((l[5:].strip() for l in raw.splitlines() if l.startswith("data:")), "{}")
        msg = json.loads(raw or "{}")
        if "error" in msg:
            raise BoardError(str(msg["error"].get("message") or msg["error"]))
        res = msg.get("result") or {}
        text = "".join(c.get("text", "") for c in res.get("content") or [] if c.get("type") == "text")
        try:
            data = json.loads(text) if text else {}
        except ValueError:
            data = {"text": text}
        if res.get("isError"):
            raise BoardError(data.get("error") or data.get("text") or text or "refused")
        return data

    def call(self, tool: str, **args) -> dict:
        return self._call(tool, dict(args, place=self.place) if tool not in ("who_am_i",) else args)

    # States and labels are read once and remembered for META_TTL seconds in state/todo-board-meta.json:
    # one round trip to the door costs ~0.65 s (measured 2026-11-20), and a spoken to-do must land within
    # about a second, so an add is ONE call when the meta is warm. A refusal naming a label or state forgets
    # the meta and the add is tried once more against a fresh read.
    def _meta_path(self) -> Path:
        return state_dir() / "todo-board-meta.json"

    def _meta(self) -> dict:
        if getattr(self, "_meta_cache", None) is None:
            self._meta_cache = {}
            if self._call == self._http:   # an injected (test) board is never cached on disk
                try:
                    m = json.loads(self._meta_path().read_text(encoding="utf-8"))
                    if m.get("place") == self.place and _dt.datetime.now().timestamp() - m.get("at", 0) < META_TTL:
                        self._meta_cache = m
                except (OSError, ValueError):
                    pass
        return self._meta_cache

    def _save_meta(self):
        if self._call != self._http:
            return
        try:
            m = {"place": self.place, "at": _dt.datetime.now().timestamp(), "states": self._states,
                 "labels": sorted(self._labels or [])}
            self._meta_path().parent.mkdir(parents=True, exist_ok=True)
            tmp = self._meta_path().with_suffix(".tmp")
            tmp.write_text(json.dumps(m), encoding="utf-8")
            os.replace(tmp, self._meta_path())
        except OSError:
            pass

    def forget(self):
        self._states = self._labels = None
        self._meta_cache = {}
        try:
            self._meta_path().unlink()
        except OSError:
            pass

    def states(self) -> list:
        if self._states is None:
            m = self._meta()
            if m.get("states") is not None:
                self._states = m["states"]
            else:
                self._states = self.call("list_states").get("states") or []
                self.labels()
                self._save_meta()
        return self._states

    def labels(self) -> set:
        if self._labels is None:
            m = self._meta()
            if m.get("labels") is not None:
                self._labels = set(m["labels"])
            else:
                rows = self.call("list_labels").get("labels") or []
                self._labels = {(r.get("name") if isinstance(r, dict) else str(r)) for r in rows}
        return self._labels

    def ensure_label(self, name: str):
        if name and name not in self.labels():
            self.call("create_label", name=name)
            self._labels.add(name)
            self._save_meta()

    def state_for(self, lane: str) -> tuple[str, bool]:
        """(state name, is_real): the lane's own state when the board has it, else its group's first state."""
        sts = self.states()
        for s in sts:
            if str(s.get("name", "")).casefold() == lane.casefold():
                return s["name"], True
        group = LANE_GROUP.get(lane, "unstarted")
        for s in sts:
            if s.get("group") == group:
                return s["name"], False
        return (sts[0]["name"] if sts else ""), False


# ── the cache and the queue ────────────────────────────────────────────────────────────────────────────

class _Locked:
    def __init__(self, path: Path):
        self.path = path

    def __enter__(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.fh = open(str(self.path) + ".lock", "a")
        fcntl.flock(self.fh.fileno(), fcntl.LOCK_EX)
        return self

    def __exit__(self, *exc):
        fcntl.flock(self.fh.fileno(), fcntl.LOCK_UN)
        self.fh.close()


def _jsonl(path: Path) -> list:
    if not path.is_file():
        return []
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            rows.append(json.loads(line))
        except ValueError:
            continue
    return rows


def _append(path: Path, row: dict):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, ensure_ascii=False) + "\n")
        fh.flush()
        os.fsync(fh.fileno())


def cache_path() -> Path:
    return state_dir() / "todo-board.jsonl"


def queue_path() -> Path:
    return state_dir() / "todo-board-queue.jsonl"


def cached(key: str) -> dict | None:
    for row in reversed(_jsonl(cache_path())):
        if row.get("key") != key:
            continue
        if row.get("deleted"):          # a card deleted on the board: the next add files it afresh
            return None
        if row.get("card"):
            return row
    return None


def _now() -> str:
    return _dt.datetime.now().astimezone().isoformat(timespec="seconds")


# ── one card ───────────────────────────────────────────────────────────────────────────────────────────

def make_key(title: str, source: str = "") -> str:
    return "todo-" + hashlib.sha1(f"{source}\n{title}".encode()).hexdigest()[:12]


# The board's provenance shape (Gimlé's create_card: `source: <path>#<id>`, one token each side, no spaces). A to-do's
# own `source` is often prose ("the command line", "<file> · line 12 · <trail>"), so the anchor is derived from it:
# the shape as given, else "<file>#L<line>", else "<record>#<id>", else the to-do door with the card's key.
SOURCE_SHAPE = re.compile(r"^[^\s#]+#[^\s#]+$")


def card_source(item: dict) -> str:
    src = str(item.get("source") or "").strip()
    key = item.get("key") or make_key(str(item.get("title", "")), src)
    if SOURCE_SHAPE.match(src):
        return src
    m = re.match(r"^(\S+) · line (\d+)\b", src)
    if m and "#" not in m.group(1):
        return f"{m.group(1)}#L{m.group(2)}"
    m = re.search(r"record (\S+), id ([^\s#)]+)\)", src)
    if m and "#" not in m.group(1):
        return f"{m.group(1)}#{m.group(2)}"
    first = src.split()[0] if src else ""
    if first and "#" not in first and ("/" in first or "." in first):
        return f"{first}#{key}"
    return f"bin/records/todo.sh#{key}"


def describe(item: dict) -> str:
    parts = []
    if item.get("note"):
        parts.append(item["note"].rstrip())
        parts.append("")
    meta = [("source", item.get("source")), ("lane", item.get("lane")), ("owner", item.get("owner")),
            ("due", item.get("due")), ("key", item.get("key"))]
    parts += [f"{k}: {v}" for k, v in meta if v]
    return "\n".join(parts).strip()


def file_card(board: Board, item: dict) -> dict:
    """Create one card (or find it already filed). Returns {verdict, card, ...}. Raises BoardDark/BoardError."""
    item = dict(item)
    lane = item.get("lane") or "Inbox"
    if lane not in LANES:
        raise BoardError(f"no lane {lane!r}; the lanes are {', '.join(LANES)}")
    item["lane"] = lane
    item.setdefault("key", make_key(item["title"], item.get("source", "")))
    hit = cached(item["key"])
    if hit:
        return {"verdict": "exists", "card": hit["card"], "title": hit.get("title"), "key": item["key"]}
    state, real = board.state_for(lane)
    labels = list(item.get("labels") or [])
    if not real:
        labels.append(lane)
    for name in labels:
        board.ensure_label(name)
    args = {"title": item["title"][:250], "description": describe(item), "source": card_source(item)}
    if state:
        args["state"] = state
    if labels:
        args["labels"] = labels
    if item.get("due"):
        args["due"] = item["due"]
    if item.get("priority") in ("urgent", "high", "medium", "low"):
        args["priority"] = item["priority"]
    owner = item.get("owner") or ""
    member = (board.cfg.get("owners") or {}).get(owner, owner) if owner else ""
    if member:
        args["assignees"] = [member]
    try:
        try:
            out = board.call("create_card", **args)
        except BoardError as exc:
            if not re.search(r"label|state", str(exc), re.I):
                raise
            board.forget()                      # the remembered meta was stale: read it fresh, try once more
            state, real = board.state_for(lane)
            for name in labels:
                board.ensure_label(name)
            if state:
                args["state"] = state
            out = board.call("create_card", **args)
    except BoardError as exc:
        if member and ("assign" in str(exc).lower() or member in str(exc)):
            args.pop("assignees", None)   # an owner the board does not know stays in the description
            out = board.call("create_card", **args)
        else:
            raise
    made = out.get("created") if isinstance(out.get("created"), dict) else out   # the door answers {"created": {...}}
    card = made.get("card") or made.get("sequence_id") or made.get("number")
    if not card:
        raise BoardError(f"the board filed nothing it could name: {json.dumps(out)[:200]}")
    with _Locked(cache_path()):
        _append(cache_path(), {"ts": _now(), "key": item["key"], "card": card, "title": item["title"],
                               "lane": lane, "state": state, "source": item.get("source", "")})
    return {"verdict": "filed", "card": card, "title": item["title"], "key": item["key"], "state": state,
            "lane": lane}


def add(item: dict, board: Board | None = None) -> dict:
    cfg = board.cfg if board else config()
    why = configured(cfg)
    if why:
        return {"verdict": "skip", "why": why}
    board = board or Board(cfg)
    item.setdefault("key", make_key(item["title"], item.get("source", "")))
    try:
        return file_card(board, item)
    except BoardDark as exc:
        with _Locked(queue_path()):
            _append(queue_path(), {"ts": _now(), "item": item, "why": str(exc)})
        return {"verdict": "queued", "key": item["key"], "why": str(exc)}


def flush(board: Board | None = None) -> dict:
    cfg = board.cfg if board else config()
    why = configured(cfg)
    if why:
        return {"verdict": "skip", "why": why}
    board = board or Board(cfg)
    with _Locked(queue_path()):
        rows = _jsonl(queue_path())
        left, sent = [], []
        for row in rows:
            try:
                sent.append(file_card(board, row["item"]))
            except BoardDark as exc:
                row["why"] = str(exc)
                left.append(row)
        tmp = queue_path().with_suffix(".tmp")
        tmp.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in left), encoding="utf-8")
        os.replace(tmp, queue_path())
    return {"verdict": "flushed", "sent": len(sent), "left": len(left)}


# ── the old list, read ─────────────────────────────────────────────────────────────────────────────────

_HALVES = (("His half", "his"), ("The derived half", "derived"), ("The house-kept half", "kept"))
_BOX = re.compile(r"^- \[( |x|X)\] (.*)$")


def _half(heading: str) -> str:
    for prefix, name in _HALVES:
        if heading.startswith(prefix):
            return name
    return "other"


def _lane(section: str, done: bool) -> str:
    if done:
        return "Done"
    s = section.strip().lower()
    if s == "today":
        return "Today"
    if s == "this week":
        return "This week"
    if s.startswith("waiting"):
        return "Waiting"
    if s.startswith("held"):
        return "Someday"
    return "Inbox"


def _title(text: str) -> str:
    m = re.match(r"^\*\*(.+?)\*\*", text)
    t = m.group(1) if m else text
    t = re.sub(r"[*`]", "", t).strip()
    return t if len(t) <= 200 else t[:197].rstrip() + "…"


def parse_markdown(path: Path, rel: str) -> list:
    """Every `- [ ]` / `- [x]` line is one item; its indented continuation lines belong to it, verbatim."""
    lines = path.read_text(encoding="utf-8").splitlines()
    items, half, h1, h2, h3 = [], "other", "", "", ""
    n = 0
    while n < len(lines):
        line = lines[n]
        if line.startswith("# "):
            h1, h2, h3 = line[2:].strip(), "", ""
            half = _half(h1)
        elif line.startswith("## "):
            h2, h3 = line[3:].strip(), ""
        elif line.startswith("### "):
            h3 = line[4:].strip()
        m = _BOX.match(line)
        if not m:
            n += 1
            continue
        body = [line]
        k = n + 1
        while k < len(lines) and lines[k].startswith("      ") and not lines[k].lstrip().startswith("- ["):
            body.append(lines[k])
            k += 1
        done = m.group(1) in "xX"
        text = " ".join([m.group(2)] + [b.strip() for b in body[1:]])
        section = h2 or h1
        # the lane comes from the nearest heading that names one (a "### Waiting on you" under a dated "##")
        lane = _lane(h3, done) if h3 and _lane(h3, done) != "Inbox" else _lane(section, done)
        due = ""
        dm = re.search(r"\bdue (\d{4}-\d{2}-\d{2})\b", text)
        if dm:
            due = dm.group(1)
        pm = re.search(r"\bpriority (urgent|high|medium|low)\b", text)
        trail = " › ".join(x for x in (h1, h2, h3) if x)
        items.append({
            "title": _title(m.group(2)),
            "note": "\n".join(body),
            "lane": lane,
            "status": "done" if done else "open",
            "due": due,
            "priority": pm.group(1) if pm else "",
            "labels": [HALF_LABELS[half]],
            "source": f"{rel} · line {n + 1} · {trail}",
            "key": "todo-" + hashlib.sha1(f"{rel}\n{m.group(2)}".encode()).hexdigest()[:12],
        })
        n = k
    return items


def parse_voice(path: Path, rel: str, view: str) -> list:
    """The voice's record (append-only events) replayed to its current state — the view is only a render of it."""
    tasks, order = {}, []
    for ev in _jsonl(path):
        tid = str(ev.get("id") or "")
        if not tid:
            continue
        a = ev.get("action")
        if a == "add":
            tasks[tid] = dict(ev, status="open")
            order.append(tid)
        elif tid in tasks:
            if a == "done":
                tasks[tid]["status"] = "done"
            elif a == "reopen":
                tasks[tid]["status"] = "open"
            elif a == "update":
                tasks[tid].update({k: ev[k] for k in ("due", "priority", "project", "item") if ev.get(k)})
    items = []
    for tid in order:
        t = tasks[tid]
        done = t["status"] == "done"
        note = json.dumps({k: t.get(k) for k in ("ts", "id", "item", "due", "priority", "project")},
                          ensure_ascii=False)
        items.append({
            "title": _title(str(t.get("item", ""))),
            "note": f"{t.get('item', '')}\nrecord: {note}",
            "lane": "Done" if done else "Inbox",
            "status": "done" if done else "open",
            "due": t.get("due") or "",
            "priority": t.get("priority") or "",
            "labels": [HALF_LABELS["voice"]],
            "source": f"{view} (record {rel}, id {tid})",
            "key": f"todo-voice-{tid}",
        })
    return items


def default_sources() -> list:
    h = home()
    me = h / "hodd" / "life" / "personal" / "me"
    return [("md", me / "todo.md", "hodd/life/personal/me/todo.md"),
            ("voice", h / "hodd" / "state" / "voice" / "todos.jsonl", "hodd/state/voice/todos.jsonl")]


def read_items(sources=None) -> list:
    items = []
    for kind, path, rel in sources or default_sources():
        if not path.is_file():
            continue
        if kind == "md":
            items += parse_markdown(path, rel)
        else:
            items += parse_voice(path, rel, "hodd/life/personal/me/todo-voice.md")
    return items


def migrate(board: Board | None, sources=None, dry_run: bool = False) -> dict:
    items = read_items(sources)
    seen, dupes = set(), 0
    unique = []
    for it in items:
        if it["key"] in seen:
            dupes += 1
            continue
        seen.add(it["key"])
        unique.append(it)
    count_in = {"open": sum(1 for i in unique if i["status"] == "open"),
                "done": sum(1 for i in unique if i["status"] == "done")}
    report = {"in": count_in, "items": len(unique), "same_text_twice": dupes, "filed": 0, "exists": 0,
              "queued": 0, "failed": []}
    if dry_run:
        report["plan"] = [{"title": i["title"], "lane": i["lane"], "due": i["due"], "source": i["source"]}
                          for i in unique]
        return report
    if board is None:
        cfg = config()
        why = configured(cfg)
        if why:
            return dict(report, verdict="skip", why=why)
        board = Board(cfg)
    out = {"open": 0, "done": 0}
    for it in unique:
        try:
            r = add(dict(it), board)
        except BoardError as exc:
            report["failed"].append({"title": it["title"], "why": str(exc)})
            continue
        report[r["verdict"]] = report.get(r["verdict"], 0) + 1
        if r["verdict"] in ("filed", "exists"):
            out[it["status"]] += 1
    report["out"] = out
    report["whole"] = out == count_in
    return report


# ── the face ───────────────────────────────────────────────────────────────────────────────────────────

def _say(obj: dict, as_json: bool):
    if as_json:
        print(json.dumps(obj, ensure_ascii=False, indent=2))
        return
    v = obj.get("verdict", "")
    if v == "skip":
        print(f"todo: skip — {obj['why']}")
    elif v == "filed":
        print(f"todo: filed #{obj['card']} in {obj.get('state')} ({obj.get('lane')}): {obj['title']}")
    elif v == "exists":
        print(f"todo: exists #{obj['card']}: {obj.get('title')}")
    elif v == "moved":
        print(f"todo: moved #{obj['card']} to {obj.get('lane')} (state {obj.get('state')})")
    elif v == "queued":
        print(f"todo: queued (the board is dark; `todo.sh flush` sends it): {obj['why']}")
    else:
        print(json.dumps(obj, ensure_ascii=False))


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="todo.sh", description="the operator's to-do, as cards on the board")
    sub = p.add_subparsers(dest="verb")
    a = sub.add_parser("add")
    a.add_argument("title")
    a.add_argument("--lane", default="Inbox")
    a.add_argument("--due", default="")
    a.add_argument("--owner", default="")
    a.add_argument("--priority", default="")
    a.add_argument("--source", default="the command line")
    a.add_argument("--note", default="")
    a.add_argument("--key", default="")
    a.add_argument("--label", action="append", default=[])
    a.add_argument("--json", action="store_true")
    ls = sub.add_parser("list")
    ls.add_argument("--lane", default="")
    ls.add_argument("--json", action="store_true")
    mv = sub.add_parser("move")
    mv.add_argument("card")
    mv.add_argument("lane")
    mv.add_argument("--json", action="store_true")
    sub.add_parser("flush")
    sub.add_parser("lanes")
    sub.add_parser("status")
    mg = sub.add_parser("migrate")
    mg.add_argument("--dry-run", action="store_true")
    mg.add_argument("--json", action="store_true")
    o = p.parse_args(argv)
    if not o.verb:
        p.print_help(sys.stderr)
        return 2

    cfg = config()
    why = configured(cfg)
    if o.verb == "status":
        q = len(_jsonl(queue_path()))
        print(json.dumps({"place": cfg["place"] or None, "door": cfg["url"] or None, "token": bool(cfg["token"]),
                          "ready": not why, "why": why or None, "filed": len(_jsonl(cache_path())),
                          "queued": q}, indent=2))
        return 0
    if o.verb == "migrate":
        rep = migrate(None, dry_run=o.dry_run)
        if o.json or o.dry_run:
            print(json.dumps(rep, ensure_ascii=False, indent=2))
        else:
            print(f"todo migrate: in {rep['in']} · out {rep.get('out')} · filed {rep['filed']} · exists "
                  f"{rep['exists']} · queued {rep['queued']} · failed {len(rep['failed'])} · whole {rep.get('whole')}")
        return 0 if not rep["failed"] else 1
    if why:
        _say({"verdict": "skip", "why": why}, getattr(o, "json", False))
        return 0
    board = Board(cfg)
    try:
        if o.verb == "add":
            if o.lane not in LANES:
                print(f"todo: no lane {o.lane!r}; the lanes are {', '.join(LANES)}", file=sys.stderr)
                return 2
            item = {"title": o.title, "lane": o.lane, "due": o.due, "owner": o.owner, "priority": o.priority,
                    "source": o.source, "note": o.note, "labels": o.label}
            if o.key:
                item["key"] = o.key
            _say(add(item, board), o.json)
            return 0
        if o.verb == "flush":
            print(json.dumps(flush(board)))
            return 0
        if o.verb == "lanes":
            rows = []
            for lane in LANES:
                st, real = board.state_for(lane)
                rows.append({"lane": lane, "state": st, "real_state": real, "label": None if real else lane})
            print(json.dumps(rows, ensure_ascii=False, indent=2))
            return 0
        if o.verb == "list":
            args = {"limit": 200}
            if o.lane:
                st, real = board.state_for(o.lane)
                args.update({"state": st} if real else {"label": o.lane})
            out = board.call("list_cards", **args)
            if o.json:
                print(json.dumps(out, ensure_ascii=False, indent=2))
            else:
                for c in out.get("cards") or []:
                    print(f"#{c['card']:<5} {c.get('state', ''):<12} {c.get('due') or '':<10} {c['title'][:90]}")
                print(f"count: {out.get('count', len(out.get('cards') or []))}")
            return 0
        if o.verb == "move":
            if o.lane not in LANES:
                print(f"todo: no lane {o.lane!r}; the lanes are {', '.join(LANES)}", file=sys.stderr)
                return 2
            st, real = board.state_for(o.lane)
            args = {"card": o.card, "state": st}
            if not real:
                board.ensure_label(o.lane)
                args["add_labels"] = [o.lane]
            others = [l for l in LANES if l != o.lane and l in board.labels()]
            if others:
                args["remove_labels"] = others
            out = board.call("update_card", **args)
            _say({"verdict": "moved", **out} if o.json else {"verdict": "moved", "card": o.card, "lane": o.lane,
                                                                 "state": st}, o.json)
            return 0
    except BoardDark as exc:
        print(f"todo: the board is dark — {exc}", file=sys.stderr)
        return 1
    except BoardError as exc:
        print(f"todo: the board refused — {exc}", file=sys.stderr)
        return 1
    return 2


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""night_report.py — what the fleet did overnight, written for the operator to read in the morning.

The door is `bin/day/night-report.sh`; this file is its logic (stdlib only, PyYAML when present).

For one window (default: since the last report, or since 22:00 local yesterday when there is none), it
gathers from the home and from GitHub, across every seat:

  errands done          state/<id>.status ends in `done:` (with the PR link the status or report names)
  errands not done      failed · needs-decision · blocked · paused · false-done · stuck (silent 2h+)
  PRs merged            every repository the project registry names, plus `--repo` extras
  PRs open, and why     red gate · gate running · conflict · rework asked · draft · on hold · green
  alarms and mends      the Runes ledger: notify rows at HIGH/CRITICAL, and every `mend` row
  waiting on him        the open cards of his half of his to-do (the board, through
                        bin/records/todo.sh), oldest first, the open `decision` cards on the
                        project boards, and the voice ledger's open items

His to-do lives on the board since 2026-11-20, and `bin/records/todo.sh` is the ONE door to it.
The report reads it with `todo.sh list --json` and closes a card where the work is PROVEN done:
an open card whose subject names exactly one PR, and that PR merged — or exactly one errand, and
that errand ended `done` with its PR merged (or with no PR named) — is moved with
`todo.sh move <card> Done`, and the dated proof is written in the report. A card's words are never
rewritten. When the board is not configured on this seat, the retired file
life/personal/me/todo.md is READ (never written) and nothing is closed; the report says so.
Every line of the report names its source.

Without --dry-run it writes hodd/docs/status/YYYY-MM-DD-night-report.md (a second run the same day
appends a section), appends one line to the daily log, ships the paths through
bin/vault/home-sync.sh, and sends ONE Telegram message through bin/notify/send.sh.
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import datetime as dt
import hashlib
import json
import os
import re
import socket
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
import night_seat  # noqa: E402

REPORT_DIR = Path("hodd/docs/status")
TODO = Path("life/personal/me/todo.md")  # retired 2026-11-20: read as a fallback, never written
TODO_DOOR = ROOT / "bin/records/todo.sh"
CLOSED_STATES = ("done", "cancelled", "canceled", "completed")
RUNES = Path("hodd/memory/runes_audit.md")
DAILY = Path("hodd/memory/daily")
LAST = Path("state/night-report.last")
VOICE = Path("state/voice/todos.jsonl")
DATE_RE = re.compile(r"\b(20\d\d-\d\d-\d\d)\b")
GREEN_WORDS = ("green, waiting for review", "green and approved — ready to merge")


# ── small helpers ─────────────────────────────────────────────────────────────────────────────

def clip(text, n=120):
    text = " ".join(str(text or "").split())
    return text if len(text) <= n else text[: n - 1].rstrip() + "…"


def plain(text):
    return re.sub(r"[*`_]", "", text or "")


def local(ts):
    return dt.datetime.fromtimestamp(ts).astimezone()


def hhmm(ts):
    return local(ts).strftime("%H:%M")


def iso_to_epoch(s):
    if not s:
        return None
    try:
        return dt.datetime.fromisoformat(str(s).replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None


def default_since(now, home):
    """The last report's time when it is recent, else 22:00 local the day before `now`."""
    try:
        last = float((home / LAST).read_text().strip())
        if now - 72 * 3600 <= last < now:
            return last
    except (OSError, ValueError):
        pass
    day = local(now).date() - dt.timedelta(days=1)
    return dt.datetime.combine(day, dt.time(22, 0)).astimezone().timestamp()


def parse_when(s, now):
    if s is None:
        return None
    try:
        return float(s)
    except ValueError:
        pass
    t = iso_to_epoch(s)
    if t is None:
        t = dt.datetime.fromisoformat(s).astimezone().timestamp()
    return t


# ── the seats ─────────────────────────────────────────────────────────────────────────────────

def me():
    return os.environ.get("YMIR_NIGHT_MACHINE") or socket.gethostname().split(".")[0].lower()


def fleet_roads(home):
    """[(machine, user@tailnet)] for every other seat that can carry errands (not a hand, not dark)."""
    try:
        hosts = json.loads((home / "hodd/data/fleet.json").read_text()).get("hosts") or {}
    except (OSError, ValueError):
        return []
    roads = []
    for name, h in sorted(hosts.items()):
        if name == me() or not isinstance(h, dict):
            continue
        roles = h.get("roles") or []
        if roles == ["hand"] or h.get("state") == "dark":
            continue
        if h.get("user") and h.get("tailnet"):
            roads.append((name, f"{h['user']}@{h['tailnet']}"))
    return roads


def read_remote(name, road, since, now):
    src = (HERE / "night_seat.py").read_text()
    cmd = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=6", road,
           f"python3 - --since {int(since)} --now {int(now)} --machine {name}"]
    try:
        p = subprocess.run(cmd, input=src, capture_output=True, text=True, timeout=40)
    except (OSError, subprocess.TimeoutExpired) as e:
        return None, f"no answer ({type(e).__name__})"
    if p.returncode != 0:
        return None, f"no answer (ssh exit {p.returncode})"
    try:
        return json.loads(p.stdout), ""
    except ValueError:
        return None, "answered, but not with the seat's record"


def gather_seats(home, since, now, fleet=True):
    seats = [night_seat.gather(home, since, now, me())]
    unheard = []
    if fleet:
        roads = fleet_roads(home)
        with cf.ThreadPoolExecutor(max_workers=6) as ex:
            futs = {ex.submit(read_remote, n, r, since, now): n for n, r in roads}
            for f in cf.as_completed(futs):
                data, why = f.result()
                if data:
                    seats.append(data)
                else:
                    unheard.append((futs[f], why))
    errands = []
    for s in seats:
        for e in s.get("errands", []):
            e["machine"] = s.get("machine", "?")
            errands.append(e)
    return errands, [s.get("machine") for s in seats], sorted(unheard)


# ── GitHub ────────────────────────────────────────────────────────────────────────────────────

class GitHub:
    """`gh`, or a fixture standing in for it (tests)."""

    def __init__(self, fixture=None):
        self.fx = json.loads(Path(fixture).read_text()) if fixture else None

    def _gh(self, args, tries=3):
        err = ""
        for n in range(tries):  # the network drops a call now and then; a second asking usually answers
            try:
                p = subprocess.run(["gh"] + args, capture_output=True, text=True, timeout=45)
            except subprocess.TimeoutExpired:
                err = "gh timed out"
            else:
                if p.returncode == 0:
                    return json.loads(p.stdout or "null")
                err = clip(p.stderr or f"gh exit {p.returncode}", 100)
            time.sleep(2 * (n + 1))
        raise RuntimeError(err)

    def can_push(self, repo):
        if self.fx is not None:
            return repo in (self.fx.get("repos") or {})
        try:
            perm = self._gh(["repo", "view", repo, "--json", "viewerPermission", "-q", "{p: .viewerPermission}"])
        except (RuntimeError, ValueError, subprocess.TimeoutExpired):
            return False
        return (perm or {}).get("p") in ("ADMIN", "MAINTAIN", "WRITE")

    def merged(self, repo, since):
        if self.fx is not None:
            return (self.fx["repos"].get(repo) or {}).get("merged", [])
        stamp = dt.datetime.fromtimestamp(since, dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        return self._gh(["pr", "list", "--repo", repo, "--state", "merged", "--limit", "100",
                         "--search", f"merged:>={stamp}", "--json", "number,title,url,mergedAt"]) or []

    def open(self, repo):
        if self.fx is not None:
            return (self.fx["repos"].get(repo) or {}).get("open", [])
        return self._gh(["pr", "list", "--repo", repo, "--state", "open", "--limit", "100", "--json",
                         "number,title,url,isDraft,reviewDecision,mergeable,labels,statusCheckRollup,updatedAt"]) or []

    def state(self, repo, number):
        if self.fx is not None:
            return (self.fx.get("pr_state") or {}).get(f"{repo}#{number}")
        try:
            return self._gh(["pr", "view", str(number), "--repo", repo, "--json", "state,mergedAt,url"])
        except (RuntimeError, ValueError, subprocess.TimeoutExpired):
            return None


def origin_repo():
    try:
        url = subprocess.run(["git", "-C", str(ROOT), "remote", "get-url", "origin"], capture_output=True,
                             text=True, timeout=10).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""
    m = re.search(r"github\.com[:/]([\w.-]+/[\w.-]+?)(?:\.git)?$", url)
    return m.group(1) if m else ""


def registry(home):
    try:
        import yaml  # noqa: PLC0415
    except ImportError:
        return []
    try:
        d = yaml.safe_load((home / "hodd/identity/projects.yaml").read_text()) or {}
    except (OSError, ValueError, yaml.YAMLError):
        return []
    rows = d.get("projects") if isinstance(d, dict) else d
    return [r for r in (rows or []) if isinstance(r, dict)]


def registry_repos(rows):
    out = []
    for r in rows:
        g = r.get("git") or {}
        if isinstance(g, dict) and g.get("host") == "github.com" and g.get("owner") and g.get("repo"):
            out.append(f"{g['owner']}/{g['repo']}")
    return out


def why_open(pr):
    """Why an open PR is not merged yet, in the operator's words; the last two are the green ones."""
    names = [str((l or {}).get("name", "")).lower() for l in pr.get("labels") or []]
    if pr.get("isDraft"):
        return "draft"
    if any("hold" in n for n in names):
        return "on hold"
    if pr.get("mergeable") == "CONFLICTING":
        return "conflicts with its base"
    red, pending = [], False
    for c in pr.get("statusCheckRollup") or []:
        concl = str(c.get("conclusion") or c.get("state") or "").upper()
        status = str(c.get("status") or "").upper()
        if concl in ("FAILURE", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "ERROR", "STARTUP_FAILURE"):
            red.append(c.get("name") or c.get("context") or "a check")
        elif status in ("IN_PROGRESS", "QUEUED", "PENDING", "WAITING") or concl == "PENDING":
            pending = True
    if red:
        return "red gate: " + ", ".join(sorted(set(red))[:3])
    if not (pr.get("statusCheckRollup") or []):
        return "no gate ran — waiting for review"
    if pr.get("reviewDecision") == "CHANGES_REQUESTED":
        return "rework asked"
    if pending:
        return "gate running"
    if pr.get("reviewDecision") == "APPROVED":
        return GREEN_WORDS[1]
    return GREEN_WORDS[0]


def gather_github(gh, repos, since, now):
    merged, opened, errors = [], [], []

    def one(repo):
        if not gh.can_push(repo):
            return repo, [], [], ""
        try:
            m = [p for p in gh.merged(repo, since)
                 if (iso_to_epoch(p.get("mergedAt")) or 0) >= since and (iso_to_epoch(p.get("mergedAt")) or 0) <= now]
            o = gh.open(repo)
            return repo, m, o, ""
        except (RuntimeError, ValueError, subprocess.TimeoutExpired) as e:
            return repo, [], [], str(e) or type(e).__name__

    with cf.ThreadPoolExecutor(max_workers=4) as ex:
        for repo, m, o, err in ex.map(one, repos):
            if err:
                errors.append((repo, err))
            for p in m:
                merged.append(dict(p, repo=repo))
            for p in o:
                opened.append(dict(p, repo=repo, why=why_open(p)))
    merged.sort(key=lambda p: p.get("mergedAt") or "")
    opened.sort(key=lambda p: (p["why"] in GREEN_WORDS, p["repo"], p.get("number", 0)))
    return merged, opened, errors


# ── the alarms ────────────────────────────────────────────────────────────────────────────────

def gather_alarms(home, since, now):
    rang, mended = {}, {}
    try:
        lines = (home / RUNES).read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return [], [], "the Runes ledger could not be read"
    for line in lines:
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            r = json.loads(line)
        except ValueError:
            continue
        t = iso_to_epoch(r.get("timestamp"))
        if t is None or t < since or t > now:
            continue
        ev, msg = str(r.get("event", "")), str(r.get("message", ""))
        if ev == "notify" and re.search(r"/(HIGH|CRITICAL)\]", msg):
            key = re.sub(r"^\[[^\]]*\]\s*", "", msg)
            slot = rang.setdefault(key, {"what": key, "who": r.get("actor", ""), "n": 0, "first": t})
            slot["n"] += 1
        elif ev == "mend" or ev.endswith(".mend"):
            slot = mended.setdefault(msg, {"what": msg, "who": r.get("actor", ""), "n": 0, "first": t})
            slot["n"] += 1
    by_time = lambda d: sorted(d.values(), key=lambda x: x["first"])  # noqa: E731
    return by_time(rang), by_time(mended), ""


# ── his list: the board, through bin/records/todo.sh ──────────────────────────────────────────

class TodoDoor:
    """`bin/records/todo.sh`, or a fixture standing in for it (tests). The ONE door to his to-do."""

    def __init__(self, fixture=None):
        self.fx = Path(fixture) if fixture else None

    def list(self):
        """(cards, why): cards is None when the board cannot be read, and why says so."""
        if self.fx is not None:
            out, rc = json.loads(self.fx.read_text()), 0
        else:
            rc, raw = sh(["bash", str(TODO_DOOR), "list", "--json"], timeout=120)
            try:
                out = json.loads(raw) if rc == 0 else {}
            except ValueError:
                return None, f"`todo.sh list` answered no JSON: {clip(raw, 90)}"
            if rc != 0:
                return None, f"`todo.sh list` failed (exit {rc}): {clip(raw, 90)}"
        if out.get("verdict") == "skip":
            return None, f"the board is not configured on this seat ({clip(out.get('why', ''), 80)})"
        cards = out.get("cards")
        if not isinstance(cards, list):
            return None, "`todo.sh list` answered without cards"
        return cards, ""

    def date_of(self, card):
        """The date the card's item was written, from its description (the migration kept the item's own
        line and section there). Read-only, through the door's own module; None when it cannot be told."""
        if self.fx is not None:
            for c in json.loads(self.fx.read_text()).get("cards") or []:
                if str(c.get("card")) == str(card):
                    m = DATE_RE.search(str(c.get("description") or ""))
                    return m.group(1) if m else None
            return None
        try:
            sys.path.insert(0, str(TODO_DOOR.parent))
            import todo_board  # noqa: PLC0415
            desc = str(todo_board.Board(todo_board.config()).call("get_card", card=str(card)).get("description") or "")
        except Exception:  # noqa: BLE001 — an unreadable card is an undated card, never a crash
            return None
        m = DATE_RE.search(desc)
        return m.group(1) if m else None

    def move(self, card, lane):
        """(ok, said). In the fixture the card's state changes, so a second run sees it closed."""
        if self.fx is not None:
            out = json.loads(self.fx.read_text())
            for c in out.get("cards") or []:
                if str(c.get("card")) == str(card):
                    c["state"] = lane
                    out.setdefault("moves", []).append([c["card"], lane])
                    self.fx.write_text(json.dumps(out))
                    return True, f"moved #{card} to {lane}"
            return False, f"no card #{card}"
        rc, raw = sh(["bash", str(TODO_DOOR), "move", str(card), lane], timeout=120)
        return rc == 0, clip(raw, 120)


HALF_OF_LABEL = {"his": "his", "derived": "derived", "house-kept": "kept"}


def card_items(cards):
    """One item per card, in the shape todo_items() gives a file line; `raw` is the card's title."""
    items = []
    for c in cards:
        title = str(c.get("title") or "")
        labels = [str(l) for l in (c.get("labels") or [])]
        state = str(c.get("state") or "")
        d = DATE_RE.search(title)
        half = next((HALF_OF_LABEL[l] for l in labels if l in HALF_OF_LABEL), "other")
        held = "Someday" in labels or state.casefold() == "someday"
        items.append({
            "id": f"card-{c.get('card')}", "card": c.get("card"), "line": None, "end": None,
            "open": state.casefold() not in CLOSED_STATES, "text": plain(title), "raw": title,
            "section": "Held" if held else (state or "board"), "half": half,
            "date": d.group(1) if d else None,
        })
    return items


def item_source(t):
    if t.get("card") is not None:
        return f"the to-do board, card #{t['card']}"
    return f"{TODO} line {t['line'] + 1}, read-only"


# ── his list: the retired file, read as a fallback ─────────────────────────────────────────────────────────────────────────────────────

HALVES = (("His half", "his"), ("The derived half", "derived"), ("The house-kept half", "kept"))


def todo_items(lines):
    """The same reading as bin/voice/voice_tools.py `_todo_items()`: one item per `- [ ]`/`- [x]` line."""
    items, section, half, section_date = [], "", "other", None
    for n, line in enumerate(lines):
        if line.startswith("# ") or line.startswith("## "):
            section = line.lstrip("# ").strip()
            m = DATE_RE.search(section)
            section_date = m.group(1) if m else None
            if line.startswith("# "):
                half = next((name for prefix, name in HALVES if section.startswith(prefix)), "other")
            continue
        m = re.match(r"^- \[( |x|X)\] (.*)$", line)
        if not m:
            continue
        text, k = m.group(2), n + 1
        while k < len(lines) and lines[k].startswith("      ") and not lines[k].lstrip().startswith("- ["):
            text += " " + lines[k].strip()
            k += 1
        d = DATE_RE.search(text)
        items.append({
            "id": "t" + hashlib.sha1(m.group(2).encode()).hexdigest()[:5],
            "line": n, "end": k - 1, "open": m.group(1) == " ", "text": plain(text),
            "section": section, "half": half, "date": d.group(1) if d else section_date,
            "raw": "\n".join(lines[n:k]),
        })
    return items


def waiting_on_him(items):
    mine = [t for t in items if t["open"] and t["half"] == "his" and not t["section"].startswith("Held")]
    return sorted(mine, key=lambda t: (t["date"] or "9999-99-99", t["line"] if t["line"] is not None else 0,
                                       t.get("card") or 0))


def voice_open(home):
    state = {}
    try:
        for line in (home / VOICE).read_text(encoding="utf-8").splitlines():
            try:
                ev = json.loads(line)
            except ValueError:
                continue
            i = ev.get("id")
            if not i:
                continue
            row = state.setdefault(i, {"id": i, "item": "", "open": True})
            if ev.get("action") == "add":
                row.update(item=ev.get("item", ""), open=True)
            elif ev.get("action") == "done":
                row["open"] = False
            elif ev.get("action") == "reopen":
                row["open"] = True
            elif ev.get("action") == "update" and ev.get("item"):
                row["item"] = ev["item"]
    except OSError:
        return []
    return [r for r in state.values() if r["open"] and r["item"]]


PR_REFS = (
    re.compile(r"github\.com/([\w.-]+/[\w.-]+)/pull/(\d+)"),
    re.compile(r"(?<![\w/])([\w.-]+/[\w.-]+)#(\d+)\b"),
)
BARE_PR = (re.compile(r"\bPRs?\s+#?(\d{1,6})\b"), re.compile(r"(?<![\w&])#(\d{1,6})\b"))
ERRAND_WORD = re.compile(r"(?<![\w/.-])([a-z0-9]+(?:-[a-z0-9]+)+)(?![\w/.-])")
TICKED = re.compile(r"\(done: \d{4}-\d\d-\d\d")


def head_of(raw):
    """The item's own subject: its bold lead (`- [ ] **Decide PR #831** — …`), else its words up to ' — '.

    Only the subject can prove an item done. A PR named in the item's reasons (*Unblocks: every PR's
    gate, #831 first*) is context, and its merge says nothing about the item.
    """
    body = re.sub(r"^- \[[ xX]\] ", "", raw.strip())
    m = re.match(r"^\*\*(.+?)\*\*", body, re.S)
    if m:
        return m.group(1)
    return re.split(r" — | -- ", body, maxsplit=1)[0]


def refs_of(item_text, raw, default_repo, known_errands):
    """Every PR and errand an item's SUBJECT names: {("pr", repo, n)} ∪ {("errand", id)}.

    Every bare number an item calls a PR (`PR 810`, `PR #810`, `#810`) counts, so an item that names
    several PRs names several refs and is never ticked on one of them. A bare number means the
    default repository; a number already named with its repository is not counted twice.
    """
    raw = head_of(raw)
    item_text = plain(raw)
    refs = set()
    for rx in PR_REFS:
        for repo, n in rx.findall(raw):
            refs.add(("pr", repo, int(n)))
    named = {r[2] for r in refs if r[0] == "pr"}
    for rx in BARE_PR:
        for n in rx.findall(item_text):
            if int(n) not in named:
                refs.add(("pr", default_repo or "?", int(n)))
    # an errand is named in `backticks` on the file; a board card's title has lost its backticks, so a bare
    # hyphenated word counts too — but only when it IS an errand this house knows
    for tok in set(re.findall(r"`([a-z0-9][a-z0-9-]{2,})`", raw)) | set(ERRAND_WORD.findall(raw)):
        if tok in known_errands:
            refs.add(("errand", tok))
    return refs


def proofs(items, gh, default_repo, errand_lookup, now, date_of=None):
    """[(item, note)] for every open item proven done by exactly one closed PR or errand."""
    out = []
    known = set(errand_lookup)
    for t in items:
        if not t["open"]:
            continue
        raw = t["raw"]
        if TICKED.search(raw):
            continue
        refs = refs_of(t["text"], raw, default_repo, known)
        if len(refs) != 1:
            continue
        (ref,) = refs
        stamp = local(now).strftime("%Y-%m-%d %H:%M")
        if ref[0] == "pr":
            _, repo, n = ref
            if repo == "?":
                continue
            st = gh.state(repo, n) or {}
            when = (st.get("mergedAt") or "")[:10]
            if st.get("state") == "MERGED" and not t["date"] and t.get("card") is not None and date_of:
                t["date"] = date_of(t["card"])  # an undated title: the card's description knows when
            # a PR merged BEFORE the item was written is not its proof: the item means another PR
            if st.get("state") == "MERGED" and not (t["date"] and when and when < t["date"]):
                out.append((t, f"(done: {stamp} — {repo}#{n} merged {when}; ticked by the night report)"))
        else:
            e = errand_lookup[ref[1]]
            if e.get("outcome") != "done":
                continue
            pr = e.get("pr") or ""
            m = re.search(r"github\.com/([\w.-]+/[\w.-]+)/pull/(\d+)", pr)
            if m:
                st = gh.state(m.group(1), int(m.group(2))) or {}
                if st.get("state") != "MERGED":
                    continue
                note = f"errand `{ref[1]}` done and {m.group(1)}#{m.group(2)} merged"
            else:
                note = f"errand `{ref[1]}` reported done on {e.get('machine', 'a seat')}"
            out.append((t, f"(done: {stamp} — {note}; ticked by the night report)"))
    return out


# ── the boards ────────────────────────────────────────────────────────────────────────────────

def board_decisions(rows, home):
    """Open `decision` cards on every board the registry names (plan 335), and what could not be read."""
    sys.path.insert(0, str(ROOT / "bin/boards"))
    try:
        from board_adapter_mcp import BoardRefusal, McpBoard, resolve_token  # noqa: PLC0415
    except ImportError as e:
        return [], [f"the board adapter could not load ({e})"]
    seen, cards, errors = set(), [], []
    for r in rows:
        b = r.get("board") or {}
        if not isinstance(b, dict) or b.get("adapter") != "mcp" or not b.get("place") or b["place"] in seen:
            continue
        seen.add(b["place"])
        mcp = b.get("mcp") or {}
        try:
            board = McpBoard(b["place"], mcp["url"], resolve_token(mcp.get("token_from"), str(home), str(ROOT)))
            for c in board.list_cards("decision"):
                if c.get("group") not in ("done", "cancelled"):
                    cards.append({"place": b["place"], "card": c.get("card"), "title": c.get("title", "")})
        except (BoardRefusal, KeyError, OSError, ValueError, RuntimeError) as e:
            errors.append(f"board {b['place']}: {clip(str(e), 90)}")
    return cards, errors


# ── the report ────────────────────────────────────────────────────────────────────────────────

def needs_him(errands, cards, his):
    out = []
    for e in errands:
        if e["state"] == "needs-decision":
            out.append(f"decide `{e['id']}`: {clip(e['reason'], 80)}")
    for c in cards:
        out.append(f"decision card {c['card']}: {clip(c['title'], 80)}")
    for e in errands:
        if e["state"] == "blocked":
            out.append(f"unblock `{e['id']}`: {clip(e['reason'], 80)}")
    # his own "(priority high)" items lead the rest; the order within each stays oldest first
    for t in sorted(his, key=lambda t: "priority high" not in t["text"].lower()):
        out.append(clip(t["text"], 90))
    return out


def build(data):
    d = data
    since, now = d["since"], d["now"]
    date = local(now).strftime("%Y-%m-%d")
    done = [e for e in d["errands"] if e["outcome"] == "done"]
    notdone = [e for e in d["errands"] if e["outcome"] == "not-done"]
    running = [e for e in d["errands"] if e["outcome"] == "running"]
    green = [p for p in d["open"] if p["why"] in GREEN_WORDS]
    quiet = not (d["errands"] or d["merged"] or d["rang"] or d["mended"] or d["ticks"])
    window = f"{local(since).strftime('%a %d %b %H:%M')} → {local(now).strftime('%a %d %b %H:%M')}"
    out = [f"# Night report — {date}", "",
           f"*Window: {window} (local) · written on {me()} · seats read: {', '.join(d['seats']) or 'none'}"
           + (f" · not heard: {', '.join(n for n, _ in d['unheard'])}" if d["unheard"] else "") + "*", ""]
    if quiet:
        out += ["A quiet night: no errand ran, no PR merged, no alarm rang, and nothing on your list closed.", ""]
    else:
        out += [f"{len(done)} errands done, {len(notdone)} not done, {len(running)} still running. "
                f"{len(d['merged'])} PRs merged, {len(d['open'])} open ({len(green)} green). "
                f"{len(d['rang'])} alarm{'' if len(d['rang']) == 1 else 's'} rang, the house made {len(d['mended'])} "
                f"mend{'' if len(d['mended']) == 1 else 's'}, "
                f"and {len(d['ticks'])} items on your list were ticked.", ""]
    top = d["needs"][:3]
    if top:
        out += ["## What needs you first", ""] + [f"{i}. {x}" for i, x in enumerate(top, 1)] + [""]
    if not quiet:
        if done:
            out += [f"## Errands done ({len(done)})", ""]
            for e in done:
                pr = f" · [{pr_label(e['pr'])}]({e['pr']})" if e["pr"] else ""
                out.append(f"- `{e['id']}` on {e['machine']}{pr} — {clip(e['reason'], 160)} "
                           f"*(source: {e['machine']}:{e['source']})*")
            out.append("")
        if notdone:
            out += [f"## Errands not done ({len(notdone)})", ""]
            for e in sorted(notdone, key=lambda e: e["at"]):
                out.append(f"- `{e['id']}` on {e['machine']} — **{e['state']}**: {clip(e['reason'], 160)} "
                           f"*(source: {e['machine']}:{e['source']})*")
            out.append("")
        if running:
            out += [f"## Still running ({len(running)})", ""]
            for e in running:
                out.append(f"- `{e['id']}` on {e['machine']} — last line {hhmm(e['at'])}: {clip(e['reason'], 120)} "
                           f"*(source: {e['machine']}:{e['source']})*")
            out.append("")
        if d["merged"]:
            out += [f"## PRs merged ({len(d['merged'])})", ""]
            for p in d["merged"]:
                at = iso_to_epoch(p.get("mergedAt"))
                out.append(f"- [{p['repo']}#{p['number']}]({p['url']}) {clip(p.get('title'), 90)} — merged "
                           f"{hhmm(at) if at else '?'} *(source: GitHub)*")
            out.append("")
    if d["open"]:
        out += [f"## PRs open ({len(d['open'])}), and why", ""]
        for p in d["open"]:
            out.append(f"- [{p['repo']}#{p['number']}]({p['url']}) {clip(p.get('title'), 90)} — **{p['why']}** "
                       f"*(source: GitHub)*")
        out.append("")
    if d["rang"] or d["mended"]:
        out += ["## Alarms and mends", ""]
        for a in d["rang"][:12]:
            out.append(f"- rang {hhmm(a['first'])}{times(a)}: {clip(a['what'], 130)} *(source: Runes, {a['who']})*")
        if len(d["rang"]) > 12:
            out.append(f"- and {len(d['rang']) - 12} more alarms *(source: Runes)*")
        for m in d["mended"][:12]:
            out.append(f"- mended {hhmm(m['first'])}{times(m)}: {clip(m['what'], 130)} *(source: Runes, {m['who']})*")
        if len(d["mended"]) > 12:
            out.append(f"- and {len(d['mended']) - 12} more mends *(source: Runes)*")
        out.append("")
    if d["ticks"]:
        out += [f"## Closed on your to-do ({len(d['ticks'])})", ""]
        for t, note in d["ticks"]:
            out.append(f"- {clip(t['text'], 110)} — {note.strip('()')} *(source: {item_source(t)})*")
        out.append("")
    his = d["his"]
    out += [f"## Waiting on you ({len(his)} open in your half, oldest first)", ""]
    for t in his[:12]:
        since_txt = f"since {t['date']}" if t["date"] else "undated"
        out.append(f"- {clip(t['text'], 120)} — {since_txt} *(source: {item_source(t)})*")
    if len(his) > 12:
        where = d.get("todo_source") or "the to-do board"
        out.append(f"- and {len(his) - 12} more on {where} *(source: {where})*")
    for c in d["cards"]:
        out.append(f"- decision card {c['card']} on {c['place']}: {clip(c['title'], 110)} *(source: the board)*")
    for v in d["voice"]:
        out.append(f"- {clip(v['item'], 110)} *(source: {VOICE}, {v['id']})*")
    out.append("")
    if d["problems"]:
        out += ["## What could not be read", ""] + [f"- {p}" for p in d["problems"]] + [""]
    return "\n".join(out).rstrip() + "\n"


def times(row):
    return f" ×{row['n']}" if row["n"] > 1 else ""


def pr_label(url):
    m = re.search(r"github\.com/([\w.-]+/[\w.-]+)/pull/(\d+)", url or "")
    return f"{m.group(1)}#{m.group(2)}" if m else "PR"


def telegram_lines(data):
    d = data
    done = sum(1 for e in d["errands"] if e["outcome"] == "done")
    nd = sum(1 for e in d["errands"] if e["outcome"] == "not-done")
    run = sum(1 for e in d["errands"] if e["outcome"] == "running")
    green = sum(1 for p in d["open"] if p["why"] in GREEN_WORDS)
    lines = [f"Night report {local(d['now']).strftime('%a %d %b')} ({hhmm(d['since'])}–{hhmm(d['now'])})"]
    if not (d["errands"] or d["merged"] or d["rang"] or d["mended"] or d["ticks"]):
        lines.append("A quiet night: nothing ran, nothing merged, nothing rang.")
    else:
        lines.append(f"Errands: {done} done · {nd} not done · {run} running")
    lines.append(f"PRs: {len(d['merged'])} merged · {len(d['open'])} open ({green} green) · "
                 f"alarms {len(d['rang'])} · ticked {len(d['ticks'])}")
    needs = d["needs"][:3]
    lines += [f"{i}. {clip(x, 90)}" for i, x in enumerate(needs, 1)]
    if len(lines) < 6:
        lines.append("Nothing else waits on you." if needs else "Nothing waits on you.")
    return lines[:6]


CALLBACK_MAX_BYTES = 64  # Telegram's cap on callback_data; bin/notify/telegram-buttons.mjs clips anything longer


def buttons(date):
    """The message's three buttons. A tap sends its prompt back as callback_data, which Telegram caps at
    64 bytes and the button tool clips at a word boundary — so each prompt keeps its verb and its object
    inside 64 bytes, and names the report by its date (a tap a day later still means that report)."""
    return [
        f"📄 Open the night report|Read me the {date} night report, needs first",
        f"✅ Merge the green PRs|Merge the green PRs in the {date} night report",
        f"🧱 Show what is stuck|Show the stuck errands in the {date} night report",
    ]


# ── writing ───────────────────────────────────────────────────────────────────────────────────

def sh(args, timeout=300):
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return p.returncode, (p.stdout + p.stderr).strip()
    except (OSError, subprocess.TimeoutExpired) as e:
        return 1, str(e)


def write_report(home, rel, text, now):
    path = home / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        with path.open("a", encoding="utf-8") as fh:
            fh.write(f"\n---\n\n## A later run, {local(now).strftime('%H:%M')}\n\n" + text.split("\n", 2)[-1])
    else:
        path.write_text(text, encoding="utf-8")


def append_daily(home, now, rel, counts):
    path = home / DAILY / f"{local(now).strftime('%Y-%m-%d')}.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(f"\n- {hhmm(now)} night report written on {me()}: {counts} — `{rel}`\n")
    return path.relative_to(home)


# ── main ──────────────────────────────────────────────────────────────────────────────────────

def collect(a, home, now, since):
    problems = []
    errands, seats, unheard = gather_seats(home, since, now, fleet=not a.no_fleet)
    for n, why in unheard:
        problems.append(f"seat {n}: {why} — its errands are not in this report")
    rows = registry(home)
    gh = GitHub(a.github_fixture)
    default_repo = a.default_repo or origin_repo()
    merged, opened = [], []
    if not a.no_github:
        repos = list(dict.fromkeys(([default_repo] if default_repo else []) + registry_repos(rows) + (a.repo or [])))
        merged, opened, errs = gather_github(gh, repos, since, now)
        problems += [f"GitHub {r}: {e}" for r, e in errs]
    rang, mended, err = gather_alarms(home, since, now)
    if err:
        problems.append(err)
    door = TodoDoor(getattr(a, "todo_fixture", None))
    cards, why = door.list()
    if cards is not None:
        items, todo_source = card_items(cards), "the to-do board"
    else:
        # the board cannot be read: the retired file is READ so he still sees what waits, and nothing closes
        todo_source = f"{TODO} (read-only)"
        try:
            items = todo_items((home / TODO).read_text(encoding="utf-8").splitlines())
            problems.append(f"his to-do was read from the file — {why}; nothing was closed")
        except OSError:
            items = []
            problems.append(f"his to-do could not be read — {why}, and {TODO} is not there; nothing was closed")
    his = waiting_on_him(items)
    decisions = []
    if not a.no_board:
        decisions, errs = board_decisions(rows, home)
        problems += errs
    # every errand any seat named tonight, plus this seat's own record of any errand his list names
    lookup = {e["id"]: e for e in errands}
    words = set()
    for t in items:
        if t["open"]:
            head = head_of(t["raw"])
            words |= set(re.findall(r"`([a-z0-9][a-z0-9-]{2,})`", head)) | set(ERRAND_WORD.findall(head))
    for tok in words:
        if tok not in lookup:
            e = night_seat.errand_state(home, tok)
            if e:
                e["machine"] = me()
                lookup[tok] = e
    # only a card is closed: the file is retired and is never written
    ticks = [] if a.no_github or cards is None else proofs(items, gh, default_repo, lookup, now, door.date_of)
    data = {"since": since, "now": now, "errands": errands, "seats": seats, "unheard": unheard,
            "merged": merged, "open": opened, "rang": rang, "mended": mended, "his": his,
            "cards": decisions, "voice": voice_open(home), "ticks": ticks, "problems": problems,
            "todo_source": todo_source}
    closed = {t["id"] for t, _ in ticks}
    data["his"] = his = [t for t in his if t["id"] not in closed]
    data["needs"] = needs_him(errands, decisions, his)
    return data, door


def main(argv=None):
    ap = argparse.ArgumentParser(prog="night-report.sh", description=__doc__.split("\n")[0])
    ap.add_argument("--since", help="window start: ISO time or epoch (default: the last report, or 22:00 yesterday)")
    ap.add_argument("--now", help="window end (default: now)")
    ap.add_argument("--home", help="the home (default: $YMIR_HOME, then ~/.config/ymir/home)")
    ap.add_argument("--dry-run", action="store_true", help="print the report and the message; write and send nothing")
    ap.add_argument("--json", action="store_true", help="with --dry-run: the gathered facts as JSON")
    ap.add_argument("--fallback", action="store_true",
                    help="a seat standing in for the heart: do nothing when today's report already exists")
    ap.add_argument("--repo", action="append", help="another owner/repo to read (repeatable)")
    ap.add_argument("--default-repo", help="the repo a bare 'PR 810' on his list means (default: this checkout's origin)")
    ap.add_argument("--no-fleet", action="store_true", help="read this seat only")
    ap.add_argument("--no-github", action="store_true", help="read no PRs (and tick nothing)")
    ap.add_argument("--no-board", action="store_true", help="read no board")
    ap.add_argument("--no-send", action="store_true", help="write the report, send no message")
    ap.add_argument("--no-sync", action="store_true", help="do not pull or ship the home (tests)")
    ap.add_argument("--github-fixture", help=argparse.SUPPRESS)
    ap.add_argument("--todo-fixture", help=argparse.SUPPRESS)
    a = ap.parse_args(argv)

    home = night_seat.resolve_home(a.home)
    if not home.is_dir():
        print(f"night-report: the home is not there: {home}", file=sys.stderr)
        return 1
    now = parse_when(a.now, time.time()) or time.time()
    date = local(now).strftime("%Y-%m-%d")
    rel = REPORT_DIR / f"{date}-night-report.md"

    if a.fallback and not a.dry_run:
        # every seat that stands in waits its own, fixed while, so two do not write at once
        time.sleep(int(hashlib.sha1(me().encode()).hexdigest(), 16) % 300)
    if not a.dry_run and not a.no_sync:
        rc, out = sh(["bash", str(ROOT / "bin/vault/home-sync.sh"), "begin"])
        if rc != 0:
            print(f"night-report: the home could not be pulled first — {clip(out, 200)}", file=sys.stderr)
            return 1
    if a.fallback and (home / rel).exists():
        print(f"night-report: today's report is already written ({rel}); this seat stands down")
        return 0

    since = parse_when(a.since, now) or default_since(now, home)
    data, door = collect(a, home, now, since)
    text = build(data)
    tg = telegram_lines(data)

    if a.dry_run:
        if a.json:
            safe = dict(data, ticks=[{"item": t["text"], "card": t.get("card"), "note": n} for t, n in data["ticks"]])
            print(json.dumps(safe, indent=1, default=str))
        else:
            print(text)
            print("── the Telegram message (not sent) ──")
            print("\n".join(tg))
            for t, note in data["ticks"]:
                print(f"── would move card #{t['card']} to Done: {note}")
        return 0

    paths = []
    closed = []
    for t, note in data["ticks"]:
        ok, said = door.move(t["card"], "Done")
        if ok:
            closed.append((t, note))
        else:
            data["problems"].append(f"card #{t['card']} could not be closed through todo.sh — {said}")
    if len(closed) != len(data["ticks"]):
        data["ticks"] = closed
        text = build(data)
        tg = telegram_lines(data)
    write_report(home, rel, text, now)
    paths.append(str(rel))
    done = sum(1 for e in data["errands"] if e["outcome"] == "done")
    nd = sum(1 for e in data["errands"] if e["outcome"] == "not-done")
    paths.append(str(append_daily(home, now, rel,
                                  f"{done} done · {nd} not done · {len(data['merged'])} merged · {len(data['ticks'])} ticked")))
    (home / LAST).parent.mkdir(parents=True, exist_ok=True)
    (home / LAST).write_text(f"{int(now)}\n")
    print(f"night-report: written {rel}")

    if not a.no_sync:
        rc, out = sh(["bash", str(ROOT / "bin/vault/home-sync.sh"), "ship", f"night report {date}"] + paths)
        print(f"night-report: ship {'ok' if rc == 0 else 'FAILED'} — {clip(out, 200)}")
    if not a.no_send:
        args = ["bash", str(ROOT / "bin/notify/send.sh"), "--source", "cron", "--severity", "INFO", "--ask",
                "--key", f"report:night-{date}", "--target", f"file:{home / rel}", "--message", "\n".join(tg)]
        for b in buttons(date):
            args += ["--button", b]
        rc, out = sh(args, timeout=60)
        print(f"night-report: message {'sent' if rc == 0 else 'NOT sent'} — {clip(out, 200)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

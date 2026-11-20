#!/usr/bin/env python3
"""cardlib.py — the card contract, the guard, the projections, the adapters and the ledger (gimle plan 328).

One module, so every caller that makes a card — the shell door (card.sh), an MCP tool, Rödd by voice, an agent —
runs the SAME guard against the SAME contract and writes the SAME ledger. A caller that writes to a board without
passing through here is the fault plan 328 exists to close.

    contract  $CARDS_CONTRACT, else $YMIR_HOME/hodd/identity/cards.yaml, else config/cards.yaml.example
    ledger    $CARDS_LEDGER,   else $YMIR_HOME/hodd/state/boards/cards.jsonl  (one JSON line per operation)

Nothing about one installation is written here (Rule 07): endpoints come from the environment
(PLANE_API_BASE, TRELLO_API_BASE, GITHUB_API_BASE), credentials from the environment or the vault, and the people
map (which board login a person has) from the contract file in the home.
"""
from __future__ import annotations

import datetime as _dt
import html
import json
import os
import re
import subprocess
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
BOARDS = ("plane", "trello", "github")
CALLERS_NEEDING_EVIDENCE = ("agent", "mcp", "voice")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


class Refused(Exception):
    """A write the contract refuses. `.reasons` is a list of {field, why}."""

    def __init__(self, reasons):
        self.reasons = reasons
        super().__init__("; ".join(f"{r['field']}: {r['why']}" for r in reasons))


# ── where things live ──────────────────────────────────────────────────────────────────────────────────────────
def home() -> str:
    h = os.environ.get("YMIR_HOME", "")
    if h:
        return h
    lib = os.path.join(ROOT, "bin", "vault", "hoard-lib.sh")
    if os.path.exists(lib):
        try:
            out = subprocess.run(["bash", "-c", f'. "{lib}" >/dev/null 2>&1; ymir_home_root H >/dev/null 2>&1; printf %s "$H"'],
                                 capture_output=True, text=True, timeout=10).stdout.strip()
            if out:
                return out
        except Exception:  # noqa: BLE001
            pass
    return ""


def contract_path() -> str:
    p = os.environ.get("CARDS_CONTRACT", "")
    if p:
        return p
    h = home()
    if h and os.path.exists(os.path.join(h, "hodd", "identity", "cards.yaml")):
        return os.path.join(h, "hodd", "identity", "cards.yaml")
    return os.path.join(ROOT, "config", "cards.yaml.example")


def ledger_path() -> str:
    p = os.environ.get("CARDS_LEDGER", "")
    if p:
        return p
    h = home()
    if not h:
        raise SystemExit('card[1]{door,state,why}:\n  "card","refused","no YMIR_HOME and no CARDS_LEDGER — the ledger has nowhere to live"')
    return os.path.join(h, "hodd", "state", "boards", "cards.jsonl")


def load_contract(path: str | None = None) -> dict:
    import yaml  # the repo already depends on PyYAML (bin/boards/plane.sh)
    path = path or contract_path()
    with open(path, encoding="utf-8") as fh:
        c = yaml.safe_load(fh) or {}
    c["_path"] = path
    return c


# ── the guard ──────────────────────────────────────────────────────────────────────────────────────────────────
def _norm(s) -> str:
    return re.sub(r"\s+", " ", str(s or "")).strip()


def check_title(title: str, kind: str, c: dict) -> list[str]:
    t = _norm(title)
    rules = c.get("title") or {}
    why = []
    mx = int(((c.get("fields") or {}).get("title") or {}).get("max", 80))
    if not t:
        return ["a title is required: verb + deliverable"]
    if len(t) > mx:
        why.append(f"{len(t)} characters, over {mx} — it will truncate on a board; name one deliverable")
    low = " " + t.lower() + " "
    for smell in rules.get("smells") or []:
        if re.search(r"(?<![a-z])" + re.escape(smell.lower()) + r"(?![a-z])", low):
            why.append(f"'{smell}' names no deliverable — name the artefact")
    for two in rules.get("two_deliverables") or []:
        if two.lower() in low:
            why.append(f"'{two.strip()}' joins two deliverables — that is two cards")
    words = t.split()
    first = re.sub(r"[^a-z\-]", "", words[0].lower())
    if re.match(r"^[A-Za-z]{0,3}\d+([,–\-]|$)", words[0]):
        why.append(f"opens with a record id ('{words[0]}') — the id is the key, the title is verb + deliverable")
    elif kind in ("task", "chore"):
        if first not in set(rules.get("verbs") or []):
            why.append(f"'{words[0]}' is not an imperative verb from the contract — a {kind} title is verb + deliverable")
        if len(words) < 2:
            why.append("a verb alone has no deliverable")
    elif kind == "bug":
        if not any(f" {w} " in low for w in rules.get("bug_triggers") or []):
            why.append("a bug title names the symptom AND the trigger ('… fails when …')")
    elif kind == "spike":
        if not t.endswith("?"):
            why.append("a spike is a question — end the title with '?'")
    return why


def check_owner(owner: str, c: dict) -> list[str]:
    o = _norm(owner)
    rules = c.get("owner") or {}
    if not o:
        return ["exactly one owner is required — a card nobody owns is an idea, and belongs in a document"]
    if o.lower() in [r.lower() for r in rules.get("refuse") or []]:
        return [f"'{o}' is nobody — one person or one named agent seat"]
    for sep in rules.get("separators") or []:
        if (sep in f" {o.lower()} ") if sep != sep.strip() else (sep in o):
            return [f"'{o}' names more than one owner — one card, one owner; split it or choose"]
    return []


def validate(card: dict, c: dict, caller: str = "person", op: str = "add") -> list[dict]:
    """Every refusal the contract makes of this card, as [{field, why}]. Empty = accepted."""
    fields = c.get("fields") or {}
    out = []
    kind = card.get("kind") or (fields.get("kind") or {}).get("default", "task")
    if kind not in (c.get("kinds") or ["task"]):
        out.append({"field": "kind", "why": f"'{kind}' is not a kind ({', '.join(c.get('kinds') or [])})"})
    status = card.get("status") or (fields.get("status") or {}).get("default", "proposed")
    if status not in (c.get("statuses") or []):
        out.append({"field": "status", "why": f"'{status}' is not a status ({' · '.join(c.get('statuses') or [])})"})
    for name, spec in fields.items():
        req = (spec or {}).get("required", "optional")
        val = card.get(name)
        empty = val in (None, "", []) or (isinstance(val, list) and not any(_norm(v) for v in val))
        if req == "always" and empty:
            out.append({"field": name, "why": f"required — {spec.get('rule', 'the contract requires it')}"})
        elif req == "on_status" and empty and status in (spec.get("statuses") or []):
            out.append({"field": name, "why": f"required before a card is {status} — {spec.get('rule', '')}".rstrip(" —")})
        elif req == "made_by_agent" and empty and caller in CALLERS_NEEDING_EVIDENCE:
            out.append({"field": name, "why": f"required when a {caller} makes the card — {spec.get('rule', '')}"})
        if not empty and spec.get("values") and str(val) not in [str(v) for v in spec["values"]]:
            out.append({"field": name, "why": f"'{val}' is not one of {', '.join(map(str, spec['values']))}"})
    if card.get("title"):
        out += [{"field": "title", "why": w} for w in check_title(card["title"], kind, c)]
    if card.get("owner") is not None and _norm(card.get("owner")):
        out += [{"field": "owner", "why": w} for w in check_owner(card["owner"], c)]
    due = _norm(card.get("due"))
    if due and due != "unresolved" and not DATE.match(due):
        out.append({"field": "due", "why": f"'{due}' is not YYYY-MM-DD or 'unresolved'"})
    if due == "unresolved" and not DATE.match(_norm(card.get("decide_by"))):
        out.append({"field": "decide_by", "why": "due is 'unresolved' — name the date it will be decided by (YYYY-MM-DD)"})
    for d in ("start", "decide_by"):
        v = _norm(card.get(d))
        if v and not DATE.match(v):
            out.append({"field": d, "why": f"'{v}' is not YYYY-MM-DD"})
    if status == "blocked" and not _norm(card.get("waiting")):
        out.append({"field": "waiting", "why": "a blocked card names its blocker and who must remove it"})
    if kind == "spike" and not _norm(card.get("timebox")):
        out.append({"field": "timebox", "why": "a spike carries a time box — it produces an answer, not code"})
    if kind == "bug" and not _norm(card.get("evidence")):
        out.append({"field": "evidence", "why": "a bug carries the exact error text or how to reproduce it"})
    # one refusal per (field, why)
    seen, uniq = set(), []
    for r in out:
        k = (r["field"], r["why"])
        if k not in seen:
            seen.add(k)
            uniq.append(r)
    return uniq


def normalise(card: dict, c: dict) -> dict:
    """Fill the derived fields and tidy the shape. Never invents a required field."""
    fields = c.get("fields") or {}
    card = {k: v for k, v in card.items() if v not in (None, "", [])}
    card.setdefault("status", (fields.get("status") or {}).get("default", "proposed"))
    card.setdefault("kind", (fields.get("kind") or {}).get("default", "task"))
    if isinstance(card.get("acceptance"), str):
        card["acceptance"] = [a.strip() for a in re.split(r"\n|\s*\|\|\s*", card["acceptance"]) if a.strip()]
    if isinstance(card.get("steps"), str):
        card["steps"] = [a.strip() for a in re.split(r"\n|\s*\|\|\s*", card["steps"]) if a.strip()]
    if not card.get("key") and card.get("title"):
        card["key"] = derive_key(card.get("place", ""), card["title"])
    return card


def derive_key(place: str, title: str) -> str:
    slug = lambda s: re.sub(r"[^a-z0-9]+", "-", str(s).lower()).strip("-")  # noqa: E731
    return f"{slug(place) or 'card'}:{slug(title)[:48].rstrip('-')}"


# ── the projections ────────────────────────────────────────────────────────────────────────────────────────────
def support(c: dict, field: str, board: str) -> str:
    spec = (c.get("fields") or {}).get(field) or {}
    return ((spec.get("boards") or {}).get(board)) or "degraded"


def render_body(card: dict, degraded: list[str]) -> str:
    """The card body in the runbook's order; every field the board could not hold natively is kept here."""
    lines = []
    if card.get("objective"):
        lines += [f"Objective: {card['objective']}", ""]
    if card.get("evidence"):
        lines += [f"Context: {card.get('context_note', '')}".rstrip(), f"Evidence: {card['evidence']}", ""]
    if card.get("steps"):
        lines += ["Steps:"] + [f"- [ ] {s}" for s in card["steps"]] + [""]
    if card.get("acceptance"):
        lines += ["Acceptance:"] + [f"- [ ] {a}" for a in card["acceptance"]] + [""]
    if card.get("out_of_scope"):
        lines += [f"Out of scope: {card['out_of_scope']}", ""]
    facts = [f for f in degraded if f not in ("acceptance", "evidence") and card.get(f) not in (None, "", [])]
    if facts:
        lines += ["Card (fields this board has no place for, kept here by the card door):"]
        lines += [f"- {f}: {card[f]}" for f in facts]
    lines += ["", f"card-key: {card.get('key', '')}"]
    return "\n".join(lines).strip() + "\n"


def plan_projection(card: dict, board: str, c: dict) -> dict:
    """Which fields this board carries natively, which it keeps in the body or a label, and which it loses."""
    carried, degraded, lost = [], [], []
    for f in list((c.get("fields") or {}).keys()):
        if card.get(f) in (None, "", []):
            continue
        s = support(c, f, board)
        (carried if s == "native" else lost if s == "lost" else degraded).append(f)
    return {"board": board, "carried": carried, "degraded": degraded, "lost": lost}


def demote(proj: dict, field: str, why: str, notes: list[str]):
    """A field the contract calls native that THIS board instance could not hold (an unknown person, a missing list)."""
    if field in proj["carried"]:
        proj["carried"].remove(field)
        proj["degraded"].append(field)
    notes.append(f"{field}: {why}")


# ── the adapters ───────────────────────────────────────────────────────────────────────────────────────────────
def _vault(prefixes: tuple[str, ...]) -> dict:
    if os.environ.get("CARDS_NO_VAULT"):
        return {}
    try:
        text = subprocess.run(["bash", os.path.join(ROOT, "bin", "vault", "hodd.sh"), "emit", "secrets/platform.env"],
                              capture_output=True, text=True, timeout=20).stdout
    except Exception:  # noqa: BLE001
        return {}
    keys = {}
    for line in text.splitlines():
        line = line.strip().removeprefix("export ")
        if line.startswith(prefixes) and "=" in line:
            k, v = line.split("=", 1)
            keys[k] = v.strip().strip("'\"")
    return keys


def _cred(names: tuple[str, ...]) -> dict:
    got = {n: os.environ.get(n, "") for n in names}
    if not all(got.values()):
        v = _vault(tuple(n.split("_")[0] + "_" for n in names))
        got = {n: got[n] or v.get(n, "") for n in names}
    return got


def _http(method, url, headers, body=None):
    data = json.dumps(body).encode() if body is not None else None
    h = {"Accept": "application/json", **headers}
    if data is not None:
        h["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=25) as r:
            raw = r.read().decode()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"{method} {url.split('?')[0]} answered HTTP {exc.code}: "
                           f"{exc.read().decode('utf-8', 'replace')[:200]}") from None
    except urllib.error.URLError as exc:
        raise RuntimeError(f"{url.split('?')[0]} did not answer ({exc.reason})") from None


def person(c: dict, owner: str, board: str) -> str:
    """The board login the contract's people map gives an owner, or '' when it names none."""
    for name, row in (c.get("people") or {}).items():
        if _norm(name).lower() == _norm(owner).lower() or _norm(owner).lower() in [str(a).lower() for a in (row or {}).get("aliases") or []]:
            return str((row or {}).get(board) or "")
    return ""


class NoCredentials(Exception):
    pass


STATUS_NAMES = {
    "proposed": ["proposed", "backlog", "project todos", "todo", "to do", "inbox"],
    "accepted": ["accepted", "this week", "todo", "to do", "project todos", "next"],
    "doing": ["doing", "in progress", "started", "today"],
    "done": ["done", "completed", "closed"],
    "blocked": ["blocked", "waiting"],
}


def _pick(names: list[dict], status: str, key: str = "name"):
    want = STATUS_NAMES.get(status, [status])
    for w in want:
        for n in names:
            if (n.get(key) or "").strip().lower() == w:
                return n
    return None


class Plane:
    """Plane through its REST API — the same endpoints the projector (bin/gimle/project.py) and the Gimlé MCP use.
    target = '<workspace-slug>/<project-id>'."""

    name = "plane"

    def __init__(self):
        self.base = os.environ.get("PLANE_API_BASE", "").rstrip("/")
        tok = os.environ.get("PLANE_API_TOKEN", "") or _cred(("PLANE_API_TOKEN",))["PLANE_API_TOKEN"]
        if not self.base or not tok:
            raise NoCredentials("PLANE_API_BASE / PLANE_API_TOKEN unset (env or vault)")
        self.h = {"X-API-Key": tok}

    def create(self, card, target, c, proj, notes):
        ws, pid = (target.split("/", 1) + [""])[:2]
        root = f"{self.base}/api/v1/workspaces/{ws}/projects/{pid}"
        body = {"name": card["title"], "external_source": "ymir-card", "external_id": card["key"]}
        states = _http("GET", f"{root}/states/", self.h)
        states = states.get("results", states) if isinstance(states, dict) else states
        st = _pick(states or [], card["status"])
        if st:
            body["state"] = st["id"]
        else:
            demote(proj, "status", f"no state in this project matches '{card['status']}'", notes)
        mem = _http("GET", f"{self.base}/api/v1/workspaces/{ws}/members/", self.h)
        mem = mem.get("results", mem) if isinstance(mem, dict) else mem
        login = person(c, card["owner"], "plane") or card["owner"]
        hit = next((m for m in mem or [] if login.lower() in
                    {str(m.get(k, "")).lower() for k in ("display_name", "first_name", "id", "email")}), None)
        if hit:
            body["assignees"] = [hit["id"]]
        else:
            demote(proj, "owner", f"'{card['owner']}' is not a member of this workspace — kept in the body", notes)
        if DATE.match(_norm(card.get("due"))):
            body["target_date"] = card["due"]
        elif card.get("due"):
            demote(proj, "due", "'unresolved' has no date field — kept in the body", notes)
        if card.get("start"):
            body["start_date"] = card["start"]
        body["description_html"] = "<pre>" + html.escape(render_body(card, proj["degraded"])) + "</pre>"
        made = _http("POST", f"{root}/issues/", self.h, body)
        return f"{ws}/{pid}#{made.get('sequence_id', made.get('id'))}", made.get("id")

    def move(self, ref_id, target, status):
        ws, pid = target.split("/", 1)
        root = f"{self.base}/api/v1/workspaces/{ws}/projects/{pid}"
        states = _http("GET", f"{root}/states/", self.h)
        states = states.get("results", states) if isinstance(states, dict) else states
        st = _pick(states or [], status)
        if not st:
            raise RuntimeError(f"no state in {target} matches '{status}'")
        _http("PATCH", f"{root}/issues/{ref_id}/", self.h, {"state": st["id"]})


class Trello:
    """Trello through its REST API (the hosted MCP cannot assign or label — plan 324). target = a list id."""

    name = "trello"

    def __init__(self):
        self.base = os.environ.get("TRELLO_API_BASE", "https://api.trello.com/1").rstrip("/")
        cr = _cred(("TRELLO_API_KEY", "TRELLO_TOKEN"))
        if all(cr.values()):
            self.h = {"Authorization": f'OAuth oauth_consumer_key="{cr["TRELLO_API_KEY"]}", oauth_token="{cr["TRELLO_TOKEN"]}"'}
            return
        # second road: the grant the Trello MCP server already holds on this seat, read (and refreshed) by the
        # meeting board's own client — one credential loader, never a second copy of it.
        if os.environ.get("CARDS_NO_VAULT"):
            raise NoCredentials("TRELLO_API_KEY / TRELLO_TOKEN unset, and the vault is switched off")
        try:
            import sys as _sys
            _sys.path.insert(0, os.path.join(ROOT, "systems", "snotra", "services", "cron"))
            import trello_client  # noqa: PLC0415
            tok = trello_client.token()
        except (SystemExit, Exception) as exc:  # noqa: BLE001 — die() raises SystemExit
            raise NoCredentials(f"TRELLO_API_KEY / TRELLO_TOKEN unset and no Trello MCP grant ({exc})") from None
        self.h = {"Authorization": f"Bearer {tok}"}

    def _label(self, board, name, color="sky"):
        for lab in _http("GET", f"{self.base}/boards/{board}/labels?fields=name,color&limit=1000", self.h):
            if (lab.get("name") or "").lower() == name.lower():
                return lab["id"]
        return _http("POST", f"{self.base}/labels", self.h, {"name": name, "color": color, "idBoard": board})["id"]

    def create(self, card, target, c, proj, notes):
        lst = _http("GET", f"{self.base}/lists/{target}?fields=idBoard,name", self.h)
        board = lst["idBoard"]
        body = {"idList": target, "name": card["title"], "pos": "bottom"}
        lists = _http("GET", f"{self.base}/boards/{board}/lists?fields=name", self.h)
        want = _pick(lists, card["status"])
        if want:
            body["idList"] = want["id"]
        else:
            notes.append(f"status: no list on this board matches '{card['status']}' — the card is in '{lst.get('name')}'")
        if DATE.match(_norm(card.get("due"))):
            body["due"] = card["due"] + "T09:00:00.000Z"
        elif card.get("due"):
            demote(proj, "due", "'unresolved' has no date field — kept in the body", notes)
        if card.get("start"):
            body["start"] = card["start"] + "T09:00:00.000Z"
        labels = [self._label(board, f"key:{card['key']}"[:100], "black")]
        members = _http("GET", f"{self.base}/boards/{board}/members?fields=username,fullName", self.h)
        login = person(c, card["owner"], "trello") or card["owner"]
        hit = next((m for m in members if login.lower() in (str(m.get("username", "")).lower(), str(m.get("fullName", "")).lower())), None)
        if hit:
            body["idMembers"] = [hit["id"]]
        else:
            labels.append(self._label(board, f"owner:{card['owner']}"[:100], "purple"))
            demote(proj, "owner", f"'{card['owner']}' is not a member of this board — kept as a label and in the body", notes)
        body["idLabels"] = labels
        body["desc"] = render_body(card, proj["degraded"])
        made = _http("POST", f"{self.base}/cards", self.h, body)
        return made.get("shortUrl") or made.get("id"), made.get("id")

    def move(self, ref_id, target, status):
        card = _http("GET", f"{self.base}/cards/{ref_id}?fields=idBoard", self.h)
        lists = _http("GET", f"{self.base}/boards/{card['idBoard']}/lists?fields=name", self.h)
        want = _pick(lists, status)
        if not want:
            raise RuntimeError(f"no list on this board matches '{status}'")
        _http("PUT", f"{self.base}/cards/{ref_id}", self.h, {"idList": want["id"]})


class GitHub:
    """GitHub issues through the REST API. target = '<owner>/<repo>'."""

    name = "github"

    def __init__(self):
        tok = os.environ.get("GITHUB_TOKEN", "") or _cred(("GITHUB_TOKEN",))["GITHUB_TOKEN"]
        if not tok:
            raise NoCredentials("GITHUB_TOKEN unset (env or vault)")
        self.base = os.environ.get("GITHUB_API_BASE", "https://api.github.com").rstrip("/")
        self.h = {"Authorization": f"Bearer {tok}", "Accept": "application/vnd.github+json"}

    def create(self, card, target, c, proj, notes):
        body = {"title": card["title"], "labels": [f"status:{card['status']}"]}
        login = person(c, card["owner"], "github")
        if login:
            body["assignees"] = [login]
        else:
            demote(proj, "owner", f"the contract's people map names no GitHub login for '{card['owner']}' — kept in the body", notes)
        body["body"] = render_body(card, proj["degraded"])
        made = _http("POST", f"{self.base}/repos/{target}/issues", self.h, body)
        return f"{target}#{made.get('number')}", str(made.get("number"))

    def move(self, ref_id, target, status):
        _http("PATCH", f"{self.base}/repos/{target}/issues/{ref_id}", self.h,
              {"state": "closed" if status == "done" else "open", "labels": [f"status:{status}"]})


ADAPTERS = {"plane": Plane, "trello": Trello, "github": GitHub}


# ── the ledger ─────────────────────────────────────────────────────────────────────────────────────────────────
def now() -> str:
    return _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def append(row: dict, path: str | None = None) -> dict:
    path = path or ledger_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    row = {"at": now(), **row}
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
    return row


def read(path: str | None = None) -> list[dict]:
    path = path or ledger_path()
    if not os.path.exists(path):
        return []
    rows = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line:
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    return rows


def fold(rows: list[dict]) -> dict:
    """The current record of every card, by key: the card, where each board carries it, and its history."""
    cards = {}
    for r in rows:
        if not r.get("ok") or r.get("verb") not in ("add", "move", "assign", "bind"):
            continue
        k = r.get("key")
        if not k:
            continue
        cur = cards.setdefault(k, {"card": {}, "refs": {}, "ops": []})
        if r.get("card"):
            cur["card"] = r["card"]
        if r.get("board") and r.get("ref"):
            cur["refs"][r["board"]] = {"ref": r["ref"], "id": r.get("ref_id"), "target": r.get("target")}
        cur["ops"].append({"at": r["at"], "verb": r["verb"], "board": r.get("board"), "door": r.get("door")})
    return cards


# ── the one write path: guard → ledger → board ─────────────────────────────────────────────────────────────────
def add(card: dict, *, door: str, caller: str, who: str, board: str = "", target: str = "",
        c: dict | None = None, ledger: str | None = None) -> dict:
    """Make a card. Refused by name (Refused) when the contract refuses it; the refusal is in the ledger too."""
    c = c or load_contract()
    card = normalise(card, c)
    reasons = validate(card, c, caller=caller, op="add")
    base = {"door": door, "caller": caller, "who": who, "verb": "add", "key": card.get("key", ""),
            "board": board or None, "target": target or None}
    if reasons:
        append({**base, "ok": False, "refused": reasons, "title": card.get("title", "")}, ledger)
        raise Refused(reasons)
    existing = fold(read(ledger)).get(card["key"])
    if existing and board and board in existing["refs"]:
        reasons = [{"field": "key", "why": f"'{card['key']}' is already on {board} as {existing['refs'][board]['ref']} — "
                                           "a re-run updates (move/assign), it never makes a second card"}]
        append({**base, "ok": False, "refused": reasons}, ledger)
        raise Refused(reasons)
    row = {**base, "ok": True, "card": card}
    if board:
        if board not in ADAPTERS:
            raise Refused([{"field": "board", "why": f"'{board}' is not a board ({', '.join(BOARDS)})"}])
        proj, notes = plan_projection(card, board, c), []
        try:
            ad = ADAPTERS[board]()
        except NoCredentials as exc:
            # the hand road: no credentials on this seat. The card is in the record; the caller carries the
            # projection to the board (an MCP tool it holds) and binds the board's id with `card.sh bind`.
            row.update({"board_state": "projected", "why": str(exc), **proj,
                        "body": render_body(card, proj["degraded"]), "notes": notes})
            return append(row, ledger)
        try:
            ref, ref_id = ad.create(card, target, c, proj, notes)
        except RuntimeError as exc:
            append({**base, "ok": False, "refused": [{"field": "board", "why": str(exc)}]}, ledger)
            raise Refused([{"field": "board", "why": str(exc)}]) from None
        row.update({"board_state": "created", "ref": ref, "ref_id": ref_id, **proj, "notes": notes})
    return append(row, ledger)


def find(key: str, ledger: str | None = None) -> dict:
    cur = fold(read(ledger)).get(key)
    if not cur:
        raise Refused([{"field": "key", "why": f"no card '{key}' in the ledger — `card.sh list` names them"}])
    return cur


def move(key: str, status: str, *, door: str, caller: str, who: str, waiting: str = "", due: str = "",
         decide_by: str = "", c: dict | None = None, ledger: str | None = None) -> dict:
    c = c or load_contract()
    cur = find(key, ledger)
    card = dict(cur["card"], status=status)
    for f, v in (("waiting", waiting), ("due", due), ("decide_by", decide_by)):
        if v:
            card[f] = v
    base = {"door": door, "caller": caller, "who": who, "verb": "move", "key": key}
    reasons = validate(card, c, caller="person", op="move")  # provenance was judged at creation
    if reasons:
        append({**base, "ok": False, "refused": reasons}, ledger)
        raise Refused(reasons)
    warn = []
    wip = ((c.get("personal") or {}).get("wip_limit")) or {}
    if wip and status == wip.get("status"):
        n = sum(1 for k, v in fold(read(ledger)).items() if k != key and v["card"].get("status") == status
                and v["card"].get("owner") == card.get("owner") and v["card"].get("place") == card.get("place"))
        if n + 1 > int(wip.get("max", 3)):
            warn.append(f"WIP: {card.get('owner')} now has {n + 1} cards in {status} in {card.get('place')} (limit {wip.get('max')})")
    moved = []
    for b, ref in cur["refs"].items():
        try:
            ADAPTERS[b]().move(ref["id"], ref.get("target") or "", status)
            moved.append(b)
        except NoCredentials as exc:
            warn.append(f"{b}: not moved on the board ({exc}) — the record holds the new status")
        except RuntimeError as exc:
            warn.append(f"{b}: {exc}")
    return append({**base, "ok": True, "card": card, "boards_moved": moved, "notes": warn}, ledger)


def assign(key: str, owner: str, *, door: str, caller: str, who: str, c: dict | None = None,
           ledger: str | None = None) -> dict:
    c = c or load_contract()
    cur = find(key, ledger)
    card = dict(cur["card"], owner=owner)
    base = {"door": door, "caller": caller, "who": who, "verb": "assign", "key": key}
    reasons = validate(card, c, caller="person", op="assign")
    if reasons:
        append({**base, "ok": False, "refused": reasons}, ledger)
        raise Refused(reasons)
    notes = [f"{b}: the record holds the new owner; reassign on the board through its own door" for b in cur["refs"]]
    return append({**base, "ok": True, "card": card, "notes": notes}, ledger)


def bind(key: str, board: str, ref: str, *, ref_id: str = "", target: str = "", door: str, caller: str, who: str,
         ledger: str | None = None) -> dict:
    """Record the board's id for a card that was projected by hand (an MCP tool carried it)."""
    cur = find(key, ledger)
    if board in cur["refs"]:
        raise Refused([{"field": "key", "why": f"'{key}' is already bound on {board} as {cur['refs'][board]['ref']}"}])
    return append({"door": door, "caller": caller, "who": who, "verb": "bind", "key": key, "board": board,
                   "ref": ref, "ref_id": ref_id or ref, "target": target or None, "ok": True}, ledger)

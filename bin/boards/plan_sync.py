#!/usr/bin/env python3
"""plan_sync.py — mirror a project's plan ledger onto its board: one whole card per plan (plan 335, phases 3 and 3b).

The door is `bin/boards/plan-sync.sh`; this file is its logic. Standard library only, plus PyYAML for the registry.

What it does, and refuses to do:
  * reads the project's row in `$YMIR_HOME/hodd/identity/projects.yaml` — the `board:` block names the
    adapter, the place and the road (nothing about an installation is written here, RULES/07);
  * reads the project's plan ledger in the home and its README index;
  * makes ONE card per plan, whole (plan 335 §"one card carries the whole plan"):
      - title `NNN · <plan title>`, label `plan`, the state GROUP from the ledger's status;
      - the description is the plan's full text, opened by the line
        "🔒 generated from the file — edit the file, not this card", and sent as Markdown, so the board keeps its
        headings, tables and lists and draws its ```mermaid diagrams where it can;
      - the plan's phases (every table with a `#` column, a phase/step column and an accept/done column) become
        SUB-ITEMS of the card, `NNN.<id> · <phase>`, each carrying its accept line;
      - a link to the plan file, when the home names a web address for its repository;
  * is idempotent: a second run changes nothing. A card is found by its number and title, never created twice; a
    card it wrote carries `[stamp: <group>.<hash>]`, so an unchanged plan is recognised from one listing of the
    place, without reading every card;
  * upgrades the short cards of the first pass IN PLACE (same card, now whole);
  * touches only cards that carry the `plan` label and the `NNN · ` title shape, and their own sub-items; never
    deletes one;
  * leaves a card the board moved by hand where it stands, until the ledger's status itself changes.

It speaks the board CONTRACT only (plan 335, "the split"): state groups — backlog · unstarted · started · review ·
done · cancelled — never one engine's state names, and never one engine's markup. The adapter named in the registry
turns the contract into the board's own calls; today the generic `mcp` adapter (bin/boards/board_adapter_mcp.py).

The `board:` block (in the project's registry row):

    board:
      adapter: mcp
      place: <the board's address for this project>
      mcp:
        url: https://…/mcp
        token_from: claude-mcp:<server> | env:<NAME> | vault:<NAME>   # a REFERENCE (or a list, tried in order)
      plans: <home-relative ledger path>    # optional; default records.in_home.plans, then the realm layout
      file_url: https://…/blob/main/{path}  # optional; default derived from the home's git remote
      plans_repo:                           # optional: the ledger lives in the PROJECT'S OWN repository
        clone: <path>                       #   absolute, or relative to $HOME; default the row's local_clone, then ~/<repo>
        ref: origin/main                    #   the git ref read (never the working tree); default origin/<git.default_branch>
        dir: plans                          #   the ledger's folder inside the repository; default plans
        fetch: true                         #   fetch the remote first (only remote-tracking refs move); default false
      status_map: {record: done}            # optional: this ledger's own status words → a state group
      phase_heads: {id: [n], name: [slice]} # optional: this ledger's own phase-table column words (id/name/accept)

A repository ledger is read from the ref, never the checkout, so a clone that is behind or mid-branch cannot put a
stale plan on the board; the link to each file is built from the row's `git:` block unless `file_url` names one.

Exit: 0 ok · 1 refused, or a plan could not be synced (named) · 2 usage.
"""
import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from board_adapter_mcp import BoardRefusal, McpBoard, resolve_token  # noqa: E402

LABEL = "plan"
TITLE_RE = re.compile(r"^(\d+) · (.*)$")
LOCK = "🔒 generated from the file — edit the file, not this card"
MAX_TEXT = 400_000  # a plan larger than this is cut, and the card says so


class Refusal(BoardRefusal):
    pass


# ── the home and the registry ────────────────────────────────────────────────────────────────

def home_root():
    h = os.environ.get("YMIR_HOME")  # plan-sync.sh resolves it through the one resolver and exports it
    if not h:
        raise Refusal("YMIR_HOME is not set — run through bin/boards/plan-sync.sh, or set it")
    return h


def registry_rows(home):
    try:
        import yaml
    except ImportError:
        raise Refusal("PyYAML is not installed — the registry cannot be read")
    reg = os.path.join(home, "hodd", "identity", "projects.yaml")
    if not os.path.isfile(reg):
        raise Refusal(f"no registry at {reg} — set YMIR_HOME")
    data = yaml.safe_load(open(reg)) or {}
    rows = data.get("projects", data)
    if isinstance(rows, dict):
        rows = [dict(id=k, **(v or {})) for k, v in rows.items()]
    return rows or []


def load_project(home, wanted):
    rows = registry_rows(home)
    w = wanted.lower()
    for r in rows:
        if str(r.get("id", "")).lower() == w:
            return r
    for r in rows:
        if str(r.get("name", "")).lower() == w:
            return r
    raise Refusal(f"the registry has no project '{wanted}'")


class Ledger(str):
    """The ledger's display path; `.where` says whose it is ("home" or "repository"), `.label` names it on a link."""
    where = "home"


def repo_spec(row):
    """The row's repository ledger, or None. -> dict(clone, ref, dir, fetch)."""
    rp = (row.get("board") or {}).get("plans_repo")
    if not rp:
        return None
    rp = rp if isinstance(rp, dict) else {}
    git = row.get("git") or {}
    clone = rp.get("clone") or row.get("local_clone") or row.get("repo")
    if not clone:
        raise Refusal("board.plans_repo names no clone, and the row has neither local_clone nor repo")
    clone = os.path.expanduser(str(clone))
    if not os.path.isabs(clone):
        clone = os.path.join(os.path.expanduser("~"), clone)
    ref = rp.get("ref") or f"{git.get('remote') or 'origin'}/{git.get('default_branch') or 'main'}"
    return {"clone": clone, "ref": str(ref), "dir": str(rp.get("dir") or "plans").strip("/"),
            "fetch": bool(rp.get("fetch"))}


_TMP = []


def repo_ledger(row):
    """Materialise the repository ledger AT ITS REF into a private temp folder (the checkout is never read or moved)."""
    spec = repo_spec(row)
    if not os.path.isdir(os.path.join(spec["clone"], ".git")) and not os.path.isfile(os.path.join(spec["clone"], ".git")):
        raise Refusal(f"no git clone at {spec['clone']} (board.plans_repo.clone)")
    if spec["fetch"]:
        remote = spec["ref"].split("/", 1)[0]
        subprocess.run(["git", "-C", spec["clone"], "fetch", "-q", remote], capture_output=True, timeout=120)
    tmp = tempfile.mkdtemp(prefix="plan-sync-")
    _TMP.append(tmp)
    arch = subprocess.run(["git", "-C", spec["clone"], "archive", "--format=tar", spec["ref"], "--", spec["dir"]],
                          capture_output=True, timeout=120)
    if arch.returncode != 0:
        raise Refusal(f"cannot read {spec['dir']}/ at {spec['ref']} in {spec['clone']}: "
                      f"{arch.stderr.decode(errors='replace').strip()[:200]}")
    tar = subprocess.run(["tar", "-x", "-C", tmp], input=arch.stdout, capture_output=True, timeout=120)
    if tar.returncode != 0:
        raise Refusal(f"cannot unpack the ledger: {tar.stderr.decode(errors='replace').strip()[:200]}")
    path = os.path.join(tmp, spec["dir"])
    if not os.path.isdir(path):
        raise Refusal(f"no plan ledger at {spec['dir']}/ on {spec['ref']}")
    rel = Ledger(spec["dir"])
    rel.where = "repository"
    return rel, path


def cleanup():
    for t in _TMP:
        shutil.rmtree(t, ignore_errors=True)


def ledger_dir(home, row):
    board = row.get("board") or {}
    if board.get("plans_repo"):
        return repo_ledger(row)
    rel = board.get("plans") or ((row.get("records") or {}).get("in_home") or {}).get("plans")
    if not rel:
        realm = row.get("realm") or row.get("company")
        pid = str(row.get("id", ""))
        pid = {"ymir-platform": "ymir"}.get(pid, pid)
        if not realm:
            raise Refusal("the registry row names neither board.plans, records.in_home.plans nor a realm")
        rel = f"svartalfaheim/{realm}/projects/{pid}/plans/"
    path = os.path.join(home, rel)
    if not os.path.isdir(path):
        raise Refusal(f"no plan ledger at {path}")
    return Ledger(rel.rstrip("/")), path


def project_for_file(home, path):
    """The registry row whose plan ledger holds `path` (only rows with a board: block), or a refusal naming why."""
    target = os.path.realpath(path)
    for r in registry_rows(home):
        if not r.get("board"):
            continue
        try:
            if r["board"].get("plans_repo"):  # a repository ledger: the file lies in the clone's ledger folder
                spec = repo_spec(r)
                led = os.path.join(spec["clone"], spec["dir"])
            else:
                _, led = ledger_dir(home, r)
        except Refusal:
            continue
        if os.path.dirname(target) == os.path.realpath(led):
            return r
    raise Refusal(f"no project with a board: block keeps its plans where {path} lies")


# ── the plans ────────────────────────────────────────────────────────────────────────────────

GROUPS = ("backlog", "unstarted", "started", "review", "done", "cancelled")


def status_group(text, status_map=None):
    """Map a ledger status phrase onto a state GROUP of the board contract (a ledger's own status_map first)."""
    t = (text or "").strip().lower().lstrip("`*_ ")
    head = re.split(r"\s[—–·(-]\s|\s*\(", t, maxsplit=1)[0]
    for word, group in (status_map or {}).items():
        if group in GROUPS and re.match(rf"{re.escape(str(word).lower())}\b", head):
            return group
    if re.match(r"(superseded|retired|withdrawn|rejected|abandoned|cancel|dropped|obsolete|merged into)", head):
        return "cancelled"
    if re.match(r"(built|done|landed|shipped|complete|closed|live|fixed|merged|delivered)", head):
        return "done"
    if re.match(r"(partial|active|building|in progress|in-progress|started|working|living)", head):
        return "started"
    if re.match(r"(approved|ready|briefed)", head):
        return "unstarted"
    return "backlog"


def header_status(path):
    try:
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()[:45]
    except OSError:
        return ""
    for ln in lines:
        m = re.search(r"\*\*Status:?\*\*:?\s*(.+)", ln, re.I) or re.match(r'\s*"status","([^"]+)"', ln, re.I) \
            or re.match(r"\s*status:\s*(.+)", ln, re.I)
        if m:
            return m.group(1).strip()
    return ""


def clean_title(text):
    t = re.sub(r"^#+\s*", "", text.strip())
    t = re.sub(r"^(?:Plan\s+)?\d+\s*[—–:-]\s*", "", t, flags=re.I)
    return re.sub(r"\s+", " ", t).strip()


def file_title(path):
    try:
        for ln in open(path, encoding="utf-8", errors="replace"):
            if ln.startswith("# "):
                return clean_title(ln)
    except OSError:
        pass
    return ""


def read_plans(ledger_rel, ledger_abs, include_old=False, status_map=None):
    """-> list of dicts (num, title, rel, abs, status, group) sorted by number then path."""
    found = {}  # rel path inside the ledger -> {title, status}
    readme = os.path.join(ledger_abs, "README.md")
    root_files = sorted(os.listdir(ledger_abs))
    if os.path.isfile(readme):
        rlines = open(readme, encoding="utf-8", errors="replace").read().splitlines()
        status_col = None  # the `Status` column of the table being read, for rows that carry no link
        for k, ln in enumerate(rlines):
            if not ln.startswith("|"):
                status_col = None
                continue
            nxt = _cells(rlines[k + 1]) if k + 1 < len(rlines) else None
            if nxt and all(re.match(r"^:?-{2,}:?$", c) for c in nxt if c):  # a header row
                hb = [_bare(h).lower() for h in (_cells(ln) or [])]
                status_col = hb.index("status") if "status" in hb else None
                continue
            m = re.match(r"\|\s*(\d+)\s*\|\s*\[([^\]]+)\]\(([^)#]+\.md)\)(.*)$", ln.rstrip())
            if not m:
                cells = _cells(ln) or []
                if status_col is None or len(cells) <= status_col or not re.match(r"^\d+$", cells[0]) \
                        or len(cells) < 2 or not cells[1]:
                    continue
                n = int(cells[0])  # an index row with no link: the file is the one ledger file of that number
                files = [f for f in root_files if re.match(rf"0*{n}[-_].*\.md$", f)]
                if len(files) == 1:
                    found[files[0]] = {"title": clean_title(cells[1]), "status": cells[status_col]}
                continue
            link = m.group(3)
            if not os.path.isfile(os.path.join(ledger_abs, link)):
                continue
            cells = [c.strip() for c in m.group(4).split("|")]
            cells = [c for c in cells if c != ""]
            status = cells[-1] if cells else ""
            found[link] = {"title": clean_title(m.group(2)), "status": status}  # a later row wins
    for fn in root_files:  # plans at the ledger's root that the index lacks
        if re.match(r"\d+[-_].*\.md$", fn) and fn not in found:
            found[fn] = {"title": "", "status": None}
    plans = []
    for rel, info in found.items():
        if rel.startswith("old-plans/") and not include_old:
            continue
        base = os.path.basename(rel)
        m = re.match(r"(\d+)", base)
        if not m:
            continue
        absf = os.path.join(ledger_abs, rel)
        title = info["title"] or file_title(absf) or re.sub(r"^\d+[-_]", "", base[:-3]).replace("-", " ")
        status = info["status"]
        if status is None or not status.strip():
            status = header_status(absf)
        plans.append({"num": int(m.group(1)), "title": title, "rel": f"{ledger_rel}/{rel}", "abs": absf,
                      "where": getattr(ledger_rel, "where", "home"),
                      "status": status or "", "group": status_group(status, status_map)})
    plans.sort(key=lambda p: (p["num"], p["rel"]))
    return plans


def card_title(p):
    return f"{p['num']:03d} · {p['title']}"[:250]


def status_word(p):
    return (p["status"] or "no status in the ledger").split(" — ")[0].split(" · ")[0].strip()[:60]


def short(text, n=12):
    return hashlib.sha256(text.encode()).hexdigest()[:n]


# ── the phases ───────────────────────────────────────────────────────────────────────────────

_ID_HEAD = re.compile(r"^(#|no\.?|step|phase\s*#|id)$", re.I)
_NAME_HEAD = re.compile(r"^(phase|step|what|item|the step|work)$", re.I)
_DONE_HEAD = re.compile(r"(accept|done means|done when|proof|test)", re.I)


def _cells(line):
    s = line.strip()
    if not (s.startswith("|") and s.endswith("|")):
        return None
    return [c.strip() for c in s[1:-1].split("|")]


def _bare(text):
    t = re.sub(r"\*\*|__|`", "", text or "").strip()
    return re.sub(r"\s+", " ", t)


class _Heads:
    """A column matcher: the built-in pattern, or one of a ledger's own words (whole header, any case)."""

    def __init__(self, base, words, whole=True):
        self.base, self.whole = base, whole
        self.words = [str(w).strip().lower() for w in (words or []) if str(w).strip()]

    def _hit(self, h):
        h = h.lower()
        return any(h == w for w in self.words) if self.whole else any(w in h for w in self.words)

    def match(self, h):
        return self.base.match(h) or self._hit(h)

    def search(self, h):
        return self.base.search(h) or self._hit(h)


def phase_heads(extra=None):
    """The three column matchers, widened by a ledger's own words (board.phase_heads: {id, name, accept} lists)."""
    extra = extra or {}
    return (_Heads(_ID_HEAD, extra.get("id")), _Heads(_NAME_HEAD, extra.get("name")),
            _Heads(_DONE_HEAD, extra.get("accept"), whole=False))


def read_phases(text, heads=None):
    """Every phase row of every phase table in the plan → [(id, name, accept)], first appearance order, last word wins."""
    id_head, name_head, done_head = heads or (_ID_HEAD, _NAME_HEAD, _DONE_HEAD)
    lines = text.splitlines()
    order, rows = [], {}
    in_code = False
    i = 0
    while i < len(lines):
        if lines[i].lstrip().startswith("```"):
            in_code = not in_code
        head = None if in_code else _cells(lines[i])
        sep = _cells(lines[i + 1]) if head and i + 1 < len(lines) else None
        if head and sep and all(re.match(r"^:?-{2,}:?$", c) for c in sep if c):
            hb = [_bare(h) for h in head]
            idc = next((k for k, h in enumerate(hb) if id_head.match(h)), None)
            namec = next((k for k, h in enumerate(hb) if name_head.match(h) and k != idc), None)
            donec = next((k for k, h in enumerate(hb) if done_head.search(h) and k not in (idc, namec)), None)
            i += 2
            while i < len(lines) and _cells(lines[i]) is not None:
                row = _cells(lines[i])
                if None not in (idc, namec, donec) and len(row) > max(idc, namec, donec):
                    pid = _bare(row[idc]).rstrip(".")
                    if pid and re.match(r"^[\w.]+$", pid):
                        if pid not in rows:
                            order.append(pid)
                        rows[pid] = (_bare(row[namec]), _bare(row[donec]))
                i += 1
            continue
        i += 1
    return [(pid, rows[pid][0], rows[pid][1]) for pid in order]


def phase_title(num, pid, name):
    key = pid if re.match(rf"^0*{num}\.", pid) else f"{num}.{pid}"
    return f"{key} · {name}"[:250], f"{key} · "


# ── the card's text ──────────────────────────────────────────────────────────────────────────

def file_url(home, row, rel):
    """A web address for the plan file: board.file_url, else the home's own git remote; None when neither names one."""
    tmpl = (row.get("board") or {}).get("file_url")
    if tmpl:
        return tmpl.replace("{path}", rel)
    if (row.get("board") or {}).get("plans_repo"):  # the project's own repository, from its git: block
        git = row.get("git") or {}
        if not (git.get("host") and git.get("owner") and git.get("repo")):
            return None
        return f"https://{git['host']}/{git['owner']}/{git['repo']}/blob/{git.get('default_branch') or 'main'}/{rel}"
    try:
        url = subprocess.run(["git", "-C", home, "remote", "get-url", "origin"], capture_output=True, text=True,
                             timeout=10).stdout.strip()
        branch = subprocess.run(["git", "-C", home, "rev-parse", "--abbrev-ref", "HEAD"], capture_output=True,
                                text=True, timeout=10).stdout.strip() or "main"
    except (OSError, subprocess.SubprocessError):
        return None
    m = re.match(r"^(?:git@([^:]+):|https://(?:[^@/]+@)?([^/]+)/)(.+?)(?:\.git)?$", url)
    if not m:
        return None
    return f"https://{m.group(1) or m.group(2)}/{m.group(3)}/blob/{branch}/{rel}"


def plan_body(p):
    text = open(p["abs"], encoding="utf-8", errors="replace").read()
    cut = len(text) > MAX_TEXT
    if cut:
        text = text[:MAX_TEXT]
    return text, cut


def card_markdown(p, text, cut):
    head = f"{LOCK} · `{p['rel']}` in the {p.get('where', 'home')}."
    tail = "\n\n*(The plan is longer than a card holds; the rest is in the file.)*" if cut else ""
    return f"{head}\n\n---\n\n{text.rstrip()}{tail}\n"


def with_stamp(md, p, stamp):
    return (f"{md}\n---\n\nplan-sync · plan {p['num']} · {p['group']} ({status_word(p)}) · [stamp: {stamp}]\n")


def phase_markdown(accept, stamp):
    return f"Done means: {accept or '(the plan names no accept line)'}\n\n[stamp: {stamp}]\n"


def stamp_group(stamp):
    return (stamp or "").split(".")[0] or None


def desc_state(desc):
    m = re.search(r"^plan-status: (\w+) \(", desc or "", re.M) or re.search(r"plan-sync · plan \d+ · (\w+) \(", desc or "")
    return m.group(1) if m else None


# ── the sync ─────────────────────────────────────────────────────────────────────────────────

def build_board(home, row):
    board = row.get("board") or {}
    if not board:
        raise Refusal(f"project '{row.get('id')}' has no board: block in the registry")
    if board.get("adapter") != "mcp":
        raise Refusal(f"board.adapter '{board.get('adapter')}' has no adapter yet — only 'mcp' exists")
    place, mcpc = board.get("place"), board.get("mcp") or {}
    if not place or not mcpc.get("url") or not mcpc.get("token_from"):
        raise Refusal("board.place, board.mcp.url and board.mcp.token_from are all required")
    root = os.environ.get("YMIR_ROOT") or os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    refs = mcpc["token_from"] if isinstance(mcpc["token_from"], list) else [mcpc["token_from"]]
    why = []
    for ref in refs:
        try:
            return place, McpBoard(place, mcpc["url"], resolve_token(ref, home, root))
        except BoardRefusal as e:
            why.append(str(e))
    raise Refusal("this seat has no road to the board — " + "; ".join(why))


class Sync:
    def __init__(self, home, row, place, board, dry):
        self.home, self.row, self.place, self.board, self.dry = home, row, place, board, dry
        self.n = {"created": 0, "upgraded": 0, "updated": 0, "unchanged": 0, "steps": 0, "found": 0, "failed": 0}
        self.failed, self.undrawn = [], []
        self.heads = phase_heads((row.get("board") or {}).get("phase_heads"))

    def note_diagrams(self, p, out):
        for f in ((out or {}).get("diagrams") or {}).get("failed") or []:
            self.undrawn.append(f"plan {p['num']} diagram {f.get('block')}: {f.get('why')}")

    def found_by_title(self, title, parent=None):
        """The card with exactly this title (top-level, or under `parent`), asked for by name; None when none answers."""
        for c in self.board.find_cards(None if parent is not None else LABEL, title[:60]):
            # the parent must be THIS card (or none, for a plan card): a same-titled step under another card is not ours
            if c.get("title") == title and str(c.get("parent")) == str(parent):
                return c.get("card")
        return None

    def one(self, p, card, children):
        text, cut = plan_body(p)
        md = card_markdown(p, text, cut)
        stamp = f"{p['group']}.{short(card_title(p) + md)}"
        desc = with_stamp(md, p, stamp)
        title = card_title(p)
        phases = read_phases(text, self.heads)
        source = f"{p['rel']}#plan-{p['num']}"

        if card is None:
            if not self.dry:
                # A SHORT LISTING IS NOT AN EMPTY BOARD (2026-11-21). While the board's door reloads (a restart meets
                # Plane's 429), list_all can come back without cards that exist, and a plan looked new: two runs that
                # night left four cards for plan 340 and two for 343. So the title is asked for once more, by name,
                # just before a create; a card that answers is left for the next run's full listing, never doubled.
                twin = self.found_by_title(title)
                if twin is not None:
                    print(f"found   {title}  as #{twin} — the listing missed it; the next run carries it")
                    self.n["found"] += 1
                    return
            print(f"create  {title}  [{p['group']}] phases={len(phases)}")
            if self.dry:
                self.n["created"] += 1
                return
            out = self.board.create_card(title, desc, p["group"], [LABEL], fmt="markdown", source=source)
            self.note_diagrams(p, out)
            num = out.get("card")
            if num is None:  # an older board names no number: find the card it just made
                num = next((c["card"] for c in self.board.find_cards(LABEL, title[:40]) if c["title"] == title), None)
            self.link(p, num, fresh=True)
            self.steps(p, num, phases, {}, fresh=True)
            self.n["created"] += 1
            return

        num = card["card"]
        if card.get("stamp") == stamp and card["title"] == title and self.steps_whole(p, phases, children):
            self.n["unchanged"] += 1
            return
        ours = card.get("stamp") is not None
        change = {}
        if card["title"] != title:
            change["title"] = title
        if card.get("stamp") != stamp:
            change["description"] = desc
        if card["group"] != p["group"]:
            last = stamp_group(card.get("stamp"))
            if last is None and not self.dry:
                last = desc_state(self.board.get_card(num).get("description"))
            if last != p["group"]:  # the ledger moved, so the card follows; else the board moved it by hand
                change["group"] = p["group"]
        kind = "update" if ours else "upgrade"
        print(f"{kind:7} #{num} {title}  {sorted(change) or ['steps']}")
        if self.dry:
            self.n["updated" if ours else "upgraded"] += 1
            return
        if not ours:
            self.link(p, num, fresh=False)
        self.steps(p, num, phases, children, fresh=False)
        if change:
            # the description (with its stamp) is written LAST: a stamp on the card means its link and steps stand
            out = self.board.update_card(num, title=change.get("title"), description=change.get("description"),
                                         group=change.get("group"), fmt="markdown")
            self.note_diagrams(p, out)
        self.n["updated" if ours else "upgraded"] += 1

    def link(self, p, num, fresh):
        url = file_url(self.home, self.row, p["rel"])
        if not url or num is None:
            return
        if not fresh:
            if any(l.get("url") == url for l in self.board.get_card(num).get("links") or []):
                return
        try:
            self.board.add_link(num, url, f"Plan file in the {p.get('where', 'home')}")
        except BoardRefusal as e:
            # Plane says the link is there when its listing spelled it otherwise (plan 111, 2026-11-21): it stands
            if "already exists" not in str(e):
                raise

    def steps_whole(self, p, phases, children):
        for pid, name, accept in phases:
            want, prefix = phase_title(p["num"], pid, name)
            c = next((c for c in children if c["title"].startswith(prefix)), None)
            if c is None or c["title"] != want or c.get("stamp") != f"step.{short(want + accept)}":
                return False
        return True

    def steps(self, p, num, phases, children, fresh):
        if num is None or not phases:
            return
        kids = [] if fresh else children
        start = p["group"] if p["group"] in ("done", "cancelled") else "unstarted"
        for pid, name, accept in phases:
            want, prefix = phase_title(p["num"], pid, name)
            stamp = f"step.{short(want + accept)}"
            c = next((c for c in kids if c["title"].startswith(prefix)), None)
            if c is None and not fresh and self.found_by_title(want, parent=num) is not None:
                continue   # a short listing hid this step; asked by name, it is there — never doubled
            if c is None:
                self.board.create_card(want, phase_markdown(accept, stamp), start, [], parent=num, fmt="markdown",
                                       source=f"{p['rel']}#phase-{pid}")
                self.n["steps"] += 1
            elif c["title"] != want or c.get("stamp") != stamp:
                self.board.update_card(c["card"], title=want if c["title"] != want else None,
                                       description=phase_markdown(accept, stamp), fmt="markdown")
                self.n["steps"] += 1


def run_project(home, row, args, only=None):
    place, board = build_board(home, row)
    ledger_rel, ledger_abs = ledger_dir(home, row)
    plans = read_plans(ledger_rel, ledger_abs, args.include_old, (row.get("board") or {}).get("status_map"))
    plans_by_num = {}
    for p in plans:
        plans_by_num.setdefault(p["num"], []).append(p)
    if only is not None:
        plans = [p for p in plans if p["num"] in only or os.path.realpath(p["abs"]) in only]
        if not plans:
            raise Refusal(f"no plan {sorted(map(str, only))} in the ledger {ledger_rel}")

    if board.ensure_label(LABEL, dry=args.dry_run):
        print(f"label '{LABEL}': {'would create' if args.dry_run else 'created'} in {place}")
    every = board.list_all()
    if board.saturated and not args.dry_run:
        raise Refusal("the board cannot list a place to its end (it answers no `offset`), so older cards may be hidden "
                      "and a second pass would create them again. Nothing was written; run with --dry-run, or bring "
                      "the board's door up to the contract")
    by_num, kids = {}, {}
    for c in every:
        if c.get("parent") is not None:
            kids.setdefault(c["parent"], []).append(c)
        m = TITLE_RE.match(c["title"])
        if m and LABEL in c["labels"] and c.get("parent") is None:
            by_num.setdefault(int(m.group(1)), []).append(c)

    s = Sync(home, row, place, board, args.dry_run)
    for p in plans:
        cands, want = by_num.get(p["num"], []), card_title(p)
        card = next((c for c in cands if c["title"] == want), None)
        if card is None and len(plans_by_num[p["num"]]) == 1 and len(cands) == 1:
            card = cands[0]  # the same plan under a new title
        try:
            s.one(p, card, kids.get(card["card"], []) if card else [])
        except BoardRefusal as e:
            s.n["failed"] += 1
            s.failed.append(f"plan {p['num']} ({p['rel']}): {e}")
            print(f"failed  {want}: {e}", file=sys.stderr)

    mode = "dry-run " if args.dry_run else ""
    n = s.n
    print(f"plan-sync {mode}{place}: plans={len(plans)} created={n['created']} upgraded={n['upgraded']} "
          f"updated={n['updated']} unchanged={n['unchanged']} steps={n['steps']} found={n['found']} failed={n['failed']}")
    if only is None and not args.dry_run:
        after = [c for c in board.list_all() if TITLE_RE.match(c["title"]) and LABEL in c["labels"]
                 and c.get("parent") is None]
        nums = {int(TITLE_RE.match(c["title"]).group(1)) for c in after}
        missing = sorted({p["num"] for p in plans} - nums)
        print(f"count {place}: ledger={len({p['num'] for p in plans})} plans · board={len(nums)} plan cards"
              + (f" · missing: {', '.join(map(str, missing))}" if missing else ""))
    for line in s.failed:
        print(f"not synced: {line}")
    for line in s.undrawn:
        print(f"not drawn (kept as code): {line}")
    return 1 if s.failed else 0


def main(argv):
    ap = argparse.ArgumentParser(prog="plan-sync.sh", description="mirror a plan ledger onto its board, one whole card per plan")
    ap.add_argument("--project", help="the registry id (or name) whose ledger to mirror")
    ap.add_argument("--plan", action="append", type=int, help="only this plan number (repeatable)")
    ap.add_argument("--file", action="append", help="only this plan file; its project is found from the registry")
    ap.add_argument("--road", action="store_true", help="only say whether this seat has a road to the board, and exit")
    ap.add_argument("--dry-run", action="store_true", help="print what would change; write nothing")
    ap.add_argument("--include-old", action="store_true", help="also mirror the reference archive old-plans/")
    args = ap.parse_args(argv)
    if not args.project and not args.file:
        ap.error("name --project or --file")
    try:
        home = home_root()
        if args.file:
            rows = {}
            for f in args.file:
                r = project_for_file(home, f)
                rows.setdefault(r["id"], (r, set()))[1].add(os.path.realpath(f))
            if args.road:
                for r, _ in rows.values():
                    place, _b = build_board(home, r)
                    print(f"plan-sync: road ok — {r['id']} → {place}")
                return 0
            return max(run_project(home, r, args, only) for r, only in rows.values())
        row = load_project(home, args.project)
        if args.road:
            place, _b = build_board(home, row)
            print(f"plan-sync: road ok — {row['id']} → {place}")
            return 0
        return run_project(home, row, args, set(args.plan) if args.plan else None)
    except BoardRefusal as e:
        print(f"plan-sync: refused — {e}", file=sys.stderr)
        return 1
    finally:
        cleanup()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

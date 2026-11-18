#!/usr/bin/env python3
"""plans_state.py — the plans, as data: every shelf the registry names, read once (plan 298 §2.1).

The engine behind `bin/records/plans-state.sh` and behind `bin/day/day.sh plans`. It reads the
home's project registry, walks every plan shelf that registry names, and answers one question per
plan: **is it done, and what proves it?**

    plans_state.py                 write $YMIR_HOME/hodd/registry/plans-state.yaml
    plans_state.py --stdout        print it instead of writing it
    plans_state.py --json          the same data as JSON, for a surface
    plans_state.py --check         exit 1 on an absent shelf or a colliding plan number
    plans_state.py --with-prs      ask GitHub whether a named PR merged (the one network call)
    plans_state.py --self-test     prove done-vs-open, and the unreadable-shelf rule, on a fixture
    plans_state.py --fixture DIR   write a fixture home at DIR and print its path (the test's setup)

The rule this file obeys, and the reason it exists (plan 298):

  • **a state it cannot measure is `open`, never `done`** — silence is not finished work, the same
    rule the merge gate uses;
  • every state carries its **evidence**: the header line, the register row, or the merged PR;
  • a shelf the registry names and that is not there is reported **absent with its path** — never
    counted as an empty shelf, because those are different facts;
  • it writes exactly one file, the generated registry, and that file is git-ignored.

Where the shelves come from — `hodd/identity/projects.yaml`, per project:

    records.in_home.plans         a shelf inside the home   ($YMIR_HOME/<path>)
    records.in_home.plan_index    its index (informational)
    records.in_repo.plans_ledger  a shelf inside the project's own repository
    records.in_repo.plans         the same, under its older key

A plan's declared state is read from its header, first match wins: `state:` (the convention this
plan adds) then `Status:` (the convention `plan-state.sh` already writes). Recognised values are
done · blocked · owed · building · parked · superseded · open; anything else, and any plan with no
line at all, is `open`.

Exit: 0 · 1 --check found something · 2 the home or the registry could not be read.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - the home's registries are YAML; without it nothing can be read
    yaml = None

REGISTRY = Path("hodd/identity/projects.yaml")
STATE_FILE = Path("hodd/registry/plans-state.yaml")

# Where a project's own repository may sit when the registry names a shelf inside it. Tried in
# order; a shelf whose repo is on none of them is reported absent, never guessed at.
REPO_ROOTS = ("CodeP", "Code", "src", "Projects", "repos")

# Files on a plan shelf that are not plans.
NOT_PLANS = {"readme.md", "register.md", "queue.md", "questions.md", "index.md"}

# A shelf that has been retired to reference: still counted if asked, never open work.
RETIRED_DIRS = {"old-plans", "archive", "archived", "retired"}

# The folder a plan sits in is the shelf's own word on it — a ticket shelf files its work under
# `open/`, `in-progress/`, `review/` and `done/`, and a door that ignored that would call six
# finished plans open. A leading `_` marks a template (`_templates/`), which is nobody's work.
FOLDER_STATE = {
    "done": "done", "closed": "done", "complete": "done", "completed": "done",
    "shipped": "done", "merged": "done",
    "building": "building", "in-progress": "building", "in_progress": "building",
    "wip": "building", "doing": "building", "review": "building", "in-review": "building",
    "blocked": "blocked", "owed": "owed", "parked": "parked",
}


def folder_state(parts) -> tuple[str, str]:
    """(the state a plan's folder declares, the folder that said it) — the nearest folder wins."""
    for part in reversed([p.lower() for p in parts]):
        if part in FOLDER_STATE:
            return FOLDER_STATE[part], part
    return "", ""


def is_template(rel_parts, name: str) -> bool:
    return name.startswith("_") or any(p.lower().startswith("_") for p in rel_parts)

DONE_WORDS = {"done", "closed", "shipped", "complete", "completed", "answered", "merged", "landed"}
BUILDING_WORDS = {"building", "in progress", "in-progress", "partial", "wip", "started", "active", "opened"}
PARKED_WORDS = {"parked", "on hold", "on-hold", "paused", "deferred", "someday"}
SUPERSEDED_WORDS = {"superseded", "retired", "replaced", "absorbed", "obsolete"}
BLOCKED_WORDS = {"blocked", "waiting", "needs-decision", "needs decision", "needs-owner", "ask"}
OWED_WORDS = {"owed"}

# The words that make a state. Order matters: done is checked before building, because
# "done (diagnosed)" and "shipped — see PR" both begin with a done word.
STATE_WORDS = [
    ("done", DONE_WORDS),
    ("building", BUILDING_WORDS),
    ("parked", PARKED_WORDS),
    ("superseded", SUPERSEDED_WORDS),
    ("blocked", BLOCKED_WORDS),
    ("owed", OWED_WORDS),
]


# ── the home and the tree ────────────────────────────────────────────────────────────────────────

def home_dir(arg: str | None) -> Path:
    """The home, resolved by bin/vault/hoard-lib.sh (the wrapper exports it) — never guessed (RULES/07)."""
    raw = arg or os.environ.get("YMIR_HOME", "")
    if not raw:
        raise SystemExit(
            "plans-state: YMIR_HOME is unresolved — run bin/records/plans-state.sh (it asks the resolver), or pass --home")
    h = Path(raw).expanduser()
    if not h.is_dir():
        raise SystemExit("plans-state: no home at %s" % h)
    return h


def repo_root() -> Path:
    """This checkout — exported by the wrapper, else found by walking up for RULES/ and .agents/."""
    env = os.environ.get("YMIR_REPO_ROOT")
    if env and Path(env).is_dir():
        return Path(env)
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "RULES").is_dir() and (parent / ".agents").is_dir():
            return parent
    return here.parents[1]


def as_of() -> str:
    return dt.datetime.now().astimezone().replace(microsecond=0).isoformat()


# ── the registry ─────────────────────────────────────────────────────────────────────────────────

def load_registry(home: Path) -> list[dict]:
    path = home / REGISTRY
    if not path.is_file():
        raise SystemExit("plans-state: no project registry at %s" % REGISTRY)
    if yaml is None:
        raise SystemExit("plans-state: PyYAML is required to read %s (pip install pyyaml)" % REGISTRY)
    doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    projects = doc.get("projects") if isinstance(doc, dict) else doc
    if not isinstance(projects, list):
        raise SystemExit("plans-state: %s carries no `projects:` list" % REGISTRY)
    return [p for p in projects if isinstance(p, dict)]


def repo_candidates(name: str) -> list[Path]:
    """Where a project's own checkout plausibly sits, when the registry names a shelf inside it."""
    out: list[Path] = []
    for base in REPO_ROOTS:
        out.append(Path.home() / base / name)
    return out


def resolve_repo(project: dict, home: Path) -> tuple[Path | None, str]:
    """The project's checkout, or (None, why it could not be found).

    A registry `repo:` is one of: a local path (`.`, or a folder named relative to the home), or a remote slug
    (`github.com/owner/repo`, `owner/repo`). A local path is resolved; a slug is found by name
    under the usual code shelves. Nothing is cloned and nothing is guessed.
    """
    raw = str(project.get("repo") or "").strip()
    if not raw:
        return None, "the registry names no repository"
    if raw in (".", "./"):
        return repo_root(), ""
    looks_local = raw.startswith(("/", ".", "~")) or "/" not in raw
    if looks_local:
        cand = Path(raw).expanduser()
        for base in (home.parent, home, Path.home()):
            p = (base / cand) if not cand.is_absolute() else cand
            if p.is_dir():
                return p.resolve(), ""
        return None, "no checkout at %s (tried beside the home and in it)" % raw
    name = raw.rstrip("/").split("/")[-1]
    for cand in repo_candidates(name):
        if cand.is_dir():
            return cand.resolve(), ""
    return None, "no checkout of %s on this machine (looked for %s under %s)" % (
        raw, name, ", ".join("~/" + r for r in REPO_ROOTS))


def shelves_for(home: Path, project: dict) -> list[dict]:
    """Every plan shelf this project's records name, resolved — present or absent, but named."""
    records = project.get("records") or {}
    in_home = records.get("in_home") or {}
    in_repo = records.get("in_repo") or {}
    pid = str(project.get("id") or "?")
    realm = str(project.get("realm") or "")
    index = in_home.get("plan_index") or ""
    out: list[dict] = []

    def add(source: str, rel: str, root: Path | None, why: str = "") -> None:
        entry = {"project": pid, "realm": realm, "source": source, "declared": rel}
        if root is None:
            entry.update(path="", state="absent", why=why or "the shelf's root could not be found")
            out.append(entry)
            return
        path = (root / rel).resolve() if not Path(rel).is_absolute() else Path(rel)
        entry["path"] = str(path)
        if path.is_dir():
            entry["state"] = "present"
        else:
            entry["state"] = "absent"
            entry["why"] = "the registry names this shelf and it is not there"
        out.append(entry)

    # the home's own shelf is the ordinary case
    if in_home.get("plans"):
        add("records.in_home.plans", str(in_home["plans"]).rstrip("/"), home)
    # a shelf inside the project's repository
    for key in ("plans_ledger", "plans"):
        if in_repo.get(key):
            root, why = resolve_repo(project, home)
            add("records.in_repo.%s" % key, str(in_repo[key]).rstrip("/"), root, why)
    for entry in out:
        entry["index"] = ""
        if index and entry["path"]:
            cand = home / index
            if cand.is_file():
                entry["index"] = str(cand)
    return out


# ── one plan ────────────────────────────────────────────────────────────────────────────────────

def normalize_state(raw: str) -> tuple[str | None, str]:
    """The canonical state for a declared word, or (None, what it said) when it is not a state."""
    text = (raw or "").strip()
    if not text:
        return None, ""
    # a header value is prose after a colon: "**Status:** plan — opened 2026-11-14 …"
    head = re.split(r"[—–\-,;(]|\.\s|\s\(", text, maxsplit=1)[0].strip().strip("*_` ").lower()
    head = re.sub(r"\s+", " ", head)
    if not head:
        return None, text
    for canonical, words in STATE_WORDS:
        if head in words:
            return canonical, text
    for canonical, words in STATE_WORDS:
        if any(head.startswith(w + " ") or head.startswith(w) for w in words):
            return canonical, text
    if head in ("open", "new", "plan", "planned", "proposed", "not started", "n/a", "-"):
        return "open", text
    return None, text


def header_fields(lines: list[str]) -> dict:
    """The declaration lines a plan may carry at the top, whichever convention wrote them."""
    fields: dict[str, str] = {}
    for line in lines:
        s = line.strip()
        m = re.match(r"^\*{0,2}(state|status|owner_name|owner|opened|date)\*{0,2}\s*:\s*\*{0,2}\s*(.+)$", s, re.I)
        if not m:
            continue
        key = m.group(1).lower()
        if key not in fields:                      # first wins: appended corrections never overwrite
            fields[key] = m.group(2).strip().strip("*").strip()
    return fields


def plan_title(lines: list[str], number: str | None) -> str:
    for line in lines:
        m = re.match(r"^#\s+(.+)$", line.strip())
        if not m:
            continue
        title = m.group(1).strip()
        title = re.sub(r"^plan\s+[0-9]+\s*[—–:-]\s*", "", title, flags=re.I)
        title = re.sub(r"^[0-9]+\s*[—–.:-]\s*", "", title)
        return title.strip()
    return ""


def is_plan_file(path: Path) -> bool:
    if path.suffix.lower() != ".md":
        return False
    if path.name.lower() in NOT_PLANS:
        return False
    return True


# A dated name is a REPORT, not an open plan: the shelf's own convention reserves `NNN-slug.md` for
# plans and `YYYY-MM-DD-slug.md` / `YYYYMMDDTHHMMZ-slug.md` for what was done or found on a day.
DATE_NAME = re.compile(r"^([0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]{8}T[0-9]{4}Z?)")
# A plan number is a short leading run, so `2026-11-05-report.md` can never become plan 2026.
NUMBER_NAME = re.compile(r"^([0-9]{1,4})[-_. ]")
# A ticket-form shelf (another project's own convention) numbers `plan-0001`, `bug-0012`: the kind is
# part of the number, so `plan-0001` and `bug-0001` are two plans and never one collision.
TICKET_NAME = re.compile(r"^([a-z]{2,12})-([0-9]{3,4})[-_. ]")


def is_report(path: Path) -> bool:
    return bool(DATE_NAME.match(path.name))


def plan_number(name: str) -> tuple[str, str]:
    """(the plan's number as it is spoken, why it is not numbered).

    `298-his-list.md` → `298`; `plan-0001-x.md` → `plan-0001`; a dated name → ``, "report";
    number zero → ``, "template" — a shelf keeps `bug-0000-short-description.md` as the shape to copy,
    and copying it is not work he owes anyone.
    """
    if DATE_NAME.match(name):
        return "", "report"
    m = NUMBER_NAME.match(name)
    if m:
        digits = m.group(1)
        return ("", "template") if int(digits) == 0 else (str(int(digits)), "")
    m = TICKET_NAME.match(name)
    if m:
        kind, digits = m.group(1), m.group(2)
        return ("", "template") if int(digits) == 0 else ("%s-%s" % (kind, digits), "")
    return "", ""


def parse_plan(path: Path) -> dict:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        return {"path": str(path), "number": None, "title": "", "state": "open",
                "evidence": ["unreadable — %s" % exc.__class__.__name__], "slug": path.stem}
    lines = text.splitlines()
    head = lines[:40]
    fields = header_fields(head)
    declared = fields.get("state") or fields.get("status") or ""
    which = "state:" if fields.get("state") else ("Status:" if fields.get("status") else "")
    state, _said = normalize_state(declared)
    evidence: list[str] = []
    if state:
        evidence.append("%s %s (%s)" % (which, state, "declared" if state != "open" else "declared open"))
    num, _why = plan_number(path.name)
    mtime = dt.datetime.fromtimestamp(path.stat().st_mtime)
    return {
        "path": str(path),
        "slug": path.stem,
        "number": num,
        "title": plan_title(lines, num),
        "owner": fields.get("owner", ""),
        "owner_name": fields.get("owner_name", ""),
        "declared": declared,
        "declared_by": which,
        "state": state or "open",
        "state_declared": bool(state),
        "evidence": evidence,
        "prs": pr_numbers(text),
        "mtime": mtime.astimezone().replace(microsecond=0).isoformat(),
        "age_days": (dt.datetime.now().astimezone() - mtime.astimezone()).days,
    }


def pr_numbers(text: str) -> list[int]:
    found = set()
    for m in re.finditer(r"\bPR\s*#\s*([0-9]+)", text):
        found.add(int(m.group(1)))
    for m in re.finditer(r"\bpull/([0-9]+)\b", text):
        found.add(int(m.group(1)))
    return sorted(found)


# ── the register ────────────────────────────────────────────────────────────────────────────────

def register_evidence(path: Path) -> dict[str, str]:
    """Plan number → the register's word on it: {"298": "done", "300": "blocked"}.

    A register row is `| area | ask | state | plan / where |`. Only rows that name a plan are
    joined to it; a row that names no plan is the register's business, not a plan's.
    """
    if not path.is_file():
        return {}
    out: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        s = line.strip()
        if not s.startswith("|"):
            continue
        cells = [c.strip().strip("*").strip() for c in s.strip("|").split("|")]
        if len(cells) < 3:
            continue
        refs: list[str] = []
        for c in cells:
            for m in re.finditer(r"\bplan\s+([0-9]+)", c, re.I):
                refs.append(str(int(m.group(1))))
        if not refs:
            continue
        state = None
        for c in cells:
            canon, _ = normalize_state(c)
            if canon:
                state = canon
                break
        if not state:
            continue
        for n in refs:
            # a done word outranks anything weaker for the same plan; otherwise the first word wins
            if state == "done" or out.get(n) not in ("done",):
                out[n] = state
    return out


# ── the PR check ───────────────────────────────────────────────────────────────────────────────

def gh_merged(number: int, slug: str) -> bool | None:
    """True when GitHub says the PR merged, False when it says otherwise, None when it cannot say."""
    if not shutil.which("gh"):
        return None
    cmd = ["gh", "pr", "view", str(number), "--json", "state,mergedAt"]
    if slug:
        cmd += ["--repo", slug]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=25)
    except (OSError, subprocess.SubprocessError):
        return None
    if out.returncode != 0:
        return None
    try:
        data = json.loads(out.stdout)
    except json.JSONDecodeError:
        return None
    return str(data.get("state", "")).upper() in ("MERGED",) or bool(data.get("mergedAt"))


def project_slug(project: dict) -> str:
    git = project.get("git") or {}
    owner, repo = git.get("owner"), git.get("repo")
    if owner and repo:
        return "%s/%s" % (owner, repo)
    return ""


# ── the build ──────────────────────────────────────────────────────────────────────────────────

def build(home: Path, *, with_prs: bool = False, include_old: bool = False) -> dict:
    """Read every shelf the registry names and answer, per plan, what state it is in and why."""
    projects = load_registry(home)
    by_id = {str(p.get("id") or ""): p for p in projects}
    shelves: list[dict] = []
    plans: dict[str, dict] = {}
    retired = 0
    reports = 0
    templates = 0

    named = [shelf for project in projects for shelf in shelves_for(home, project)]
    # one project may name the same relative shelf twice (inside the home and inside its own
    # repository). When one of the two answers, the absent twin is the same shelf said twice —
    # report the shelf that is there, and never a phantom beside it.
    present = {(s["project"], s["declared"]) for s in named if s["state"] == "present"}
    named = [s for s in named if not (s["state"] != "present" and (s["project"], s["declared"]) in present)]

    for shelf in named:
        if shelf["state"] != "present":
            shelves.append(shelf)
            continue
        root = Path(shelf["path"])
        found = 0
        for path in sorted(root.rglob("*.md")):
            if not is_plan_file(path):
                continue
            rel = path.relative_to(root)
            if any(part.lower() in RETIRED_DIRS for part in rel.parts[:-1]):
                retired += 1
                if not include_old:
                    continue
            elif is_template(rel.parts[:-1], path.name):
                templates += 1
                continue
            elif is_report(path):
                reports += 1
                if not include_old:
                    continue
            elif plan_number(path.name)[1] == "template":
                templates += 1
                continue
            plan = parse_plan(path)
            fstate, fdir = folder_state(rel.parts[:-1])
            if fstate:
                plan["evidence"].append("the shelf files it under %s/" % fdir)
                # done needs ONE witness; any other folder word only speaks when nothing else did
                if fstate == "done" or plan["state"] == "open":
                    plan["state"] = fstate
            plan["project"] = shelf["project"]
            plan["realm"] = shelf["realm"]
            plan["shelf"] = shelf["source"]
            plans[plan["path"]] = plan
            found += 1
        shelf["plans"] = found
        reg = root / "register.md"
        shelf["register"] = str(reg) if reg.is_file() else ""
        shelves.append(shelf)

    # the register joins a plan by number, per project
    registers: dict[str, dict[str, str]] = {}
    for shelf in shelves:
        if shelf.get("register") and shelf["state"] == "present":
            registers.setdefault(shelf["project"], {}).update(register_evidence(Path(shelf["register"])))

    for plan in plans.values():
        reg = registers.get(plan["project"]) or {}
        key = plan["number"] or ""
        # a register says `plan 203`; a ticket shelf names `plan-0044`. Both close the same way.
        said = reg.get(key) or reg.get(re.sub(r"\D", "", key).lstrip("0") or "-")
        if key and said:
            state = said
            plan["evidence"].append("register.md says %s" % state)
            # a declared state is the plan's own word and outranks the register, except that a
            # register `done` closes a plan the header still calls open — that is the whole point
            # of the join (the header lags, the register is where the ask is answered).
            if state == "done" or plan["state"] == "open":
                plan["state"] = state

    if with_prs:
        for plan in plans.values():
            if not plan["prs"]:
                continue
            slug = project_slug(by_id.get(plan["project"]) or {})
            for number in plan["prs"]:
                merged = gh_merged(number, slug)
                if merged:
                    plan["evidence"].append("PR #%d merged (GitHub)" % number)
                    plan["state"] = "done"
                    break
                if merged is False:
                    plan["evidence"].append("PR #%d not merged (GitHub)" % number)

    for plan in plans.values():
        if not plan["evidence"]:
            plan["evidence"].append("no state measured — open, because silence is not finished work")
        plan.pop("state_declared", None)

    ordered = sorted(plans.values(), key=lambda p: (p["project"],
                                                    int(re.sub(r"\D", "", p["number"]) or 0) if p["number"] else 10**6,
                                                    p["slug"]))
    counts = {"total": len(ordered)}
    for name in ("open", "building", "blocked", "owed", "parked", "superseded", "done"):
        counts[name] = sum(1 for p in ordered if p["state"] == name)
    return {
        "generator": "bin/records/plans-state.sh (plan 298)",
        "as_of": as_of(),
        "home": str(home),
        "with_prs": bool(with_prs),
        "shelves": shelves,
        "counts": counts,
        "retired_not_listed": retired,
        "reports_not_listed": reports,
        "templates_not_listed": templates,
        "plans": ordered,
    }


def findings(state: dict) -> list[str]:
    """What --check refuses: a shelf the registry names and that is absent, a number used twice."""
    out: list[str] = []
    for shelf in state["shelves"]:
        if shelf["state"] != "present":
            out.append("%s: the registry names %s and it is not there (%s)"
                       % (shelf["project"], shelf["declared"], shelf.get("why") or shelf["source"]))
    seen: dict[tuple[str, str], list[str]] = {}
    for plan in state["plans"]:
        if plan["number"]:
            seen.setdefault((plan["project"], plan["number"]), []).append(plan["path"])
    for (project, number), paths in sorted(seen.items()):
        if len(paths) > 1:
            out.append("%s: plan number %s is used by %d files (%s)"
                       % (project, number, len(paths), ", ".join(Path(p).name for p in paths)))
    return out


# ── printing ───────────────────────────────────────────────────────────────────────────────────

def yaml_scalar(value) -> str:
    if value is None:
        return '""'
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    return json.dumps(str(value), ensure_ascii=False)


def to_yaml(state: dict) -> str:
    """Hand-rendered so the file has no dependency and the bytes are the same on every machine."""
    lines = [
        "# GENERATED by bin/records/plans-state.sh — never hand-edit (plan 298 §2.1).",
        "# Read it, or ask the door: bin/day/day.sh plans. The registry and the ledgers are the truth.",
        "generator: " + yaml_scalar(state["generator"]),
        "as_of: " + yaml_scalar(state["as_of"]),
        "home: " + yaml_scalar(state["home"]),
        "with_prs: " + yaml_scalar(state["with_prs"]),
        "retired_not_listed: " + yaml_scalar(state["retired_not_listed"]),
        "reports_not_listed: " + yaml_scalar(state["reports_not_listed"]),
        "templates_not_listed: " + yaml_scalar(state["templates_not_listed"]),
        "counts:",
    ]
    for key, value in state["counts"].items():
        lines.append("  %s: %s" % (key, value))
    lines.append("shelves:")
    for shelf in state["shelves"]:
        lines.append("  - project: " + yaml_scalar(shelf["project"]))
        lines.append("    realm: " + yaml_scalar(shelf.get("realm", "")))
        lines.append("    source: " + yaml_scalar(shelf["source"]))
        lines.append("    declared: " + yaml_scalar(shelf["declared"]))
        lines.append("    state: " + yaml_scalar(shelf["state"]))
        lines.append("    path: " + yaml_scalar(shelf.get("path", "")))
        if shelf.get("why"):
            lines.append("    why: " + yaml_scalar(shelf["why"]))
        if shelf.get("plans") is not None:
            lines.append("    plans: " + str(shelf["plans"]))
    lines.append("plans:")
    for plan in state["plans"]:
        lines.append("  - project: " + yaml_scalar(plan["project"]))
        lines.append("    number: " + yaml_scalar(plan["number"]))
        lines.append("    title: " + yaml_scalar(plan["title"]))
        lines.append("    state: " + yaml_scalar(plan["state"]))
        lines.append("    owner: " + yaml_scalar(plan["owner"]))
        lines.append("    owner_name: " + yaml_scalar(plan["owner_name"]))
        lines.append("    age_days: " + str(plan["age_days"]))
        lines.append("    path: " + yaml_scalar(plan["path"]))
        if plan["evidence"]:
            lines.append("    evidence:")
            for item in plan["evidence"]:
                lines.append("      - " + yaml_scalar(item))
    return "\n".join(lines) + "\n"


def write_state(home: Path, state: dict) -> Path:
    dest = home / STATE_FILE
    dest.parent.mkdir(parents=True, exist_ok=True)
    # the folder is generated from top to bottom: one README for a person, one ignore so the home
    # never carries a conflict in a file it regenerates.
    ignore = dest.parent / ".gitignore"
    wanted = ("# generated by bin/records/plans-state.sh — the registry is the truth\n"
              "*\n!.gitignore\n!README.md\n")
    if not ignore.exists() or ignore.read_text(encoding="utf-8") != wanted:
        ignore.write_text(wanted, encoding="utf-8")
    (dest.parent / "README.md").write_text(
        "# The generated registries\n\n"
        "Every file here is **written by a door, never by a person**. Read them, do not edit them: "
        "the file they are generated from is the truth.\n\n"
        "| File | Written by | Generated from |\n|---|---|---|\n"
        "| `plans-state.yaml` | `bin/records/plans-state.sh` | `hodd/identity/projects.yaml` and every "
        "plan shelf it names |\n\n"
        "The shelf is git-ignored (see `.gitignore` beside this file) because a generated file that "
        "can conflict is a file that will.\n", encoding="utf-8")
    dest.write_text(to_yaml(state), encoding="utf-8")
    return dest


# ── a fixture home, and the proof ───────────────────────────────────────────────────────────────

def write_fixture(root: Path) -> Path:
    """A small home that exercises every way a plan can be open or done. Used by --self-test and the suite."""
    root = root.resolve()
    (root / "hodd/identity").mkdir(parents=True, exist_ok=True)
    shelf = root / "svartalfaheim/acme/projects/widget/plans"
    shelf.mkdir(parents=True, exist_ok=True)
    (root / "hodd/identity/projects.yaml").write_text(
        "projects:\n"
        "  - id: widget\n"
        "    realm: acme\n"
        "    records:\n"
        "      in_home:\n"
        "        plans: svartalfaheim/acme/projects/widget/plans/\n"
        "        plan_index: svartalfaheim/acme/projects/widget/plans/README.md\n"
        "  - id: gadget\n"
        "    realm: acme\n"
        "    records:\n"
        "      in_home:\n"
        "        plans: svartalfaheim/acme/projects/gadget/plans/\n"
        "  - id: elsewhere\n"
        "    realm: acme\n"
        "    repo: github.com/acme/nowhere\n"
        "    records:\n"
        "      in_repo:\n"
        "        plans: plans/\n",
        encoding="utf-8")
    (shelf / "README.md").write_text("# Index\n\nnot a plan\n", encoding="utf-8")
    (shelf / "001-a-thing-nobody-finished.md").write_text(
        "# Plan 001 — A thing nobody finished\n\nowner: project\nowner_name: widget\n\nNo state line at all.\n",
        encoding="utf-8")
    (shelf / "002-declared-done.md").write_text(
        "# Plan 002 — Declared done\n\nowner: project\nowner_name: widget\nstate: done\n\nShipped.\n",
        encoding="utf-8")
    (shelf / "003-register-says-done.md").write_text(
        "# Plan 003 — The register closed it\n\nowner: project\nowner_name: widget\n\nStill says nothing.\n",
        encoding="utf-8")
    (shelf / "004-pr-will-close-it.md").write_text(
        "# Plan 004 — Closed by its merged PR\n\nowner: project\nowner_name: widget\nstate: open\n\nLanded in PR #77.\n",
        encoding="utf-8")
    (shelf / "005-waiting-on-him.md").write_text(
        "# Plan 005 — Waiting on his word\n\nowner: operator\nowner_name: him\nstate: blocked\n\nHe must choose.\n",
        encoding="utf-8")
    (shelf / "register.md").write_text(
        "# The register\n\n| area | ask | state | plan / where |\n|---|---|---|---|\n"
        "| runtime | close the third plan | **done** | plan 003 |\n"
        "| runtime | something nobody planned | **open** | — |\n",
        encoding="utf-8")
    (shelf / "old-plans").mkdir(exist_ok=True)
    (shelf / "old-plans/01-retired.md").write_text("# 01 — retired reference\n", encoding="utf-8")
    (shelf / "2026-11-15-a-session-report.md").write_text("# 2026-11-15 — a session report, not a plan\n", encoding="utf-8")
    (shelf / "_templates").mkdir(exist_ok=True)
    (shelf / "_templates/plan-0000-short-description.md").write_text("# a shape to copy\n", encoding="utf-8")
    (shelf / "tickets/open").mkdir(parents=True, exist_ok=True)
    (shelf / "tickets/done").mkdir(parents=True, exist_ok=True)
    (shelf / "tickets/open/bug-0007-nothing-says-it-is-done.md").write_text(
        "# bug-0007 — nothing in the header says it is done\n", encoding="utf-8")
    (shelf / "tickets/done/feature-0062-filed-as-done.md").write_text(
        "# feature-0062 — the folder is the archive\n", encoding="utf-8")
    return root


def self_test() -> int:
    fails: list[str] = []

    def want(cond: bool, what: str) -> None:
        if not cond:
            fails.append(what)

    with tempfile.TemporaryDirectory() as t:
        root = write_fixture(Path(t) / "home")
        # a stub `gh` on PATH proves the merged-PR road offline, and that it is the ONLY network road
        fake_bin = Path(t) / "bin"
        fake_bin.mkdir()
        (fake_bin / "gh").write_text("#!/bin/sh\necho '{\"state\":\"MERGED\",\"mergedAt\":\"2026-11-15T00:00:00Z\"}'\n")
        (fake_bin / "gh").chmod(0o755)
        old_path = os.environ.get("PATH", "")
        os.environ["PATH"] = str(fake_bin) + os.pathsep + old_path
        try:
            state = build(root, with_prs=False)
            open_nums = [p["number"] for p in state["plans"] if p["state"] == "open"]
            done_nums = [p["number"] for p in state["plans"] if p["state"] == "done"]
            want("1" in open_nums, "an undeclared plan is open (001)")
            want("2" not in open_nums and "2" in done_nums, "a `state: done` header closes a plan (002)")
            want("3" in done_nums, "a register row saying done closes a plan (003)")
            want("4" in open_nums, "an open plan with an unasked PR stays open (004)")
            want(state["counts"]["blocked"] == 1, "a blocked plan is counted as blocked, not open")
            want(state["retired_not_listed"] == 1, "a retired reference plan is not listed as work")
            want(state["reports_not_listed"] == 1, "a dated report is not listed as an open plan")
            want(state["templates_not_listed"] == 1, "a template plan is not listed as work")
            want(len(state["plans"]) == 7, "exactly the seven real plans are listed (%d)" % len(state["plans"]))
            want("feature-0062" in done_nums, "a plan filed under done/ is done by the shelf's own word")
            want("bug-0007" in open_nums, "a plan filed under open/ and declaring nothing stays open")
            absent = [s for s in state["shelves"] if s["state"] == "absent"]
            want(len(absent) == 2, "a shelf the registry names and that is missing is absent, never empty")
            want(any("gadget" in s["project"] for s in absent), "the absent shelf names its project")
            want(all(p["evidence"] for p in state["plans"]), "every plan carries its evidence")

            with_prs = build(root, with_prs=True)
            four = [p for p in with_prs["plans"] if p["number"] == "4"][0]
            want(four["state"] == "done", "a merged PR closes the plan that names it (004)")
            want(any("PR #77 merged" in e for e in four["evidence"]),
                 "the merged-PR evidence is carried, not just the verdict")

            text = to_yaml(state)
            for want_line in ("plans:", "shelves:", "generator:", "state: "):
                want(want_line in text, "the registry yaml carries %r" % want_line)

            found = findings(state)
            want(any("gadget" in f for f in found), "--check names the absent shelf")
            want(not any("collide" in f for f in found), "--check invents no collision that is not there")

            # a number used twice is a finding
            dup = root / "svartalfaheim/acme/projects/widget/plans/005-a-second-five.md"
            dup.write_text("# 005 — a second five\n", encoding="utf-8")
            found2 = findings(build(root))
            want(any("number 5 is used by 2 files" in f for f in found2), "--check reports a colliding number")
            dup.unlink()

            dest = write_state(root, state)
            want(dest.is_file(), "the state file is written")
            want((dest.parent / ".gitignore").is_file(), "the generated shelf is git-ignored")
            want("plans: " in dest.read_text(encoding="utf-8"), "the written file parses as the shape it claims")
        finally:
            os.environ["PATH"] = old_path

    if fails:
        for f in fails:
            print("FAIL %s" % f)
        print("plans-state self-test: %d finding(s)" % len(fails))
        return 1
    print("plans-state self-test: held — open vs done by header, by register and by merged PR; "
          "a missing shelf says absent; a duplicate number is reported")
    return 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="plans-state.sh", description=__doc__.split("\n")[0])
    ap.add_argument("--home")
    ap.add_argument("--stdout", action="store_true")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--with-prs", action="store_true")
    ap.add_argument("--include-old", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--fixture", metavar="DIR")
    a = ap.parse_args(argv)

    if a.fixture:
        print(write_fixture(Path(a.fixture)))
        return 0
    if a.self_test:
        return self_test()

    home = home_dir(a.home)
    state = build(home, with_prs=a.with_prs, include_old=a.include_old)

    if a.check:
        problems = findings(state)
        for p in problems:
            print("plans-state: %s" % p)
        print("plans-state check: %s" % ("ok" if not problems else "%d finding(s)" % len(problems)))
        return 1 if problems else 0
    if a.json:
        print(json.dumps(state, indent=2))
        return 0
    if a.stdout:
        sys.stdout.write(to_yaml(state))
        return 0

    dest = write_state(home, state)
    c = state["counts"]
    print("plans-state: wrote %s" % dest)
    print("  %d plans · %d open · %d building · %d blocked · %d owed · %d done · %d retired not listed"
          % (c["total"], c["open"], c["building"], c["blocked"], c["owed"], c["done"], state["retired_not_listed"]))
    if state["reports_not_listed"] or state["templates_not_listed"]:
        print("  not listed as work: %d dated report(s), %d template(s)"
              % (state["reports_not_listed"], state["templates_not_listed"]))
    for shelf in state["shelves"]:
        if shelf["state"] == "present":
            print("  shelf %-14s %-28s %d plans" % (shelf["project"], shelf["source"], shelf.get("plans") or 0))
        else:
            print("  ABSENT %-13s %-28s %s" % (shelf["project"], shelf["source"], shelf["declared"]))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)

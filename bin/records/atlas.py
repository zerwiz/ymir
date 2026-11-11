#!/usr/bin/env python3
"""atlas.py — one page at the top of the home that says where we have it all (plan 251).

Reads the home's registries (hodd/identity/companies.yaml, hodd/identity/projects.yaml) and each company's realm folder
under svartalfaheim/, and renders hodd/ATLAS.md: per company — status, owners, board, projects (repository, local
clone), where its plans, documents, meetings and decisions live, what is open, and what has gone stale — then the doors
that cut across every company. A rendered view (RULES/34): regenerate it, never edit it; the registries are the truth.

  atlas.py                 write hodd/ATLAS.md and print where
  atlas.py --stdout        print the page instead of writing it
  atlas.py --check         exit 1 when a registry names a realm that has no folder
  atlas.py --self-test     render a fixture home and prove the sections and the check
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    import yaml  # noqa: F401
except ImportError:  # pragma: no cover
    yaml = None

STALE_DAYS = 7
SHELVES = [("plans", "plans"), ("docs", "documents"), ("meetings", "meetings"), ("trello", "Trello record"),
           ("projects", "project folders"), ("mail", "mail digests")]


def home_dir(arg: str | None) -> Path:
    h = Path(arg or os.environ.get("YMIR_HOME") or os.path.expanduser("~/Documents/ymirhome"))
    if not h.is_dir():
        raise SystemExit(f"atlas: YMIR_HOME is unresolved ({h}) — nothing is guessed")
    return h


def load(path: Path):
    if not path.exists():
        return None
    if yaml is None:
        raise SystemExit("atlas: PyYAML is required to read the registries (pip install pyyaml)")
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def as_list(doc, key: str) -> list[dict]:
    if doc is None:
        return []
    if isinstance(doc, list):
        return [d for d in doc if isinstance(d, dict)]
    v = doc.get(key)
    if isinstance(v, list):
        return [d for d in v if isinstance(d, dict)]
    if isinstance(v, dict):
        return [dict(val, id=k) for k, val in v.items() if isinstance(val, dict)]
    return []


def last_change(home: Path, rel: Path) -> str:
    """The date the shelf last changed, from git when the home is a repository, else from the files."""
    try:
        out = subprocess.run(["git", "-C", str(home), "log", "-1", "--format=%cs", "--", str(rel)],
                             capture_output=True, text=True, timeout=20).stdout.strip()
        if out:
            return out
    except Exception:
        pass
    p = home / rel
    stamps = [f.stat().st_mtime for f in p.rglob("*") if f.is_file()] if p.exists() else []
    return dt.date.fromtimestamp(max(stamps)).isoformat() if stamps else ""


def realm_name(entry: dict) -> str:
    r = str(entry.get("realm") or "").strip()
    if not r or " " in r or r.lower() in ("none", "-", "—"):
        return ""          # "none yet" and the like: a company without a folder is not a registry error
    return r.split("/")[-1]


def header(path: Path) -> dict:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")[:1500]
    except OSError:
        return {}
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    meta = {}
    for line in text[3:end].splitlines():
        k, _, v = line.partition(":")
        if k.strip() and not line.startswith(" "):
            meta[k.strip()] = v.strip()
    return meta


def open_decisions(realm_dir: Path) -> list[Path]:
    found = []
    for f in sorted(realm_dir.rglob("*.md")):
        if any(part.startswith(".") for part in f.parts):
            continue
        if f.name == "open-questions.md":
            found.append(f)
            continue
        m = header(f)
        if m.get("kind") == "decision" and m.get("status", "") not in ("live", "superseded", "archived"):
            found.append(f)
    return found


def people(entry: dict) -> str:
    for k in ("owners", "people", "owner"):
        v = entry.get(k)
        if isinstance(v, list):
            return ", ".join(str(x.get("name", x)) if isinstance(x, dict) else str(x) for x in v)
        if v:
            return str(v)
    return "—"


def render(home: Path) -> tuple[str, list[str]]:
    companies = as_list(load(home / "hodd/identity/companies.yaml"), "companies")
    projects = as_list(load(home / "hodd/identity/projects.yaml"), "projects")
    sv = home / "svartalfaheim"
    today = dt.date.today()
    problems: list[str] = []

    realms = {(realm_name(c) or str(c.get("id", ""))): c for c in companies if realm_name(c) or c.get("id")}
    for p in projects:
        r = realm_name(p)
        if r and r not in realms:
            realms[r] = {"id": r, "name": r, "status": "(no company entry)"}
    for r in {realm_name(p) for p in projects}:
        if r and not (sv / r).is_dir() and r not in ("personal", "none"):
            problems.append(f"realm `{r}` is named in a registry but `svartalfaheim/{r}/` does not exist")

    out = ["---", "kind: index", "status: live", f"verified: {today.isoformat()}",
           "verified_by: bin/records/atlas.sh (generated — do not edit; change the registries)", "owner: the operator",
           "---", "# The atlas — where we have it all", "",
           f"*Generated {today.isoformat()} from `hodd/identity/companies.yaml`, `hodd/identity/projects.yaml` and the "
           "folders under `svartalfaheim/`. Regenerate with `bin/records/atlas.sh`; to change it, change the registries.*",
           "", "## Start here", "",
           "- **What I do next:** `hodd/life/personal/me/todo.md`",
           "- **The order of the plans across everything:** `hodd/docs/masterplan.md`",
           "- **Personal working plans:** `hodd/plans/`",
           "- **How we work (runbooks, for people and agents):** `hodd/docs/runbooks/`",
           "- **What we learned (research):** `hodd/library/research/INDEX.md`",
           "- **Today and earlier days:** `hodd/memory/daily/`",
           "", "## The companies", ""]
    summary = ["| company | status | board | projects | plans last changed | open decisions |", "|---|---|---|---|---|---|"]
    sections = []
    for r in sorted(realms, key=lambda k: (str(realms[k].get("status", "")) == "personal", k)):
        c = realms[r]
        rd = sv / r
        # The board is declared in the registry (`board: trello | gimle`); a realm that keeps a trello/ record is Trello.
        declared = str(c.get("board", "")).strip().lower()
        board = "Trello" if declared == "trello" or (not declared and (rd / "trello").is_dir()) else "Gimlé"
        mine = [p for p in projects if realm_name(p) == r]
        plans_date = last_change(home, Path("svartalfaheim") / r / "plans") if (rd / "plans").is_dir() else ""
        stale = ""
        if plans_date:
            try:
                if (today - dt.date.fromisoformat(plans_date)).days > STALE_DAYS:
                    stale = " ⚠ stale"
            except ValueError:
                pass
        decisions = open_decisions(rd) if rd.is_dir() else []
        summary.append(f"| [{c.get('name', r)}](#{re.sub(r'[^a-z0-9]+', '-', str(c.get('name', r)).lower()).strip('-')}) "
                       f"| {c.get('status', '—')} | {board} | {len(mine)} | {plans_date or '—'}{stale} | {len(decisions)} |")
        s = [f"### {c.get('name', r)}", "",
             f"**Status:** {c.get('status', '—')} · **People:** {people(c)} · **Board:** {board} · "
             f"**Folder:** `svartalfaheim/{r}/`" if rd.is_dir() else f"**Status:** {c.get('status', '—')} · no folder yet", ""]
        if rd.is_dir():
            rows = []
            for shelf, label in SHELVES:
                d = rd / shelf
                if d.is_dir():
                    n = sum(1 for f in d.rglob("*") if f.is_file() and not f.name.startswith("."))
                    rows.append(f"- **{label}:** `svartalfaheim/{r}/{shelf}/` — {n} file(s), last changed "
                                f"{last_change(home, Path('svartalfaheim') / r / shelf) or '—'}")
            for led in sorted(list(rd.glob("projects/*/plans")) + list(rd.glob("workspace/*/plans"))):
                n = sum(1 for f in led.glob("*.md"))
                rows.append(f"- **plan ledger — {led.parent.name}:** `{led.relative_to(home)}/` — {n} plan(s), last changed "
                            f"{last_change(home, led.relative_to(home)) or '—'}")
            for f in ("entity.md", "AGENTS.md", "README.md"):
                if (rd / f).is_file():
                    rows.append(f"- **{f}:** `svartalfaheim/{r}/{f}`")
            s += rows or ["- (an empty folder)"]
        if decisions:
            s += ["", "**Open decisions:**"] + [f"- `{d.relative_to(home)}`" for d in decisions]
        if mine:
            s += ["", "| project | repository | on this machine |", "|---|---|---|"]
            host = os.uname().nodename
            for p in sorted(mine, key=lambda x: x.get("id", "")):
                clones = p.get("clones") or {}
                local = clones.get(host) if isinstance(clones, dict) else ""
                s.append(f"| {p.get('name', p.get('id'))} | `{p.get('repo', '—')}` | {('`' + local + '`') if local else '—'} |")
        sections += s + [""]
    out += summary + [""] + sections
    if problems:
        out += ["## Registry problems", ""] + [f"- {p}" for p in problems] + [""]
    return "\n".join(out) + "\n", problems


def self_test() -> int:
    fails = []
    with tempfile.TemporaryDirectory() as t:
        h = Path(t)
        (h / "hodd/identity").mkdir(parents=True)
        (h / "hodd/identity/companies.yaml").write_text(
            "companies:\n  - id: alpha\n    name: Alpha AB\n    realm: svartalfaheim/alpha\n    status: active\n"
            "    owners: [A, B]\n    board: trello\n"
            "  - id: beta\n    name: Beta AB\n    realm: none yet\n    status: forming\n")
        (h / "hodd/identity/projects.yaml").write_text(
            "projects:\n  - id: p1\n    name: Project One\n    realm: alpha\n    repo: org/p1\n"
            "  - id: p2\n    name: Orphan\n    realm: ghost\n    repo: org/p2\n")
        (h / "svartalfaheim/alpha/plans").mkdir(parents=True)
        (h / "svartalfaheim/alpha/plans/01.md").write_text("# a plan\n")
        (h / "svartalfaheim/alpha/trello").mkdir()
        (h / "svartalfaheim/alpha/projects/p1/plans").mkdir(parents=True)
        (h / "svartalfaheim/alpha/projects/p1/plans/01.md").write_text("# p\n")
        (h / "svartalfaheim/alpha/trello/open-questions.md").write_text("# q\n")
        (h / "svartalfaheim/alpha/docs").mkdir()
        (h / "svartalfaheim/alpha/docs/d.md").write_text("---\nkind: decision\nstatus: draft\n---\n# d\n")
        page, problems = render(h)
        for want in ("# The atlas", "## Start here", "Alpha AB", "| Trello |", "Project One", "`org/p1`",
                     "Open decisions", "open-questions.md", "docs/d.md", "Registry problems", "plan ledger — p1"):
            if want not in page:
                fails.append(f"missing: {want}")
        if "Beta AB" not in page:
            fails.append("a company with no folder yet is missing from the atlas")
        if not any("ghost" in p for p in problems):
            fails.append("a project in a realm with no folder was not reported")
        if any("none yet" in p for p in problems):
            fails.append("a company with no folder yet ('none yet') was reported as a registry error")
    for f in fails:
        print("FAIL", f)
    print(f"atlas self-test: {'ok' if not fails else str(len(fails)) + ' failure(s)'}")
    return 1 if fails else 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="atlas.sh", description=__doc__.split("\n")[0])
    ap.add_argument("--home")
    ap.add_argument("--stdout", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args(argv)
    if a.self_test:
        return self_test()
    h = home_dir(a.home)
    page, problems = render(h)
    if a.check:
        for p in problems:
            print(f"atlas: {p}")
        print(f"atlas check: {'ok' if not problems else str(len(problems)) + ' problem(s)'}")
        return 1 if problems else 0
    if a.stdout:
        sys.stdout.write(page)
        return 0
    dest = h / "hodd/ATLAS.md"
    dest.write_text(page, encoding="utf-8")
    print(f"atlas: wrote {dest} ({page.count(chr(10))} lines, {len(problems)} registry problem(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

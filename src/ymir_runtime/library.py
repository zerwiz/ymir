#!/usr/bin/env python3
"""library.py — the library of records: one corpus, one contract, one door.

Plan 115. The house had registers (doors, capabilities, features, law, skills) and no corpus:
a document was a loose `.md` in whatever folder a hand chose, with no shape, no status and
nothing that could tell a reader whether it was still true. And what an agent *looked up* —
the research it did online — was kept nowhere at all.

This is the one door over both halves.

    library.py check   [--repo R] [--home H] [--changed] [--shelf PATH]…
    library.py ask     <words…>  [--repo R] [--home H] [--k N]
    library.py index   [--home H]
    library.py research keep|list|show|find|index|check [--root DIR] …
    library.py self-test

**The contract is not invented here.** It is the one `.pi/extensions/ymirhome.ts` already
ships — `kind · status · verified · verified_by · supersedes · superseded_by · grade ·
aliases · canonical · origin · used_by · sensitivity · owner` — extended with `tags` and
`sources`. A document is TYPED when its first line is `---` and its header carries `kind`
and `status`. Two headers would be the same fault this library exists to kill, one level up.

**The research kind** (plan 115 §3): one episode = one question, the finding in OUR words, every
source that backed it, filed by date under the home's `hodd/library/research/<YYYY>/<MM>/`, with
`sources.json` for machines and `note.md` for humans, and `INDEX.md` regenerated from the
folders. A finding with no source is an opinion; an episode is never rewritten — a correction is
a new episode citing the old one. A negative result is worth keeping too: what was looked for and
not found, and the route tried.

Exit: 0 clean · 1 findings · 2 usage.
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

VERSION = "1.0.0"

# The contract as the harness enforces it (`.pi/extensions/ymirhome.ts`, HEADER_FIELDS),
# plus the two fields this library needs and that tool did not have.
HEADER_FIELDS = [
    "kind", "status", "verified", "verified_by", "supersedes", "superseded_by",
    "grade", "aliases", "canonical", "origin", "used_by", "sensitivity", "owner",
    "tags", "sources",
]
REQUIRED_FOR_TYPED = ("kind", "status")

# Where records live, per tree. A shelf that does not exist is reported, never invented.
REPO_SHELVES = ["docs/features", "docs/audits", "docs/fixes", "RULES", "docs/guides", "docs/developer-setup"]
HOME_SHELVES = [
    "hodd/library", "hodd/docs", "hodd/identity", "hodd/memory", "hodd/plans",
    "hodd/workspaces", "hodd/life", "hodd/data", "hodd/security", "hodd/evidence",
    "svartalfaheim",
]


def out(block: str, rows: list[list[str]], header: list[str]) -> None:
    print(f"{block}[{len(rows)}]{{{','.join(header)}}}:")
    for r in rows:
        print("  " + ",".join('"' + str(c or "").replace('"', "'").replace("\n", " ")[:160] + '"' for c in r))


def now_iso() -> str:
    return datetime.now().astimezone().replace(microsecond=0).isoformat()


def slugify(text: str, limit: int = 60) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return re.sub(r"-{2,}", "-", s)[:limit].strip("-") or "episode"


# ── the contract ────────────────────────────────────────────────────────────────────────────

def read_header(path: Path) -> dict:
    """The header block, if the file's first line is `---`. One shape, no YAML library."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return {}
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return {}
    meta: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            return meta
        if ":" in line and not line.startswith((" ", "\t", "-")):
            k, v = line.split(":", 1)
            meta[k.strip()] = v.strip()
    return {}


def is_typed(meta: dict) -> bool:
    return all(meta.get(k, "") != "" or k in meta for k in REQUIRED_FOR_TYPED) and all(k in meta for k in REQUIRED_FOR_TYPED)


def md_files(root: Path) -> list[Path]:
    if not root.is_dir():
        return []
    return sorted(p for p in root.rglob("*.md") if p.is_file() and ".git" not in p.parts and "node_modules" not in p.parts)


def shelf_coverage(root: Path, shelves: list[str], tree: str) -> list[list[str]]:
    rows = []
    for s in shelves:
        d = root / s
        if not d.is_dir():
            rows.append([tree, s, "absent", "", ""])
            continue
        files = md_files(d)
        typed = sum(1 for f in files if is_typed(read_header(f)))
        pct = f"{(100 * typed // len(files)) if files else 0}%"
        rows.append([tree, s, str(len(files)), str(typed), pct])
    return rows


def untyped_list(root: Path, shelves: list[str], cap: int = 40) -> list[Path]:
    bad: list[Path] = []
    for s in shelves:
        d = root / s
        for f in md_files(d):
            if not is_typed(read_header(f)):
                bad.append(f)
                if len(bad) >= cap:
                    return bad
    return bad


def cmd_check(a: dict) -> int:
    repo = Path(a["repo"]).expanduser() if a.get("repo") else None
    home = Path(a["home"]).expanduser() if a.get("home") else None
    rows: list[list[str]] = []
    if repo and repo.is_dir():
        rows += shelf_coverage(repo, REPO_SHELVES, "repo")
    if home and home.is_dir():
        rows += shelf_coverage(home, HOME_SHELVES, "home")
    if a.get("shelf"):
        rows = []
        for s in a["shelf"]:
            p = Path(s).expanduser()
            root = p if p.is_dir() else p.parent
            rows += shelf_coverage(root, [p.name], "shelf")
    out("library", rows, ["tree", "shelf", "md", "typed", "coverage"])
    if a.get("changed"):
        return check_changed(a)
    total = sum(int(r[2]) for r in rows if r[2] not in ("", "absent"))
    typed = sum(int(r[3]) for r in rows if r[3] not in ("", "absent"))
    print(f'library[1]{{documents,typed,untyped,coverage}}:\n  "{total}","{typed}","{total - typed}","{(100 * typed // total) if total else 0}%"')
    return 0


def git_changed(root: Path) -> list[Path]:
    try:
        p = subprocess.run(["git", "status", "--porcelain"], cwd=root, capture_output=True, text=True)
    except Exception:
        return []
    files: list[Path] = []
    for line in p.stdout.splitlines():
        if len(line) < 4:
            continue
        status, rel = line[:2], line[3:].strip()
        if status.strip() == "D" or not rel.endswith(".md"):
            continue
        f = root / rel
        if f.is_file():
            files.append(f)
    return files


def check_changed(a: dict) -> int:
    """The gate on the DIFF, not on history: a new or changed document must be typed."""
    roots = [Path(p).expanduser() for p in (a.get("repo"), a.get("home")) if a.get("root") or a.get("repo") or a.get("home")]
    roots = [p for p in roots if p and p.is_dir()]
    if not roots:
        return 0
    rows = []
    for root in roots:
        for f in git_changed(root):
            meta = read_header(f)
            if is_typed(meta):
                continue
            rel = f.relative_to(root).as_posix()
            rows.append([str(root.name), rel, "no header" if not meta else "header lacks " + ",".join(k for k in REQUIRED_FOR_TYPED if k not in meta)])
    if rows:
        out("library", rows, ["tree", "document", "why"])
        print("library: a changed document carries no contract header — run `ymir_header apply` (or add kind/status yourself) and commit it with the change", file=sys.stderr)
        return 1
    print('library[1]{changed,untyped}:\n  "every changed document is typed","0"')
    return 0


# ── ask: one query across the registers and the corpus ─────────────────────────────────────

REGISTERS = [
    ("door", "bin/README.md"),
    ("capability", ".agents/assets/agents/capabilities.md"),
    ("feature", "FEATURES.md"),
    ("law", "RULES/README.md"),
    ("skill", ".agents/skills/README.md"),
]


def cmd_ask(a: dict) -> int:
    repo = Path(a["repo"]).expanduser()
    home = Path(a["home"]).expanduser() if a.get("home") else None
    words = " ".join(a["words"]).strip()
    if not words:
        print("library: ask needs words", file=sys.stderr)
        return 2
    pat = re.compile(re.escape(words), re.I)
    rows: list[list[str]] = []
    for kind, rel in REGISTERS:
        f = repo / rel
        if not f.is_file():
            continue
        for line in f.read_text(encoding="utf-8", errors="replace").splitlines():
            if pat.search(line):
                text = re.sub(r"^\s*[\"|]?\s*", "", line).strip(" |")
                rows.append([kind, rel, text[:150]])
    # the law itself, by title, and the corpus
    for f in md_files(repo / "RULES"):
        for line in f.read_text(encoding="utf-8", errors="replace").split("\n")[:3]:
            if pat.search(line):
                rows.append(["rule", f.relative_to(repo).as_posix(), line.strip("# ")[:150]])
                break
    if home and home.is_dir():
        for f in md_files(home / "hodd/library"):
            meta = read_header(f)
            hay = " ".join([meta.get("question", ""), meta.get("finding", ""), meta.get("tags", "")])
            if pat.search(hay + " " + f.name):
                rows.append(["research", f.relative_to(home).as_posix(), meta.get("question", f.stem)[:150]])
    k = int(a.get("k") or 12)
    out("library", rows[:k], ["kind", "where", "what"])
    if not rows:
        return 1
    print(f'library[1]{{asked,matched}}:\n  "{words}","{len(rows)}"')
    return 0


# ── index: the shelf's own view ─────────────────────────────────────────────────────────────

def cmd_index(a: dict) -> int:
    home = Path(a["home"]).expanduser() if a.get("home") else None
    if not home:
        print("library: index needs --home (the study of the library is the home's)", file=sys.stderr)
        return 2
    lib = home / "hodd/library"
    rows = []
    for shelf in sorted(p for p in lib.iterdir() if p.is_dir()) if lib.is_dir() else []:
        files = md_files(shelf)
        typed = sum(1 for f in files if is_typed(read_header(f)))
        rows.append([shelf.name, str(len(files)), str(typed)])
    body = ["# The library — the corpus and its shelves", "",
            "**Generated by `bin/records/library.sh index`. Do not hand-edit.**", "",
            "One corpus: records typed by the contract in `RULES/34`. Views are rendered, never hand-appended.", "",
            f"library[{len(rows)}]{{shelf,documents,typed}}:"]
    for r in rows:
        body.append("  " + ",".join(f'"{c}"' for c in r))
    body.append("")
    (lib / "INDEX.md").write_text("\n".join(body), encoding="utf-8")
    print(f'library[1]{{index,shelves}}:\n  "{lib / "INDEX.md"}","{len(rows)}"')
    return 0


# ── the research kind ───────────────────────────────────────────────────────────────────────

def parse_sources(raw: list[str]) -> list[dict]:
    out_: list[dict] = []
    for item in raw:
        parts = item.split("|")
        url = parts[0].strip()
        if not re.match(r"^https?://", url):
            raise ValueError(f"a source must be an http(s) URL, not {url!r}")
        out_.append({"url": url,
                     "title": parts[1].strip() if len(parts) > 1 else url,
                     "kind": parts[2].strip() if len(parts) > 2 else "web",
                     "fetched": now_iso()})
    return out_


def write_note(path: Path, meta: dict, sources: list[dict]) -> None:
    lines = ["---"]
    for k in ("kind", "status", "verified", "verified_by", "owner", "tags", "sources", "question", "finding", "at", "route", "why"):
        v = meta.get(k, "")
        if isinstance(v, list):
            v = ", ".join(v)
        lines.append(f"{k}: {v}")
    lines += ["---", "", f"# {meta['question']}", "", meta["finding"], ""]
    if meta.get("why"):
        lines += ["## Why", "", meta["why"], ""]
    lines += ["## Sources", ""]
    for s in sources:
        lines.append(f"- [{s['title']}]({s['url']}) — {s['kind']}, fetched {s['fetched']}")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def episodes(root: Path) -> list[Path]:
    if not root.is_dir():
        return []
    return sorted(p for p in root.glob("[0-9][0-9][0-9][0-9]/[0-9][0-9]/*") if p.is_dir() and (p / "note.md").is_file())


def load(ep: Path) -> tuple[dict, list[dict]]:
    meta = read_header(ep / "note.md")
    try:
        sources = json.loads((ep / "sources.json").read_text(encoding="utf-8")).get("sources", [])
    except Exception:
        sources = []
    return meta, sources


def render_index(root: Path) -> str:
    rows = []
    for ep in episodes(root):
        meta, sources = load(ep)
        rows.append([meta.get("at", "")[:10], ep.name, meta.get("question", ""), meta.get("owner", ""), str(len(sources))])
    lines = ["# research — the library of what was learned outside", "",
             "**Generated by `bin/records/library.sh research index`. Do not hand-edit.**",
             "One episode per question, filed by the date it was kept. The note is in our own words;",
             "`sources.json` carries the pages behind it. See `RULES/35-the-research-is-kept.md`.", "",
             f"research[{len(rows)}]{{date,slug,question,owner,sources}}:"]
    for r in rows:
        lines.append("  " + ",".join('"' + c.replace('"', "'") + '"' for c in r))
    lines.append("")
    lines.append("*Nothing kept yet. The first research an agent does is the first row.*" if not rows
                 else "*A correction is a NEW episode citing the old one — never an edit.*")
    lines.append("")
    return "\n".join(lines)


def research_keep(a: dict) -> int:
    root = Path(a["root"]).expanduser()
    q, f = a.get("question", "").strip(), a.get("finding", "").strip()
    if not q or not f:
        print("research: --question and --finding are both required — a finding with no question is a note, not research", file=sys.stderr)
        return 2
    try:
        sources = parse_sources(a.get("source") or [])
    except ValueError as e:
        print(f"research: {e}", file=sys.stderr)
        return 2
    if not sources and not a.get("negative"):
        print("research: at least one --source is required — RULES/35 refuses an unsourced finding (or pass --negative for a recorded dead end)", file=sys.stderr)
        return 1
    at = now_iso()
    ep = root / at[:4] / at[5:7] / f"{at[:10]}-{a.get('slug') or slugify(q)}"
    if ep.exists():
        print(f"research: {ep} already exists — an episode is never rewritten; keep the correction as a new episode citing it", file=sys.stderr)
        return 1
    ep.mkdir(parents=True)
    write_note(ep / "note.md", {
        "kind": "research", "status": "live", "verified": at[:10],
        "verified_by": a.get("source_by", "the sources below"),
        "owner": a.get("who", ""), "tags": a.get("tag") or [],
        "sources": "see sources.json",
        "question": q, "finding": f, "at": at,
        "route": a.get("route", ""), "why": a.get("why", "")}, sources)
    (ep / "sources.json").write_text(json.dumps(
        {"episode": ep.name, "kept_at": at, "question": q, "route": a.get("route", ""),
         "negative": bool(a.get("negative")), "sources": sources}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (root / "INDEX.md").write_text(render_index(root), encoding="utf-8")
    out("research[1]{kept,slug,sources,index}", [[str(ep), ep.name, str(len(sources)), str(root / "INDEX.md")]], ["kept", "slug", "sources", "index"])
    return 0


def research_list(a: dict) -> int:
    root = Path(a["root"]).expanduser()
    rows = [[m.get("at", "")[:10], ep.name, m.get("question", ""), m.get("owner", ""), str(len(s))] for ep in episodes(root) for m, s in [load(ep)]]
    out("research", rows, ["date", "slug", "question", "owner", "sources"])
    return 0


def research_show(a: dict) -> int:
    root = Path(a["root"]).expanduser()
    want = a.get("slug") or " ".join(a["words"])
    for ep in episodes(root):
        if ep.name == want or ep.name.endswith(want):
            meta, sources = load(ep)
            out("research[1]{date,slug,question,owner,tags,route,status}",
                [[meta.get("at", "")[:10], ep.name, meta.get("question", ""), meta.get("owner", ""), meta.get("tags", ""), meta.get("route", ""), meta.get("status", "")]],
                ["date", "slug", "question", "owner", "tags", "route", "status"])
            print(f"\nfinding: {meta.get('finding','')}\n")
            out("sources", [[s.get("url", ""), s.get("title", ""), s.get("kind", "")] for s in sources], ["url", "title", "kind"])
            print(f"\nnote: {ep / 'note.md'}")
            return 0
    print(f"research: no episode matching {want!r}", file=sys.stderr)
    return 1


def research_find(a: dict) -> int:
    root = Path(a["root"]).expanduser()
    words = " ".join(a["words"]).lower()
    if not words:
        print("research: find needs words", file=sys.stderr)
        return 2
    rows = []
    for ep in episodes(root):
        meta, sources = load(ep)
        hay = " ".join([meta.get("question", ""), meta.get("finding", ""), meta.get("tags", ""),
                        " ".join(s.get("url", "") + " " + s.get("title", "") for s in sources)]).lower()
        if words in hay:
            rows.append([meta.get("at", "")[:10], ep.name, meta.get("question", "")[:90]])
    out("research", rows, ["date", "slug", "question"])
    return 0 if rows else 1


def research_check(a: dict) -> int:
    root = Path(a["root"]).expanduser()
    rows: list[list[str]] = []
    eps = episodes(root)
    for ep in eps:
        meta, sources = load(ep)
        neg = False
        try:
            neg = bool(json.loads((ep / "sources.json").read_text(encoding="utf-8")).get("negative"))
        except Exception:
            pass
        for key in ("question", "finding", "at", "kind", "status"):
            if not meta.get(key):
                rows.append(["header incomplete", ep.name, f"the note carries no `{key}` — RULES/34 requires kind, status, every research field"])
        if not sources and not neg:
            rows.append(["no source", ep.name, "sources.json is empty — an unsourced finding is an opinion"])
        for s in sources:
            if not re.match(r"^https?://", s.get("url", "")):
                rows.append(["bad source", ep.name, f"not an http(s) URL: {s.get('url','')!r}"])
        if meta.get("at", "")[:10] != ep.name[:10]:
            rows.append(["date drift", ep.name, f"folder says {ep.name[:10]}, note says {meta.get('at','')[:10]}"])
    if root.is_dir():
        cur = (root / "INDEX.md").read_text(encoding="utf-8") if (root / "INDEX.md").is_file() else ""
        if cur.strip() != render_index(root).strip():
            rows.append(["index stale", "INDEX.md", "run bin/records/library.sh research index — the index is derived"])
    if rows:
        out("research", rows, ["finding", "episode", "detail"])
        print(f"research: {len(rows)} finding(s)", file=sys.stderr)
        return 1
    print(f'research[1]{{episodes,sources}}:\n  "{len(eps)}","{sum(len(load(e)[1]) for e in eps)}"')
    print("research: every episode carries a question, a finding, its header and its sources; the index is current")
    return 0


def self_test() -> int:
    tmp = Path(tempfile.mkdtemp(prefix="library-selftest."))
    fails = 0

    def ok(name: str, cond: bool, why: str = "") -> None:
        nonlocal fails
        print(f'  "{"PASS" if cond else "FAIL"}","{name}","{"" if cond else why}"')
        if not cond:
            fails += 1

    def run(*args: str) -> subprocess.CompletedProcess:
        return subprocess.run([sys.executable, __file__, *args], capture_output=True, text=True)

    home = tmp / "home"
    (home / "hodd/library/research").mkdir(parents=True)
    (home / "hodd/docs").mkdir(parents=True, exist_ok=True)
    (home / "hodd/docs/typed.md").write_text("---\nkind: document\nstatus: live\n---\n\n# typed\n")
    (home / "hodd/docs/untyped.md").write_text("# untyped\n\nno header here\n")
    print("library-self-test[10]{status,check,why}:")
    ok("the self-test root is not the real home", "selftest" in str(tmp), str(tmp))

    r = run("check", "--home", str(home))
    ok("check counts typed and untyped", r.returncode == 0 and '"hodd/docs","2","1"' in r.stdout, r.stdout[-300:])

    rroot = home / "hodd/library/research"
    r = run("research", "keep", "--root", str(rroot), "--question", "does a door refuse an unsourced finding",
            "--finding", "yes, with exit 1", "--source", "https://example.org/a|A page", "--owner", "self-test")
    ok("a sourced episode is kept", r.returncode == 0, r.stderr)
    ep = rroot / datetime.now().strftime("%Y/%m") / f"{datetime.now().strftime('%Y-%m-%d')}-does-a-door-refuse-an-unsourced-finding"
    ok("note.md and sources.json exist", (ep / "note.md").is_file() and (ep / "sources.json").is_file(), str(ep))
    ok("the note is typed by the same contract", is_typed(read_header(ep / "note.md")), str(read_header(ep / "note.md")))
    r = run("research", "check", "--root", str(rroot))
    ok("a clean research shelf passes", r.returncode == 0, r.stdout + r.stderr)
    r = run("research", "keep", "--root", str(rroot), "--question", "no source here", "--finding", "refused")
    ok("an unsourced finding is refused", r.returncode == 1, r.stdout + r.stderr)
    r = run("research", "keep", "--root", str(rroot), "--question", "a dead end", "--finding", "not found anywhere", "--negative")
    ok("a negative result is kept without a source", r.returncode == 0, r.stderr)
    r = run("research", "keep", "--root", str(rroot), "--question", "does a door refuse an unsourced finding", "--finding", "again", "--source", "https://example.org/b")
    ok("an episode is never rewritten", r.returncode == 1, r.stdout + r.stderr)
    (ep / "sources.json").write_text('{"sources": []}', encoding="utf-8")
    r = run("research", "check", "--root", str(rroot))
    ok("check fails when the sources are emptied", r.returncode == 1, r.stdout)
    shutil.rmtree(tmp, ignore_errors=True)
    print(f"library-self-test: {'clean' if fails == 0 else str(fails) + ' failed'}")
    return 0 if fails == 0 else 1


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(__doc__)
        return 0 if argv else 2
    if argv[0] in ("-v", "--version", "version"):
        print(VERSION)
        return 0
    if argv[0] == "self-test":
        return self_test()

    cmd, rest = argv[0], argv[1:]
    sub = ""
    if cmd == "research" and rest and not rest[0].startswith("--"):
        sub, rest = rest[0], rest[1:]
    a: dict = {"root": "", "source": [], "words": [], "tag": [], "shelf": []}
    i = 0
    while i < len(rest):
        tok = rest[i]
        if tok.startswith("--"):
            key = tok[2:].replace("-", "_")
            vals: list[str] = []
            i += 1
            while i < len(rest) and not rest[i].startswith("--"):
                vals.append(rest[i])
                i += 1
            if key in ("source", "tag", "shelf"):
                a[key].extend(vals)
            elif key in ("negative",):
                a[key] = True
            else:
                a[key] = " ".join(vals)
        else:
            a["words"].append(tok)
            i += 1

    if cmd == "check":
        return cmd_check(a)
    if cmd == "ask":
        return cmd_ask(a)
    if cmd == "index":
        return cmd_index(a)
    if cmd == "research":
        if not a.get("root"):
            print("research: --root is required (the door resolves the home's research shelf)", file=sys.stderr)
            return 2
        table = {"keep": research_keep, "list": research_list, "show": research_show,
                 "find": research_find, "check": research_check}
        if sub == "index":
            root = Path(a["root"]).expanduser()
            root.mkdir(parents=True, exist_ok=True)
            (root / "INDEX.md").write_text(render_index(root), encoding="utf-8")
            print(f'research[1]{{index,episodes}}:\n  "{root / "INDEX.md"}","{len(episodes(root))}"')
            return 0
        if sub not in table:
            print(f"research: unknown subcommand {sub!r} — keep · list · show · find · index · check", file=sys.stderr)
            return 2
        return table[sub](a)
    print(f"library: unknown command {cmd!r} — check · ask · index · research · self-test", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

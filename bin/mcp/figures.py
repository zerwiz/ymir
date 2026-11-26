#!/usr/bin/env python3
"""figures.py — the figures served through the MCP, never copied into a project (plan 358, 2026-11-22 13:25).

A project carries only its own craft. Ymir's figures (`.agents/agents/*.md`) are offered by the MCP as PROMPTS; the
frame's skills and the current project's own skills as RESOURCES (listed small, read on need); and one tool,
`ymir_figure(name, task, project)`, returns a figure's KIT: its prompt, the skills to read for the task, the tools it
may use, the project's rules and OUTCOMES.md, and the well's top episodes. `ymir_research` is Huginn's road: search,
scrape only the main content, keep the finding in the library.

This module holds the logic with no dependency on the MCP SDK, so a test can call it; `ymir-mcp.py` registers it.
Nothing here writes a file into a project.
"""
from __future__ import annotations

import datetime
import json
import os
import re
import subprocess
import urllib.error
import urllib.request
from pathlib import Path

CAP = 3500  # characters of any one file a kit carries; the rest is read on need
WORD = re.compile(r"[a-z0-9]{3,}")
STOP = {"the", "and", "for", "with", "that", "this", "from", "into", "are", "was", "not", "all", "any", "use", "when"}


def _front(text: str) -> tuple[dict, str]:
    """Front matter as flat key -> text (a nested block is kept as the raw text under its key) and the body."""
    if not text.startswith("---"):
        return {}, text
    end = text.find("\n---", 3)
    if end < 0:
        return {}, text
    head, body = text[3:end], text[end + 4:].lstrip("\n")
    out: dict = {}
    for ln in head.splitlines():
        m = re.match(r"([A-Za-z_][\w-]*):\s*(.*)$", ln)
        if m:
            out[m.group(1)] = m.group(2).strip().strip("\"'")
    return out, body


def _words(text: str) -> set[str]:
    return {w for w in WORD.findall((text or "").lower()) if w not in STOP}


# ── the figures ──────────────────────────────────────────────────────────────────────────────

def figure_cards(root: Path) -> dict[str, dict]:
    """name -> {name, description, role, file, text, read_only}. The name is the card's `name:` (else the file's first
    word), so `forseti-reviewer.md` is `forseti`."""
    out: dict[str, dict] = {}
    d = Path(root) / ".agents" / "agents"
    for f in sorted(d.glob("*.md")) if d.is_dir() else []:
        text = f.read_text(encoding="utf-8", errors="replace")
        meta, body = _front(text)
        name = (meta.get("name") or f.stem.split("-")[0]).lower()
        out[name] = {"name": name, "description": meta.get("description", ""), "role": meta.get("role", ""),
                     "file": str(f), "text": text, "body": body,
                     "read_only": bool(re.search(r"^\s+edit:\s*deny", text, re.M))}
    return out


def figure_prompt(card: dict) -> str:
    """The card as a prompt: who the figure is and its laws. Front-matter plumbing (permissions, workspace patterns)
    stays out; the card's own words stay in."""
    head = f"You are {card['name'].capitalize()}. {card['description']}".strip()
    return f"{head}\n\n{card['body'].strip()}"[:20000]


# ── skills ───────────────────────────────────────────────────────────────────────────────────

def skills_in(base: Path, scope: str) -> list[dict]:
    """The skills a shelf holds, each as {scope, name, description, path}: front matter only, never the body."""
    out = []
    d = Path(base) / ".agents" / "skills"
    for f in sorted(d.glob("*/SKILL.md")) if d.is_dir() else []:
        try:
            meta, _ = _front(f.read_text(encoding="utf-8", errors="replace")[:4000])
        except OSError:
            continue
        out.append({"scope": scope, "name": meta.get("name") or f.parent.name,
                    "description": meta.get("description", ""), "path": str(f)})
    return out


def project_root(project: str = "", cwd: str = "") -> Path | None:
    """The project a session is about: a path given, else the git top-level of the session's working directory."""
    for cand in (project, cwd or os.getcwd()):
        if not cand:
            continue
        p = Path(os.path.expanduser(cand))
        if p.is_dir():
            r = subprocess.run(["git", "-C", str(p), "rev-parse", "--show-toplevel"], capture_output=True, text=True)
            if r.returncode == 0 and r.stdout.strip():
                return Path(r.stdout.strip())
    return None


def rank_skills(skills: list[dict], task: str, paths: list[str] | None = None, top: int = 5) -> list[dict]:
    """Skills whose name or description share words with the task (and its paths), best first. A skill the task does
    not touch is not listed: a figure the task does not need is not loaded."""
    want = _words(task) | _words(" ".join(paths or []))
    scored = []
    for s in skills:
        have = _words(s["name"].replace("-", " ")) | _words(s["description"])
        hit = len(want & have) + 2 * len(want & _words(s["name"].replace("-", " ")))
        if hit:
            scored.append((hit, s))
    return [s for _, s in sorted(scored, key=lambda x: -x[0])[:top]]


def task_paths(task: str) -> list[str]:
    return re.findall(r"[\w./-]+/[\w./-]+", task or "")


# ── the project's rules ──────────────────────────────────────────────────────────────────────

def project_rules(proj: Path | None) -> dict:
    """The project's own rules, small: the names of RULES/*.md (read on need), and OUTCOMES.md in full up to CAP."""
    if proj is None:
        return {"rules": [], "outcomes": ""}
    rules = [str(p.relative_to(proj)) for p in sorted((proj / "RULES").glob("*.md"))] if (proj / "RULES").is_dir() else []
    out = ""
    for name in ("OUTCOMES.md", "docs/OUTCOMES.md"):
        f = proj / name
        if f.is_file():
            out = f.read_text(encoding="utf-8", errors="replace")[:CAP]
            break
    return {"rules": rules, "outcomes": out}


# ── the tools ────────────────────────────────────────────────────────────────────────────────

READ_TOOLS = ("ymir_where", "ymir_rule", "ymir_find", "ymir_recall", "ymir_figure", "ymir_veil",
              "well_recall", "ymir_context", "ymir_pending")


def tools_for(card: dict, all_tools: list[str]) -> list[str]:
    """A figure that may not edit gets the reading doors and the Veil (its one mouth); the others get every door."""
    if card["read_only"]:
        return [t for t in all_tools if t in READ_TOOLS]
    return sorted(all_tools)


# ── the kit ──────────────────────────────────────────────────────────────────────────────────

def kit(root: Path, name: str, task: str, project: str, all_tools: list[str], recall) -> dict:
    cards = figure_cards(root)
    key = (name or "").lower().strip()
    card = cards.get(key) or next((c for k, c in cards.items() if k.startswith(key) and key), None)
    if card is None:
        return {"error": f"no figure named '{name}'", "figures": sorted(cards)}
    proj = project_root(project)
    paths = task_paths(task)
    frame = rank_skills(skills_in(root, "frame"), task + " " + card["description"], paths)
    mine = rank_skills(skills_in(proj, "project"), task, paths) if proj else []
    rules = project_rules(proj)
    return {"figure": card["name"], "prompt": figure_prompt(card), "project": str(proj) if proj else None,
            "skills": [{"scope": s["scope"], "name": s["name"], "path": s["path"],
                        "uri": f"ymir-skill://{s['scope']}/{s['name']}"} for s in frame + mine],
            "tools": tools_for(card, all_tools), "rules": rules["rules"], "outcomes": rules["outcomes"],
            "well": recall(task) if task else ""}


def render_kit(k: dict) -> str:
    if "error" in k:
        return f"{k['error']}. Figures: {', '.join(k['figures'])}."
    lines = [f"# Kit — {k['figure']}", f"project: {k['project'] or '(none: not inside a git repository)'}", "",
             "## Prompt", k["prompt"], "", "## Skills to read for this task (read on need; the uri is an MCP resource)"]
    lines += [f"- [{s['scope']}] {s['name']} — {s['path']}  ({s['uri']})" for s in k["skills"]] or ["- none match the task"]
    lines += ["", "## Tools it may use (Ymir MCP)", ", ".join(k["tools"]), "", "## The project's rules"]
    lines += [f"- {r}" for r in k["rules"]] or ["- none"]
    lines += ["", "## OUTCOMES.md", k["outcomes"] or "(the project has none)", "", "## The well, for this task",
              k["well"] or "(nothing recalled)"]
    return "\n".join(lines)


def read_skill(root: Path, scope: str, name: str, project: str = "") -> str:
    base = root if scope == "frame" else project_root(project)
    if base is None:
        return "no project: the session is not inside a git repository"
    for s in skills_in(base, scope):
        if s["name"] == name or Path(s["path"]).parent.name == name:
            return Path(s["path"]).read_text(encoding="utf-8", errors="replace")
    return f"no {scope} skill named '{name}'"


# ── Huginn's road ────────────────────────────────────────────────────────────────────────────

def _post(url: str, key: str, body: dict, timeout: int = 90) -> dict:
    req = urllib.request.Request(url, data=json.dumps(body).encode(), method="POST",
                                 headers={"Content-Type": "application/json",
                                          **({"Authorization": f"Bearer {key}"} if key else {})})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode() or "{}")


def firecrawl_env(root: Path) -> tuple[str, str]:
    """(api url, key): env first, then the home's secrets by reference — never a value in a file."""
    url, key = os.environ.get("FIRECRAWL_API_URL", ""), os.environ.get("FIRECRAWL_API_KEY", "")
    if not (url and key):
        try:
            out = subprocess.run(["bash", str(Path(root) / "bin" / "vault" / "hodd.sh"), "emit", "secrets/platform.env"],
                                 capture_output=True, text=True, timeout=30).stdout
            for k, v in re.findall(r"^(?:export )?(FIRECRAWL_API_URL|FIRECRAWL_API_KEY)=(.*)$", out, re.M):
                v = v.strip().strip("\"'")
                if k == "FIRECRAWL_API_URL":
                    url = url or v
                else:
                    key = key or v
        except (OSError, subprocess.SubprocessError):
            pass
    return (url or "https://api.firecrawl.dev").rstrip("/"), key


def _research_shelf(root: Path) -> Path | None:
    env = os.environ.get("YMIR_RESEARCH_ROOT")
    if env:
        return Path(env)
    home = os.environ.get("YMIR_HOME") or str(Path.home() / "Documents" / "ymirhome")
    shelf = Path(home) / "hodd" / "library" / "research"
    return shelf if shelf.is_dir() else None


def _norm(q: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", q.lower()).strip()


def kept_answer(root: Path, question: str, max_age_days: int = 7):
    """Ask before you read (plan 365 H1): a kept answer to the SAME question, newer than a week, is reused with
    no web call. Returns (finding, source) or None. A kept negative result is reused too, so a dead end is
    not walked twice."""
    shelf = _research_shelf(root)
    if not shelf:
        return None
    want = _norm(question)
    newest = None
    for f in shelf.rglob("*.md"):
        try:
            head = f.read_text(encoding="utf-8", errors="replace").split("---")
            meta = dict(ln.split(":", 1) for ln in (head[1] if len(head) > 2 else "").splitlines() if ":" in ln)
        except OSError:
            continue
        if _norm(meta.get("question", "").strip().strip('"')) != want:
            continue
        at = meta.get("at", "").strip().strip('"')
        try:
            age = (datetime.datetime.now(datetime.timezone.utc) - datetime.datetime.fromisoformat(at.replace("Z", "+00:00"))).days
        except ValueError:
            continue
        if age <= max_age_days and (newest is None or at > newest[0]):
            newest = (at, meta.get("finding", "").strip().strip('"'), meta.get("sources", "").strip().strip('[]"'))
    return newest[1:] if newest else None


def _shelf_rows(shelf):
    for f in shelf.rglob("*.md"):
        try:
            head = f.read_text(encoding="utf-8", errors="replace").split("---")
            meta = dict(ln.split(":", 1) for ln in (head[1] if len(head) > 2 else "").splitlines() if ":" in ln)
        except OSError:
            continue
        yield {k: v.strip().strip('"') for k, v in meta.items()}


def find_kept(query: str, shareable_only: bool = False, limit: int = 5, root=None):
    """Read-only search over the kept answers (plan 365 H3). `shareable_only` serves a collaborator: only an answer
    tagged `shareable` leaves this machine, so private research never does (the realm law)."""
    shelf = _research_shelf(root)
    if not shelf:
        return []
    words = set(_norm(query).split())
    rows = []
    for m in _shelf_rows(shelf):
        if shareable_only and "shareable" not in m.get("tags", ""):
            continue
        hay = set(_norm(m.get("question", "") + " " + m.get("finding", "")).split())
        score = len(words & hay)
        if score:
            rows.append((score, {"question": m.get("question", ""), "finding": m.get("finding", "")[:300],
                                 "source": m.get("sources", ""), "at": m.get("at", "")}))
    return [r for _, r in sorted(rows, key=lambda x: -x[0])[:limit]]


def heart_kept(question: str, ask=None):
    """The heart's kept answer to the SAME question (plan 365 H2) — fetched by THIS machine over the ssh ring, after
    its own shelf found nothing, and named by seat. The heart never answers for this machine; a heart that does not
    answer in 5 seconds changes nothing: the caller fetches the web itself. Returns (finding, 'source via <seat>')."""
    try:
        hosts = json.load(open(os.path.join(os.environ.get("YMIR_HOME") or str(Path.home() / "Documents" / "ymirhome"),
                                            "hodd", "data", "fleet.json"))).get("hosts", {})
    except (OSError, ValueError):
        return None
    me = os.uname().nodename.split(".")[0]
    seat = next((h for h, v in hosts.items() if "heart" in (v.get("roles") or []) and h != me), None)
    if not seat:
        return None
    spec = hosts[seat]
    dest = f"{spec['user']}@{spec.get('tailnet') or spec.get('lan') or seat}" if spec.get("user") else (spec.get("tailnet") or seat)
    code = ("import sys,json,re,os,pathlib;q=re.sub(r'[^a-z0-9]+',' ',sys.argv[1].lower()).strip();"
            "h=os.environ.get('YMIR_HOME') or os.path.expanduser('~/Documents/ymirhome');"
            "[print(json.dumps(m)) for f in pathlib.Path(h,'hodd/library/research').rglob('*.md') "
            "for m in [dict(l.split(':',1) for l in f.read_text(errors='replace').split('---')[1].splitlines() if ':' in l)] "
            "if re.sub(r'[^a-z0-9]+',' ',m.get('question','').strip().strip('\"').lower()).strip()==q]")
    run = ask or (lambda: subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=4", dest, "python3", "-c", repr(code), question],
                                         capture_output=True, text=True, timeout=8).stdout)
    try:
        lines = [json.loads(x) for x in run().splitlines() if x.strip()]
    except (OSError, subprocess.SubprocessError, ValueError):
        return None
    if not lines:
        return None
    m = max(lines, key=lambda x: x.get("at", ""))
    return m.get("finding", "").strip().strip('"'), f"{m.get('sources', '').strip().strip('[]\"')} (kept by {seat})"


def record_saving(cache: str, tokens_in: int, tokens_out: int, pages: int, seat_role: str = "") -> None:
    """Measure, never claim (plan 365 H4): one row per research call — kept-answer hit or miss, the page's tokens
    read, the tokens handed back. `ymir work` and Andhrimnir's report sum them per role and seat."""
    home = os.environ.get("YMIR_HOME") or str(Path.home() / "Documents" / "ymirhome")
    path = Path(os.environ.get("YMIR_RESEARCH_SAVING") or Path(home) / "state" / "research-saving.jsonl")
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a") as fh:
            fh.write(json.dumps({"at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                                 "cache": cache, "tokens_in": tokens_in, "tokens_out": tokens_out, "pages": pages,
                                 "role": os.environ.get("YMIR_WORK_ROLE", seat_role), "seat": os.uname().nodename.split(".")[0]}) + "\n")
    except OSError:
        pass


def research(root: Path, question: str, project: str = "", plan: str = "", post=_post, run=None, heart_ask=None) -> str:
    """Search, then scrape the best hit as markdown with only the main content; KEEP the finding (source, practice,
    which plan uses it) with `library.sh research keep`; answer short. A search with no hit is kept as a negative
    result, so nobody looks the same dead end up twice."""
    if not question.strip():
        return "ymir_research needs a `question`."
    kept = kept_answer(root, question)
    if kept:
        record_saving("hit", 0, len(kept[0]) // 4, 0)
        return f"{kept[0]}\n\nsource: {kept[1] or 'kept answer'}\nreused from the library (no web call)"
    kept = heart_kept(question, ask=heart_ask)
    if kept:
        record_saving("hit-heart", 0, len(kept[0]) // 4, 0)
        return f"{kept[0]}\n\nsource: {kept[1]}\nreused from the heart's kept answers (no web call)"
    url, key = firecrawl_env(root)
    if not key and "api.firecrawl.dev" in url:
        return "ymir_research: no Firecrawl key (FIRECRAWL_API_KEY) and no self-hosted FIRECRAWL_API_URL on this seat."
    try:
        hits = (post(f"{url}/v1/search", key, {"query": question, "limit": 3}) or {}).get("data") or []
        page, src = "", None
        for h in hits:
            u = h.get("url") or ""
            if not u.startswith("http"):
                continue
            got = (post(f"{url}/v1/scrape", key, {"url": u, "formats": ["markdown"], "onlyMainContent": True}) or {})
            md = ((got.get("data") or {}).get("markdown") or "").strip()
            if md:
                page, src = md, (u, h.get("title") or u)
                break
    except (urllib.error.URLError, OSError, ValueError) as e:
        return f"ymir_research: Firecrawl did not answer ({e}). Huginn's tools are down — run ymir_huginn with action 'up' (or bin/fleet/huginn-web.sh up)."
    answer = re.sub(r"\s+", " ", page)[:700]
    record_saving("miss", len(page) // 4, len(answer) // 4, 1 if page else 0)
    keep = ["bash", str(Path(root) / "bin" / "records" / "library.sh"), "research", "keep", "--question", question,
            "--owner", "huginn", "--tag", "research"] + (["--tag", project] if project else [])
    why = "practice: " + (f"read the page's main content, kept this summary; used by plan {plan}" if plan
                          else "read the page's main content, kept this summary")
    if src:
        keep += ["--finding", answer, "--source", f"{src[0]}|{src[1]}", "--why", why]
    else:
        keep += ["--finding", "no page answered this question", "--negative", "--why", "practice: searched, found nothing"]
    kept = (run or (lambda a: subprocess.run(a, capture_output=True, text=True, timeout=120)))(keep)
    ok = getattr(kept, "returncode", 1) == 0
    status = "kept in the library" if ok else f"NOT kept ({(getattr(kept, 'stderr', '') or '').strip()[:160]})"
    return (f"{answer}\n\nsource: {src[0]}\n{status}" if src else f"No page answered. {status}")

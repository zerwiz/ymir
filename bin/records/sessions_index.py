#!/usr/bin/env python3
"""sessions_index.py — every agent session on this machine, from every tool, read into one seat index (plan 368).

  sessions.sh scan [--since DAYS] [--tool T]    read new session bytes only (Claude, pi, Codex, Hermes, opencode)
  sessions.sh list [--project P] [--tool T] [--fleet] [--public-view]      sessions, newest first
  sessions.sh decisions [--fleet]               failures grouped across tools, each with every session it hit
  sessions.sh updates [--project P]             the next updates per project, each with its source session
  sessions.sh alerts                            task-failure rate, cost per session, quality — per project and per tool
  sessions.sh judge [--limit N]                 the judge pass on this machine's own profile (off when none)
  sessions.sh brief                             "what to update" lines for the morning brief
  sessions.sh summary --json                    this seat's summaries only (what another seat may fetch)
  sessions.sh export --otlp URL                 optional OTLP/HTTP export of the spans (off unless you name a URL)

THIS MACHINE IS COMPLETE ALONE (the Allfather, 2026-11-24: "not all have a heart"). Scan, index, redaction, project join,
the judge pass, alerts and every face run on the one machine; no heart, ssh ring or second machine is needed. `--fleet`
only ADDS: this machine fetches other seats' summaries itself and names the seat of every row. The heart may compute,
never speaks for the user's machine.

What is stored: spans in the OpenTelemetry GenAI shape (convention version pinned: SEMCONV) plus ymir.* attributes
(project, seat, tool, branch). Tokens and counts, a redacted one-line error and a redacted last prompt. Never the raw
transcript — that stays where the tool wrote it. Tail retention: every error span and every session's counters are kept.

Privacy (RULES/04, RULES/15): the house secret patterns, bearer tokens, emails and the vault mount are masked BEFORE
anything is written. A session whose cwd is inside the vault is indexed by COUNT ONLY (no cwd, title, prompt, project,
spans). `--public-view` drops sessions whose project is not marked public.

Env: YMIR_HOME · YMIR_STATE_DIR · YMIR_SEAT · YMIR_VAULT_MNT · YMIR_JUDGE_BASE_URL / YMIR_JUDGE_MODEL / YMIR_JUDGE_KEY_ENV
(or `judge:` in <home>/config/sessions.yaml) · YMIR_OTLP_ENDPOINT · SESSIONS_SSH · SESSIONS_SSH_CMD
Exit: 0 ok · 2 usage.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

VERSION = "1.0.0"
SEMCONV = "1.37.0"          # OpenTelemetry GenAI semantic conventions — still Development; pinned on purpose
HERE = Path(__file__).resolve().parent
TOOLS = ("claude", "pi", "codex", "hermes", "opencode")


def _ps():
    spec = importlib.util.spec_from_file_location("projects_status", HERE / "projects_status.py")
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


PS = _ps()
home, this_seat = PS.home, PS.this_seat


def state_dir() -> Path:
    s = os.environ.get("YMIR_STATE_DIR")
    return (Path(s) if s else home() / "state") / "sessions"


def roots() -> dict[str, Path]:
    h = Path.home()
    return {"claude": h / ".claude/projects", "pi": h / ".pi/agent/sessions", "codex": h / ".codex/sessions",
            "hermes": h / ".hermes/state.db", "opencode": h / ".local/share/opencode/opencode.db"}


# ── redaction ────────────────────────────────────────────────────────────────────────────────────────────────────
# The house patterns are secret-guard's (bin/gates/guards/secret-guard.sh) plus the shapes a transcript adds.
SECRETS = re.compile(
    r"(AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?(?:-----END [A-Z ]*PRIVATE KEY-----|$)|(?:ghp|gho|ghs|ghr)_[A-Za-z0-9]{36}"
    r"|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]+|AIza[0-9A-Za-z_-]{35}"
    r"|(?i:bearer)\s+[A-Za-z0-9._~+/=-]{16,}"
    r"|(?i:(?:api[_-]?key|secret|token|passwd|password|[A-Z_]*_(?:KEY|TOKEN|SECRET)))[\"']?\s*[:=]\s*[\"']?[A-Za-z0-9_./+=-]{12,})")
EMAIL = re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+")


def vault_mnt() -> str:
    return os.path.realpath(os.environ.get("YMIR_VAULT_MNT") or str(Path.home() / "Vault"))


def redact(text: str, n: int = 300) -> str:
    t = str(text or "")[: n * 4]
    v = vault_mnt()
    if v and v in t:
        t = t.replace(v, "[vault]")
    t = SECRETS.sub("[secret]", t)
    t = EMAIL.sub("[email]", t)
    return re.sub(r"\s+", " ", t).strip()[:n]


def in_vault(path: str) -> bool:
    if not path:
        return False
    p, v = os.path.realpath(path), vault_mnt()
    return p == v or p.startswith(v + os.sep)


def signature(err: str) -> str:
    """One stable line for 'the same failure': numbers, hex, uuids and paths folded away."""
    s = redact(err, 400).lower() if err else ""
    s = re.sub(r"[0-9a-f]{8}-[0-9a-f-]{27,}", "<id>", s)
    s = re.sub(r"(?:/[\w.@+-]+){2,}", "<path>", s)
    s = re.sub(r"0x[0-9a-f]+|\b[0-9a-f]{12,}\b|\d+", "<n>", s)
    return re.sub(r"\s+", " ", s).strip()[:120]


# ── the index ────────────────────────────────────────────────────────────────────────────────────────────────────
SCHEMA = """
CREATE TABLE IF NOT EXISTS sources(key TEXT PRIMARY KEY, size INTEGER, off REAL, mtime REAL);
CREATE TABLE IF NOT EXISTS sessions(id TEXT PRIMARY KEY, tool TEXT, seat TEXT, sid TEXT, cwd TEXT, branch TEXT,
  project TEXT DEFAULT '', started REAL, last REAL, model TEXT, spans INTEGER DEFAULT 0, errors INTEGER DEFAULT 0,
  tokens_in INTEGER DEFAULT 0, tokens_out INTEGER DEFAULT 0, cost REAL DEFAULT 0, title TEXT DEFAULT '',
  last_prompt TEXT DEFAULT '', confidential INTEGER DEFAULT 0, judged INTEGER DEFAULT 0, outcome TEXT DEFAULT '',
  summary TEXT DEFAULT '', threads TEXT DEFAULT '[]');
CREATE TABLE IF NOT EXISTS spans(id INTEGER PRIMARY KEY, session TEXT, ts REAL, op TEXT, name TEXT, model TEXT,
  tin INTEGER, tout INTEGER, status TEXT, sig TEXT, err TEXT);
CREATE TABLE IF NOT EXISTS updates(id INTEGER PRIMARY KEY, project TEXT, session TEXT, action TEXT, text TEXT, source TEXT, ts REAL);
CREATE INDEX IF NOT EXISTS spans_session ON spans(session);
CREATE INDEX IF NOT EXISTS spans_sig ON spans(sig);
CREATE INDEX IF NOT EXISTS sessions_project ON sessions(project);
"""


def db(create: bool = True) -> sqlite3.Connection | None:
    p = state_dir() / "index.db"
    if not p.is_file() and not create:
        return None
    p.parent.mkdir(parents=True, exist_ok=True)
    c = sqlite3.connect(str(p))
    c.row_factory = sqlite3.Row
    c.executescript(SCHEMA)
    return c


class Sink:
    """Collects events for one scan and writes them; a confidential session keeps counters only."""

    def __init__(self, c: sqlite3.Connection, tool: str):
        self.c, self.tool, self.seat = c, tool, this_seat()
        self.cache: dict[str, sqlite3.Row | None] = {}

    def ev(self, sid: str, ts: float = 0, op: str = "", name: str = "", model: str = "", tin: int = 0, tout: int = 0,
           error: str | None = None, cwd: str = "", branch: str = "", title: str = "", prompt: str = "", cost: float = 0.0):
        key = f"{self.tool}:{sid}"
        row = self.c.execute("SELECT confidential FROM sessions WHERE id=?", (key,)).fetchone()
        conf = bool(row["confidential"]) if row else False
        if cwd and in_vault(cwd):
            conf = True
        if not row:
            self.c.execute("INSERT INTO sessions(id,tool,seat,sid,started,last,confidential) VALUES(?,?,?,?,?,?,?)",
                           (key, self.tool, self.seat, sid, ts or time.time(), ts or 0, int(conf)))
        status = "error" if error is not None else "ok"
        sets, args = [], []
        if conf:
            sets.append("confidential=1")
            sets += ["cwd=''", "branch=''", "title=''", "last_prompt=''", "project=''"]
        else:
            for col, val in (("cwd", cwd), ("branch", branch), ("title", redact(title, 120)), ("last_prompt", redact(prompt, 200))):
                if val:
                    sets.append(f"{col}=?"); args.append(val)
        if model:
            sets.append("model=?"); args.append(model)
        if ts:
            sets += ["last=MAX(COALESCE(last,0),?)", "started=MIN(COALESCE(NULLIF(started,0),?),?)"]; args += [ts, ts, ts]
        if op:
            sets += ["spans=spans+1", "errors=errors+?", "tokens_in=tokens_in+?", "tokens_out=tokens_out+?", "cost=cost+?"]
            args += [1 if status == "error" else 0, tin, tout, cost]
        if sets:
            self.c.execute(f"UPDATE sessions SET {','.join(sets)} WHERE id=?", (*args, key))
        if op and not conf:
            msg = redact(error or "", 300)
            self.c.execute("INSERT INTO spans(session,ts,op,name,model,tin,tout,status,sig,err) VALUES(?,?,?,?,?,?,?,?,?,?)",
                           (key, ts, op, name, model, tin, tout, status, signature(msg) if error is not None else "", msg))


def ts_of(v) -> float:
    if isinstance(v, (int, float)):
        return v / 1000 if v > 1e12 else float(v)
    try:
        from datetime import datetime
        return datetime.fromisoformat(str(v).replace("Z", "+00:00")).timestamp()
    except (ValueError, TypeError):
        return 0.0


def text_of(c) -> str:
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        return " ".join(x.get("text", "") if isinstance(x, dict) else str(x) for x in c)
    return ""


# ── adapters: JSONL tools, incremental by byte offset ────────────────────────────────────────────────────────────
def adapt_claude(o: dict, sid: str, sink: Sink, st: dict) -> None:
    ts, cwd, br = ts_of(o.get("timestamp")), o.get("cwd", ""), o.get("gitBranch", "")
    t = o.get("type")
    if t == "ai-title":
        sink.ev(sid, title=o.get("aiTitle", ""))
    elif t == "assistant":
        m = o.get("message") or {}
        u = m.get("usage") or {}
        sink.ev(sid, ts, "chat", model=m.get("model", ""), tin=u.get("input_tokens", 0), tout=u.get("output_tokens", 0), cwd=cwd, branch=br)
        for b in m.get("content") or []:
            if isinstance(b, dict) and b.get("type") == "tool_use":
                st.setdefault("pending", {})[b.get("id")] = b.get("name", "tool")
    elif t == "user":
        m = o.get("message") or {}
        c = m.get("content")
        if isinstance(c, list):
            for b in c:
                if isinstance(b, dict) and b.get("type") == "tool_result":
                    name = st.get("pending", {}).pop(b.get("tool_use_id"), "tool")
                    err = text_of(b.get("content")) if b.get("is_error") else None
                    sink.ev(sid, ts, "execute_tool", name, error=err if err is not None else None, cwd=cwd, branch=br)
        elif isinstance(c, str) and not o.get("isMeta") and not c.startswith("<"):
            sink.ev(sid, ts, prompt=c, cwd=cwd, branch=br)


def adapt_pi(o: dict, sid: str, sink: Sink, st: dict) -> None:
    t, ts = o.get("type"), ts_of(o.get("timestamp"))
    if t == "session":
        st["sid"] = o.get("id", sid); sink.ev(sid, ts, cwd=o.get("cwd", ""))
    elif t == "model_change":
        sink.ev(sid, ts, model=o.get("modelId", ""))
    elif t == "message":
        m = o.get("message") or {}
        r = m.get("role")
        if r == "assistant":
            u = m.get("usage") or {}
            err = m.get("errorMessage") or (m.get("stopReason") == "error" and "model call failed") or None
            sink.ev(sid, ts, "chat", model=m.get("model", ""), tin=u.get("input", 0), tout=u.get("output", 0),
                    error=str(err) if err else None, cost=float((u.get("cost") or {}).get("total", 0) or 0))
        elif r == "toolResult":
            sink.ev(sid, ts, "execute_tool", m.get("toolName", "tool"), error=text_of(m.get("content")) if m.get("isError") else None)
        elif r == "user":
            sink.ev(sid, ts, prompt=text_of(m.get("content")))


def adapt_codex(o: dict, sid: str, sink: Sink, st: dict) -> None:
    t, p, ts = o.get("type"), o.get("payload") or {}, ts_of(o.get("timestamp"))
    pt = p.get("type")
    if t == "session_meta":
        sink.ev(sid, ts, cwd=p.get("cwd", ""), model=p.get("model_provider", ""))
    elif t == "event_msg" and pt == "user_message":
        sink.ev(sid, ts, prompt=p.get("message", ""))
    elif t == "event_msg" and pt == "token_count":
        u = ((p.get("info") or {}).get("last_token_usage")) or {}
        if u:
            sink.ev(sid, ts, "chat", tin=u.get("input_tokens", 0), tout=u.get("output_tokens", 0))
    elif t == "response_item" and pt == "function_call":
        st.setdefault("pending", {})[p.get("call_id")] = p.get("name", "tool")
    elif t == "response_item" and pt == "function_call_output":
        name = st.get("pending", {}).pop(p.get("call_id"), "tool")
        out, err = p.get("output", ""), None
        try:
            j = json.loads(out) if isinstance(out, str) else out
            code = ((j or {}).get("metadata") or {}).get("exit_code")
            if isinstance(code, int) and code != 0:
                err = str((j or {}).get("output", ""))[:300] or f"exit code {code}"
        except (ValueError, AttributeError):
            m = re.search(r"exit code:?\s*(\d+)", str(out), re.I)
            if m and m.group(1) != "0":
                err = str(out)[:300]
        sink.ev(sid, ts, "execute_tool", name, error=err)


JSONL = {"claude": (adapt_claude, lambda f: f.stem), "pi": (adapt_pi, lambda f: f.stem.split("_")[-1]),
         "codex": (adapt_codex, lambda f: f.stem.split("rollout-")[-1][-36:])}


def scan_jsonl(c, tool: str, root: Path, since: float, stats: dict) -> None:
    adapt, sid_of = JSONL[tool]
    if not root.is_dir():
        return
    sink = Sink(c, tool)
    for f in root.rglob("*.jsonl"):
        try:
            stt = f.stat()
        except OSError:
            continue
        key = f"{tool}:{f}"
        row = c.execute("SELECT off FROM sources WHERE key=?", (key,)).fetchone()
        off = int(row["off"]) if row else 0
        if stt.st_size <= off or (not row and stt.st_mtime < since):
            continue
        with open(f, "rb") as fh:
            fh.seek(off)
            data = fh.read()
        end = data.rfind(b"\n") + 1            # complete lines only; a half-written tail waits for the next scan
        st: dict = {}
        sid = sid_of(f)
        for line in data[:end].splitlines():
            try:
                o = json.loads(line)
            except ValueError:
                continue
            if isinstance(o, dict):
                adapt(o, sid, sink, st)
        c.execute("INSERT OR REPLACE INTO sources VALUES(?,?,?,?)", (key, stt.st_size, off + end, stt.st_mtime))
        stats[tool] = stats.get(tool, 0) + 1
        c.commit()


# ── adapters: database tools, incremental by time/id ─────────────────────────────────────────────────────────────
def _ro(p: Path):
    c = sqlite3.connect(f"file:{p}?mode=ro", uri=True)
    c.row_factory = sqlite3.Row
    return c


def _clean(v) -> str:
    """The one human line of an error value: a dict's message, a JSON blob's error or last output line."""
    if isinstance(v, dict):
        return _clean(v.get("error") or (v.get("data") or {}).get("message") or v.get("message") or v.get("name") or json.dumps(v)[:200])
    s = str(v or "")
    if s[:1] in "{[":
        try:
            return _clean(json.loads(s))
        except ValueError:
            pass
    return s


def _failed(content: str) -> str | None:
    s = str(content or "")
    try:
        j = json.loads(s)
    except ValueError:
        j = None
    if isinstance(j, dict):
        code = j.get("exit_code")
        if j.get("error") or j.get("status") == "error" or (isinstance(code, int) and code != 0):
            out = [l for l in str(j.get("output") or "").splitlines() if l.strip()]
            return _clean(j.get("error")) if j.get("error") else (out[-1] if out else f"exit code {code}")
        return None
    m = re.search(r"exit[_ ]code\W+(-?\d+)", s[:600], re.I)
    return s[:300] if m and m.group(1) != "0" else None


def scan_hermes(c, p: Path, stats: dict) -> None:
    if not p.is_file():
        return
    key = f"hermes:{p}"
    row = c.execute("SELECT off FROM sources WHERE key=?", (key,)).fetchone()
    cut = float(row["off"]) if row else 0.0
    mx = c.execute("SELECT off FROM sources WHERE key=?", (key + "#msg",)).fetchone()
    last_msg = int(mx["off"]) if mx else 0
    sink, h = Sink(c, "hermes"), _ro(p)
    new_cut, new_msg = cut, last_msg
    for s in h.execute("SELECT * FROM sessions WHERE COALESCE(last_activity_at, started_at) > ? ORDER BY started_at", (cut,)):
        sid = s["id"]
        sink.ev(sid, s["started_at"], model=s["model"] or "", cwd=s["cwd"] or "", branch=s["git_branch"] or "", title=s["title"] or "")
        c.execute("UPDATE sessions SET last=?, cost=?, tokens_in=?, tokens_out=? WHERE id=?",
                  (s["last_activity_at"] or s["started_at"], s["estimated_cost_usd"] or 0, (s["input_tokens"] or 0) + (s["cache_read_tokens"] or 0),
                   s["output_tokens"] or 0, f"hermes:{sid}"))
        new_cut = max(new_cut, s["last_activity_at"] or s["started_at"])
        for m in h.execute("SELECT id,role,content,tool_name,timestamp FROM messages WHERE session_id=? AND id>? ORDER BY id", (sid, last_msg)):
            if m["role"] == "tool":
                sink.ev(sid, m["timestamp"], "execute_tool", m["tool_name"] or "tool", error=_failed(m["content"]))
            elif m["role"] == "user":
                sink.ev(sid, m["timestamp"], prompt=m["content"] or "")
            new_msg = max(new_msg, m["id"])
        stats["hermes"] = stats.get("hermes", 0) + 1
    h.close()
    c.execute("INSERT OR REPLACE INTO sources VALUES(?,?,?,?)", (key, 0, new_cut, 0))
    c.execute("INSERT OR REPLACE INTO sources VALUES(?,?,?,?)", (key + "#msg", 0, new_msg, 0))
    c.commit()


def scan_opencode(c, p: Path, stats: dict) -> None:
    if not p.is_file():
        return
    key = f"opencode:{p}"
    row = c.execute("SELECT off FROM sources WHERE key=?", (key,)).fetchone()
    cut = int(row["off"]) if row else 0
    sink, o = Sink(c, "opencode"), _ro(p)
    new = cut
    sess = {r["id"]: r for r in o.execute("SELECT id,directory,title FROM session")}
    for m in o.execute("SELECT id,session_id,time_created,data FROM message WHERE time_created>? ORDER BY time_created", (cut,)):
        d = json.loads(m["data"])
        s = sess.get(m["session_id"])
        sid, ts = m["session_id"], m["time_created"] / 1000
        base = {"cwd": (s["directory"] if s else ""), "title": (s["title"] if s else "")}
        if d.get("role") == "assistant":
            t = d.get("tokens") or {}
            sink.ev(sid, ts, "chat", model=d.get("modelID", ""), tin=t.get("input", 0), tout=t.get("output", 0),
                    error=_clean(d.get("error")) if d.get("error") else None,
                    cost=float(d.get("cost") or 0), **base)
        new = max(new, m["time_created"])
    for pt in o.execute("SELECT session_id,time_created,data FROM part WHERE time_created>? ORDER BY time_created", (cut,)):
        d = json.loads(pt["data"])
        if d.get("type") == "tool":
            stt = d.get("state") or {}
            sink.ev(pt["session_id"], pt["time_created"] / 1000, "execute_tool", d.get("tool", "tool"),
                    error=_clean(stt.get("error") or stt.get("output") or "tool error") if stt.get("status") == "error" else None)
        new = max(new, pt["time_created"])
    o.close()
    if new > cut:
        stats["opencode"] = stats.get("opencode", 0) + 1
    c.execute("INSERT OR REPLACE INTO sources VALUES(?,?,?,?)", (key, 0, new, 0))
    c.commit()


# ── the project join (plan 367's resolver: projects cloned on this machine) ──────────────────────────────────────
def project_map() -> tuple[list[tuple[str, str]], dict]:
    prefixes, remotes = [], {}
    for p in PS.registry():
        pid = str(p.get("id", ""))
        clone = PS.clone_here(p, this_seat())
        if clone:
            prefixes.append((clone, pid))
            rc, out = PS.run(["git", "worktree", "list", "--porcelain"], clone)
            for ln in out.splitlines():
                if ln.startswith("worktree "):
                    prefixes.append((os.path.realpath(ln[9:].strip()), pid))
        g = p.get("git") or {}
        if g.get("owner") and g.get("repo"):
            remotes[f"{g['owner']}/{g['repo']}".lower()] = pid
    prefixes.sort(key=lambda x: -len(x[0]))
    return prefixes, remotes


def join_projects(c) -> None:
    prefixes, remotes = project_map()
    cache: dict[str, str] = {}
    for r in c.execute("SELECT DISTINCT cwd FROM sessions WHERE cwd!='' AND confidential=0").fetchall():
        cwd = r["cwd"]
        real = os.path.realpath(cwd) if os.path.exists(cwd) else cwd
        pid = next((i for pth, i in prefixes if real == pth or real.startswith(pth + os.sep)), "")
        if not pid and os.path.isdir(cwd):
            rc, url = PS.run(["git", "-C", cwd, "remote", "get-url", "origin"], timeout=5)
            m = re.search(r"[:/]([\w.-]+/[\w.-]+?)(?:\.git)?\s*$", url.strip()) if rc == 0 else None
            pid = remotes.get(m.group(1).lower(), "") if m else ""
        cache[cwd] = pid
    for cwd, pid in cache.items():
        c.execute("UPDATE sessions SET project=? WHERE cwd=? AND confidential=0", (pid, cwd))
    c.commit()


# ── heuristic next updates (no model) and the judge pass (the machine's own profile, or off) ─────────────────────
def refresh_updates(c) -> None:
    """Updates that need no model: a failure recurring across sessions, and a session that ended on an error."""
    c.execute("DELETE FROM updates WHERE source='index'")
    now = time.time()
    for r in c.execute("""SELECT s.sig, COUNT(DISTINCT s.session) n, MAX(s.session) sess, x.project FROM spans s
                          JOIN sessions x ON x.id=s.session WHERE s.status='error' AND s.sig!='' AND x.project!=''
                          GROUP BY s.sig, x.project HAVING n>=3 ORDER BY n DESC LIMIT 60"""):
        c.execute("INSERT INTO updates(project,session,action,text,source,ts) VALUES(?,?,?,?,?,?)",
                  (r["project"], r["sess"], "open an errand", f"the same failure hit {r['n']} sessions: {r['sig']}", "index", now))
    for r in c.execute("""SELECT id, project, title, last FROM sessions WHERE project!='' AND confidential=0 AND last>?
                          AND (SELECT status FROM spans WHERE session=sessions.id ORDER BY ts DESC, id DESC LIMIT 1)='error'
                          ORDER BY last DESC LIMIT 60""", (now - 7 * 86400,)):
        c.execute("INSERT INTO updates(project,session,action,text,source,ts) VALUES(?,?,?,?,?,?)",
                  (r["project"], r["id"], "answer", f"session ended on an error: {r['title'] or r['id']}", "index", now))
    c.commit()


def judge_profile() -> dict | None:
    e = os.environ
    prof = {"base_url": e.get("YMIR_JUDGE_BASE_URL", ""), "model": e.get("YMIR_JUDGE_MODEL", ""), "key_env": e.get("YMIR_JUDGE_KEY_ENV", "")}
    cfg = home() / "config" / "sessions.yaml"
    if not prof["base_url"] and cfg.is_file() and PS.yaml:
        prof.update(((PS.yaml.safe_load(cfg.read_text()) or {}).get("judge")) or {})
    return prof if prof.get("base_url") and prof.get("model") else None


def judge_pass(c, limit: int) -> dict:
    prof = judge_profile()
    if not prof:
        return {"judge": "off", "why": "no judge profile on this machine — the index, alerts and panels work without a model", "judged": 0}
    now = time.time()
    hi = c.execute("SELECT tokens_out+tokens_in t FROM sessions ORDER BY t DESC LIMIT 1 OFFSET (SELECT COUNT(*)/10 FROM sessions)").fetchone()
    cost_cut = hi["t"] if hi else 1 << 60
    rows = c.execute("""SELECT * FROM sessions WHERE judged=0 AND confidential=0 AND last<? AND spans>0 ORDER BY errors DESC, last DESC""",
                     (now - 1800,)).fetchall()
    pick = [r for r in rows if r["errors"] > 0 or (r["tokens_in"] + r["tokens_out"]) >= cost_cut
            or int(hashlib.md5(r["id"].encode()).hexdigest(), 16) % 10 == 0][:limit]
    key = os.environ.get(prof.get("key_env", ""), "")
    done = 0
    for r in pick:
        errs = c.execute("SELECT name,err FROM spans WHERE session=? AND status='error' ORDER BY ts DESC LIMIT 5", (r["id"],)).fetchall()
        digest = (f"tool {r['tool']} · project {r['project'] or 'unknown'} · {r['spans']} spans, {r['errors']} errors\n"
                  f"title: {r['title']}\nlast prompt: {r['last_prompt']}\n" + "\n".join(f"error in {e['name']}: {e['err']}" for e in errs))
        body = {"model": prof["model"], "messages": [
            {"role": "system", "content": "You judge one finished agent session from its digest. Reply with JSON only: "
             '{"outcome":"done|partial|failed|unknown","summary":"one line","open_threads":["..."],"next_updates":[{"action":"open an errand|reap|answer","text":"..."}]}'},
            {"role": "user", "content": digest}], "temperature": 0}
        req = urllib.request.Request(prof["base_url"].rstrip("/") + "/chat/completions", json.dumps(body).encode(),
                                     {"Content-Type": "application/json", **({"Authorization": f"Bearer {key}"} if key else {})})
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                msg = json.load(resp)["choices"][0]["message"]["content"]
            j = json.loads(re.search(r"\{[\s\S]*\}", msg).group(0))
        except Exception:
            continue          # a failed call leaves the session unjudged; it is tried again on the next pass
        c.execute("UPDATE sessions SET judged=1, outcome=?, summary=?, threads=? WHERE id=?",
                  (str(j.get("outcome", "unknown"))[:12], redact(j.get("summary", ""), 200), json.dumps([redact(t, 160) for t in j.get("open_threads", [])][:8]), r["id"]))
        for u in (j.get("next_updates") or [])[:4]:
            if r["project"]:
                c.execute("INSERT INTO updates(project,session,action,text,source,ts) VALUES(?,?,?,?,?,?)",
                          (r["project"], r["id"], redact(u.get("action", "answer"), 40), redact(u.get("text", ""), 200), "judge", now))
        done += 1
    c.commit()
    return {"judge": prof["model"], "judged": done, "candidates": len(pick)}


# ── faces ────────────────────────────────────────────────────────────────────────────────────────────────────────
def visibility() -> dict[str, str]:
    return {str(p.get("id")): (((p.get("handling") or {}).get("visibility") or {}).get("value") or "unknown") for p in PS.registry()}


def rows_sessions(c, project: str = "", tool: str = "", public: bool = False, limit: int = 300) -> list[dict]:
    q, a = "SELECT * FROM sessions WHERE 1=1", []
    if project:
        q += " AND project=?"; a.append(project)
    if tool:
        q += " AND tool=?"; a.append(tool)
    out, vis = [], visibility()
    for r in c.execute(q + " ORDER BY last DESC LIMIT ?", (*a, limit * 3)):
        if public and (r["confidential"] or vis.get(r["project"]) != "public"):
            continue
        out.append({k: r[k] for k in ("id", "tool", "seat", "project", "cwd", "branch", "started", "last", "model", "spans", "errors",
                                      "tokens_in", "tokens_out", "cost", "title", "last_prompt", "outcome", "summary", "confidential")})
        if len(out) >= limit:
            break
    return out


def decisions(c, public: bool = False) -> list[dict]:
    vis, groups = visibility(), {}
    for r in c.execute("""SELECT s.sig, s.name, s.err, s.session, x.tool, x.seat, x.project, x.title FROM spans s
                          JOIN sessions x ON x.id=s.session WHERE s.status='error' AND s.sig!=''"""):
        if public and vis.get(r["project"]) != "public":
            continue
        g = groups.setdefault(r["sig"], {"signature": r["sig"], "sample": r["err"], "count": 0, "sessions": {}, "tools": set(), "projects": set()})
        g["count"] += 1
        g["tools"].add(r["tool"]); g["projects"].add(r["project"] or "-")
        g["sessions"].setdefault(r["session"], {"id": r["session"], "tool": r["tool"], "seat": r["seat"], "project": r["project"], "title": r["title"]})
    out = [{**g, "sessions": list(g["sessions"].values()), "tools": sorted(g["tools"]), "projects": sorted(g["projects"])} for g in groups.values()]
    return sorted(out, key=lambda g: (-len(g["sessions"]), -g["count"]))[:100]


def updates(c, project: str = "") -> list[dict]:
    q = "SELECT u.project,u.session,u.action,u.text,u.source,x.tool,x.seat FROM updates u LEFT JOIN sessions x ON x.id=u.session"
    q += " WHERE u.project=?" if project else " WHERE 1=1"
    return [dict(r) for r in c.execute(q + " ORDER BY u.ts DESC, u.id DESC LIMIT 200", (project,) if project else ())]


def alerts(c) -> list[dict]:
    now, wk = time.time(), 7 * 86400
    out = []
    for dim in ("project", "tool"):
        for r in c.execute(f"SELECT {dim} k FROM sessions WHERE {dim}!='' GROUP BY {dim}"):
            k = r["k"]

            def win(a, b):
                return c.execute(f"""SELECT COUNT(*) n, COALESCE(SUM(spans),0) sp, COALESCE(SUM(errors),0) er,
                    COALESCE(SUM(tokens_in+tokens_out),0) tk, COALESCE(SUM(outcome='failed'),0) bad, COALESCE(SUM(judged),0) j
                    FROM sessions WHERE {dim}=? AND last>? AND last<=?""", (k, a, b)).fetchone()
            cur, prev = win(now - wk, now), win(now - 2 * wk, now - wk)
            if cur["sp"] >= 20 and prev["sp"] >= 20 and cur["er"] / cur["sp"] - prev["er"] / prev["sp"] > 0.10:
                out.append({"alert": "task-failure rate", dim: k, "now": round(cur["er"] / cur["sp"], 3), "before": round(prev["er"] / prev["sp"], 3)})
            if cur["n"] >= 3 and prev["n"] >= 3 and prev["tk"] and (cur["tk"] / cur["n"]) > 1.5 * (prev["tk"] / prev["n"]):
                out.append({"alert": "cost-per-task regression", dim: k, "now": round(cur["tk"] / cur["n"]), "before": round(prev["tk"] / prev["n"])})
            if cur["j"] >= 3 and prev["j"] >= 3 and (cur["bad"] or 0) / cur["j"] - (prev["bad"] or 0) / prev["j"] > 0.2:
                out.append({"alert": "quality drop", dim: k, "now": round((cur["bad"] or 0) / cur["j"], 2), "before": round((prev["bad"] or 0) / prev["j"], 2)})
    return out


def project_summary(pid: str) -> dict:
    """For the Projects panel: sessions per project by tool and seat, and the next updates. Never needs a heart."""
    c = db(create=False)
    if c is None:
        return {"sessions": 0, "by_tool": {}, "by_seat": {}, "updates": []}
    by_tool, by_seat = {}, {}
    for r in c.execute("SELECT tool, seat, COUNT(*) n FROM sessions WHERE project=? GROUP BY tool, seat", (pid,)):
        by_tool[r["tool"]] = by_tool.get(r["tool"], 0) + r["n"]
        by_seat[r["seat"]] = by_seat.get(r["seat"], 0) + r["n"]
    return {"sessions": sum(by_tool.values()), "by_tool": by_tool, "by_seat": by_seat, "updates": updates(c, pid)[:5]}


def ssh_seats() -> dict:
    try:
        return (json.loads((home() / "hodd" / "data" / "fleet.json").read_text()).get("hosts") or {})
    except (OSError, ValueError):
        return {}


def fleet_rows(kind: str) -> list[dict]:
    """Opt-in. THIS machine asks each other seat for its summaries and names the seat of every row it brings back."""
    out, here = [], this_seat()
    ssh = os.environ.get("SESSIONS_SSH", "ssh")
    cmd = os.environ.get("SESSIONS_SSH_CMD", "bash -lc 'for d in ~/ymir-runtime ~/ymir; do [ -x $d/bin/records/sessions.sh ] && exec $d/bin/records/sessions.sh summary --json; done; exit 127'")
    for seat, h in ssh_seats().items():
        if seat == here or h.get("state") == "dark":
            continue
        target = f"{h['user']}@{h['tailnet']}" if h.get("user") and h.get("tailnet") else seat
        rc, text = PS.run([ssh, "-o", "BatchMode=yes", "-o", "ConnectTimeout=6", target, cmd], timeout=40)
        try:
            doc = json.loads(text) if rc == 0 else {}
        except ValueError:
            doc = {}
        for r in doc.get(kind, []):
            out.append({**r, "seat": seat, "source_seat": seat})
    return out


def otlp(c, since: float, limit: int = 5000) -> dict:
    spans = []
    for r in c.execute("""SELECT s.*, x.tool, x.seat, x.project, x.branch, x.sid FROM spans s JOIN sessions x ON x.id=s.session
                          WHERE s.ts>? ORDER BY s.ts LIMIT ?""", (since, limit)):
        t = int(r["ts"] * 1e9)
        attrs = {"gen_ai.operation.name": r["op"], "gen_ai.agent.name": r["tool"], "gen_ai.conversation.id": r["sid"],
                 "gen_ai.request.model": r["model"], "gen_ai.usage.input_tokens": r["tin"], "gen_ai.usage.output_tokens": r["tout"],
                 "ymir.tool": r["tool"], "ymir.seat": r["seat"], "ymir.project": r["project"], "ymir.branch": r["branch"]}
        if r["op"] == "execute_tool":
            attrs["gen_ai.tool.name"] = r["name"]
        if r["status"] == "error":
            attrs["error.type"] = r["sig"]
        spans.append({"traceId": hashlib.md5(r["session"].encode()).hexdigest(), "spanId": f"{r['id']:016x}",
                      "name": f"{r['op']} {r['name'] or r['model']}".strip(), "kind": 1, "startTimeUnixNano": str(t), "endTimeUnixNano": str(t),
                      "status": {"code": 2 if r["status"] == "error" else 1},
                      "attributes": [{"key": k, "value": {"stringValue": str(v)}} for k, v in attrs.items() if v not in ("", None)]})
    return {"resourceSpans": [{"resource": {"attributes": [
        {"key": "service.name", "value": {"stringValue": "ymir-sessions"}},
        {"key": "ymir.semconv.pin", "value": {"stringValue": SEMCONV}}]},
        "scopeSpans": [{"scope": {"name": "ymir.sessions", "version": VERSION}, "spans": spans}]}]}


# ── commands ─────────────────────────────────────────────────────────────────────────────────────────────────────
def toon(name: str, rows: list[dict], cols: list[str]) -> str:
    q = lambda v: '"' + str(v if v is not None else "").replace('"', "'") + '"'
    return "\n".join([f"{name}[{len(rows)}]{{{','.join(cols)}}}:"] + ["  " + ",".join(q(r.get(k)) for k in cols) for r in rows])


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="sessions.sh", description=__doc__.split("\n")[0])
    ap.add_argument("cmd", choices=["scan", "list", "decisions", "updates", "alerts", "judge", "brief", "summary", "export"])
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--project", default="")
    ap.add_argument("--tool", default="")
    ap.add_argument("--since", type=float, default=30, help="scan: skip files untouched for this many days on a first read")
    ap.add_argument("--limit", type=int, default=20)
    ap.add_argument("--fleet", action="store_true", help="also fetch other seats' summaries (opt-in; this machine asks)")
    ap.add_argument("--public-view", action="store_true")
    ap.add_argument("--otlp", default=os.environ.get("YMIR_OTLP_ENDPOINT", ""))
    ap.add_argument("-v", "--version", action="version", version=VERSION)
    a = ap.parse_args(argv)
    emit = (lambda doc, text: print(json.dumps(doc) if a.json else text))
    c = db()

    if a.cmd == "scan":
        stats: dict = {}
        since = time.time() - a.since * 86400
        for t in TOOLS:
            if a.tool and a.tool != t:
                continue
            r = roots()[t]
            if t in JSONL:
                scan_jsonl(c, t, r, since, stats)
            elif t == "hermes":
                scan_hermes(c, r, stats)
            else:
                scan_opencode(c, r, stats)
        join_projects(c)
        refresh_updates(c)
        n = c.execute("SELECT COUNT(*) n FROM sessions").fetchone()["n"]
        emit({"read": stats, "sessions": n}, f"scan: read {sum(stats.values())} source(s) {stats or ''} · {n} sessions indexed")
    elif a.cmd == "list":
        rows = rows_sessions(c, a.project, a.tool, a.public_view)
        if a.fleet:
            rows += fleet_rows("sessions")
        emit({"seat": this_seat(), "count": len(rows), "sessions": rows},
             toon("sessions", rows, ["tool", "seat", "project", "last", "spans", "errors", "title"]))
    elif a.cmd == "decisions":
        g = decisions(c, a.public_view)
        emit({"seat": this_seat(), "decisions": g}, toon("decisions", [{**x, "n": len(x["sessions"]), "tools": ",".join(x["tools"])} for x in g],
                                                           ["signature", "count", "n", "tools"]))
    elif a.cmd == "updates":
        u = updates(c, a.project)
        emit({"updates": u}, toon("updates", u, ["project", "action", "text", "tool", "session"]))
    elif a.cmd == "alerts":
        al = alerts(c)
        emit({"alerts": al}, toon("alerts", al, ["alert", "project", "tool", "now", "before"]))
    elif a.cmd == "judge":
        r = judge_pass(c, a.limit)
        emit(r, "judge: " + ", ".join(f"{k}={v}" for k, v in r.items()))
    elif a.cmd == "brief":
        lines = [f"{u['project']}: {u['action']} — {u['text']} ({u['tool']} · {u['session']})" for u in updates(c)[:8]]
        lines += [f"alert: {x['alert']} on {x.get('project') or x.get('tool')}" for x in alerts(c)]
        emit({"seat": this_seat(), "lines": lines}, "\n".join(lines) or "nothing to update")
    elif a.cmd == "summary":
        emit({"seat": this_seat(), "sessions": rows_sessions(c, a.project, a.tool, a.public_view, 200), "decisions": decisions(c, a.public_view)}, "see --json")
    elif a.cmd == "export":
        if not a.otlp:
            print("export is off: name a collector with --otlp URL (or YMIR_OTLP_ENDPOINT)", file=sys.stderr)
            return 2
        body = json.dumps(otlp(c, 0)).encode()
        url = a.otlp if a.otlp.rstrip("/").endswith("/v1/traces") else a.otlp.rstrip("/") + "/v1/traces"
        with urllib.request.urlopen(urllib.request.Request(url, body, {"Content-Type": "application/json"}), timeout=30) as r:
            print(f"exported {len(json.loads(body)['resourceSpans'][0]['scopeSpans'][0]['spans'])} span(s) to {url}: HTTP {r.status}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

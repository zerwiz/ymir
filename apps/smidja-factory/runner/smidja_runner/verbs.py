"""Every verb the smithy's books teach, as one function each.

The `smidja` command, the Smíðja MCP and a remote `--on <host>` call all land
here, so a verb that exists in one door exists in all three. Each returns a plain
dict; the doors only format it. A refusal is a `Refusal` with the reason and the
way forward, never a traceback.

Only pi works inside the smithy (the Allfather, 2026-11-19). These verbs never
choose a harness for the run; any harness may call them.
"""

from __future__ import annotations

import json
import os
import re
import secrets
import shutil
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from . import paths, trace


class Refusal(Exception):
    """A verb that will not act, with why and what to do instead."""

    def __init__(self, reason: str, help: str = ""):
        super().__init__(reason)
        self.reason, self.help = reason, help


# ── small helpers ────────────────────────────────────────────────────────────

def _http(method: str, url: str, body: dict | None = None, timeout: float = 5.0):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"Content-Type": "application/json"} if data else {})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read().decode()
        return json.loads(raw) if raw.strip() else {}


def viewer_up(w: paths.Where) -> bool:
    try:
        _http("GET", w.viewer + "/api/health", timeout=2)
        return True
    except (urllib.error.URLError, OSError, ValueError):
        return False


def _need_engine(w: paths.Where) -> Path:
    if w.engine is None:
        raise Refusal(f"no smithy engine in {w.project} (looked in smidja/, apps/smidja/, and beside the factory)",
                      "stamp one with the factory's scripts/install.py, or pass --project-dir to a repo that has one")
    return w.engine


def _need_run(w: paths.Where, smidja_id: str) -> dict:
    if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", smidja_id or ""):
        raise Refusal(f"not a run id: {smidja_id!r}")
    s = trace.session(w.db, smidja_id)
    if not s:
        raise Refusal(f"no such run: {smidja_id}", "list runs with: smidja sessions")
    return s


def _uv() -> str:
    uv = shutil.which("uv")
    if not uv:
        raise Refusal("uv is not installed — the smithy's chains are uv scripts",
                      "install uv (https://docs.astral.sh/uv/) and run smidja doctor again")
    return uv


def _engine_script(w: paths.Where, name: str, *args: str, timeout: int = 120) -> subprocess.CompletedProcess:
    engine = _need_engine(w)
    script = engine / name
    if not script.is_file():
        raise Refusal(f"the engine has no {name}", f"engine: {engine}")
    cmd = [_uv(), "run", "--quiet", str(script)]
    if w.config:
        cmd += ["--config", str(w.config)]
    cmd += list(args)
    return subprocess.run(cmd, cwd=w.root or w.project, env=paths.run_env(w),
                          capture_output=True, text=True, timeout=timeout)


def _volundr_script(name: str, *args: str, timeout: int = 60) -> subprocess.CompletedProcess:
    script = paths.factory_dir() / "skills" / "volundr" / "scripts" / name
    if not script.is_file():
        raise Refusal(f"Völundr's {name} is missing from the factory", str(script))
    return subprocess.run([sys.executable, str(script), *args], capture_output=True,
                          text=True, timeout=timeout)


# ── the chains, modes, teams ────────────────────────────────────────────────

def chains(w: paths.Where) -> dict:
    engine = _need_engine(w)
    out = []
    for f in sorted(engine.glob("smidja_*.py")):
        text = f.read_text(errors="replace")[:4000]
        phases = re.search(r"^Phases:\s*(.+)$", text, re.M)
        name = f.stem.removeprefix("smidja_").replace("_", "-")
        if name in ("record", "resume", "decide", "trace"):
            continue      # doors over a run, not chains
        out.append({"chain": name, "script": f.name, "phases": phases.group(1).strip() if phases else ""})
    return {"engine": str(engine), "chains": out}


ALIASES = {"sdlc": "plan-build-test", "build-and-review": "build-review"}


def chain_script(w: paths.Where, chain: str) -> Path:
    engine = _need_engine(w)
    chain = ALIASES.get(chain, chain)
    candidate = engine / f"smidja_{chain.replace('-', '_')}.py"
    if chain.endswith(".py"):
        candidate = engine / chain
    if not candidate.is_file():
        known = ", ".join(c["chain"] for c in chains(w)["chains"])
        raise Refusal(f"no chain {chain!r}", f"chains here: {known}")
    return candidate


def _config_blocks(w: paths.Where) -> dict:
    """The config's own `stacks:` (teams), `modes:` and `services:` blocks.

    One config is the truth (smidja.md, 2026-11-06): the runner never keeps a
    second table of teams. YAML is read through uv's pyyaml so this package stays
    stdlib-only.
    """
    if not w.config or not w.config.is_file():
        return {}
    code = ("import json,sys,yaml;d=yaml.safe_load(open(sys.argv[1])) or {};"
            "print(json.dumps({k:d.get(k) for k in ('stacks','modes','services','tiers','agents','defaults')},default=str))")
    try:
        out = subprocess.run([_uv(), "run", "--quiet", "--with", "pyyaml", "python", "-c", code, str(w.config)],
                             capture_output=True, text=True, timeout=120)
    except Refusal:
        return {}
    if out.returncode != 0:
        return {"error": out.stderr.strip()[-400:]}
    return _expand(json.loads(out.stdout or "{}"))


_VAR = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(?::-((?:[^{}]|\$\{[^{}]*\})*))?\}")


def _expand(value):
    """`${VAR}` / `${VAR:-default}` filled from the environment, the way the engine's
    agents._expand_env reads the same file — so doctor shows what a run will get."""
    if isinstance(value, str):
        for _ in range(4):
            new = _VAR.sub(lambda m: os.environ.get(m.group(1)) or (m.group(2) or ""), value)
            if new == value:
                break
            value = new
        return value
    if isinstance(value, list):
        return [_expand(v) for v in value]
    if isinstance(value, dict):
        return {k: _expand(v) for k, v in value.items()}
    return value


def _block_list(w: paths.Where, key: str, book: str) -> dict:
    block = _config_blocks(w).get(key) or {}
    items = [{"name": k, **(v if isinstance(v, dict) else {"value": v})} for k, v in block.items()] \
        if isinstance(block, dict) else list(block)
    out: dict = {"config": str(w.config), key: items}
    if not items:
        out["cause"] = (f"the config has no `{key}:` block yet. A {key[:-1]} is made with the operator, "
                        f"never guessed: follow skills/{book}/SKILL.md")
    return out


def modes(w: paths.Where) -> dict:
    return _block_list(w, "modes", "create-new-teams")


def services(w: paths.Where) -> dict:
    return _block_list(w, "services", "create-new-teams")


def rosters(w: paths.Where) -> dict:
    """The teams (stacks) and every agent with the model it runs, validated."""
    blocks = _config_blocks(w)
    agents = [{"agent": a.get("name"), "model": a.get("model") or (blocks.get("defaults") or {}).get("model") or "",
               "coding_agent": a.get("coding_agent") or (blocks.get("defaults") or {}).get("coding_agent") or "pi"}
              for a in (blocks.get("agents") or []) if isinstance(a, dict)]
    teams = _block_list(w, "stacks", "create-new-teams")
    problems = [f"agent {a['agent']}: harness {a['coding_agent']!r} — only pi works inside the smithy"
                for a in agents if a["coding_agent"] != "pi"]
    return {"config": str(w.config), "agents": agents, "teams": teams["stacks"],
            "cause": teams.get("cause", ""), "problems": problems}


def team(w: paths.Where, action: str, name: str = "") -> dict:
    if action == "list":
        return {"teams": rosters(w)["teams"]}
    if action == "show":
        for t in rosters(w)["teams"]:
            if t.get("name") == name:
                return {"team": t}
        raise Refusal(f"no team {name!r}", "list them with: smidja team list")
    if action == "new":
        raise Refusal("a team is not generated — it is made by interviewing the operator",
                      "load skills/create-new-teams/SKILL.md and add a `stacks:` block to the config with them")
    if action == "smoke":
        return run(w, "scout", "List the top-level folders of this repository and say what each is for.\n"
                               "Done means: every top-level folder is named with one line each.",
                   stack=name or None)
    raise Refusal(f"unknown team action {action!r}", "list | show <name> | new | smoke [<name>]")


ROLE_NAME = re.compile(r"[a-z][a-z0-9_-]{1,30}")
PALETTE = ["#7fa7c9", "#b48ead", "#a3be8c", "#d08770", "#88c0d0", "#ebcb8b", "#bf616a", "#8fbcbb"]


def agent_new(w: paths.Where, name: str, base: str = "planner", thinking: str = "medium",
              tools: str = "", writes: str = "", purpose: str = "") -> dict:
    """Scaffold one new role (skills/create-new-agent): its prompt pair, copied from
    a base role, and its entry APPENDED to the config's `agents:` block. Nothing in
    the config is rewritten; a config whose last block is not `agents:` is refused
    with the entry printed to paste by hand."""
    if not ROLE_NAME.fullmatch(name or ""):
        raise Refusal(f"not a role name: {name!r}", "lowercase letters, digits, - or _, 2-31 long")
    if not purpose.strip():
        raise Refusal("a role needs --purpose: the one sentence from the interview (skills/create-new-agent)")
    engine = _need_engine(w)
    if not w.config or not w.config.is_file():
        raise Refusal("no config to add the role to", str(w.config))
    blocks = _config_blocks(w)
    if any(isinstance(a, dict) and a.get("name") == name for a in blocks.get("agents") or []):
        raise Refusal(f"role {name!r} already exists in the config")
    src = engine / "smidja_data" / "prompt_engineering" / base
    if not src.is_dir():
        stamp_runtime(w)
    if not src.is_dir():
        raise Refusal(f"no prompts for base role {base!r}", str(src))
    dest = engine / "smidja_data" / "prompt_engineering" / name
    dest.mkdir(parents=True, exist_ok=True)
    for part in ("system.md", "user.md"):
        if not (dest / part).exists() and (src / part).exists():
            (dest / part).write_text((src / part).read_text().replace(base, name))
    rel = os.path.relpath(dest, w.root or w.project)
    color = PALETTE[len(blocks.get("agents") or []) % len(PALETTE)]
    lines = [f"", f"  - name: {name}", f"    color: \"{color}\"", f"    thinking: {thinking}",
             f"    purpose: {purpose.strip()}", "    prompt_engineering:",
             f"      system: {rel}/system.md", f"      user: {rel}/user.md"]
    if tools:
        lines += ["    tools:"] + [f"      - {t.strip()}" for t in tools.split(",") if t.strip()]
    if writes:
        lines += ["    writes:"] + [f"      - {x.strip()}" for x in writes.split(",") if x.strip()]
    entry = "\n".join(lines) + "\n"
    top = [m.group(1) for m in re.finditer(r"^([a-z_]+):", w.config.read_text(), re.M)]
    if not top or top[-1] != "agents":
        return {"role": name, "prompts": str(dest), "appended": False,
                "paste_under_agents": entry, "why": "the config's last block is not `agents:`; nothing was rewritten"}
    with w.config.open("a") as fh:
        fh.write(entry)
    return {"role": name, "prompts": str(dest), "appended": True, "config": str(w.config),
            "next": "smidja doctor  # green = the role is known and its prompts are on disk"}


def model(w: paths.Where, action: str, role: str = "", value: str = "") -> dict:
    """Show or check the model a role runs. `set` and `pin` name the variable to
    export; the runner never rewrites the config behind the operator's back."""
    if action in ("show", ""):
        return {"agents": rosters(w)["agents"],
                "overrides": {k: v for k, v in os.environ.items() if re.fullmatch(r"SMIDJA_[A-Z_]*MODEL(_TIER)?", k)}}
    if action in ("set", "pin"):
        if not role or not value:
            raise Refusal("smidja model set <role|all> <provider/model>")
        listed = catalog_has(value)
        if listed is False:
            raise Refusal(f"{value} is not in this machine's model catalog", "list models with: bin/model/catalog.sh")
        var = "SMIDJA_LOCAL_MODEL" if role == "all" else f"SMIDJA_{role.upper()}_MODEL"
        return {"export": f"{var}={value}", "catalog": "listed" if listed else "not checked (no Ymir catalog here)",
                "note": "export it in the shell that runs smidja, or pass --model to one run"}
    raise Refusal(f"unknown model action {action!r}", "show | set <role|all> <model> | pin <role|all> <model>")


def catalog_has(model_id: str) -> bool | None:
    root = paths.ymir_root()
    cat = root / "bin" / "model" / "catalog.sh" if root else None
    if not cat or not cat.is_file():
        return None
    out = subprocess.run(["bash", str(cat), "--has", model_id], capture_output=True, text=True, timeout=60)
    return out.returncode == 0


# ── converge, run, watch ────────────────────────────────────────────────────

def up(w: paths.Where) -> dict:
    """Converge: clear the kill-switch, make sure the trace exists, raise the viewer."""
    did = []
    ks = paths.kill_switch()
    if ks.exists():
        ks.unlink()
        did.append("kill-switch cleared")
    w.data.mkdir(parents=True, exist_ok=True)
    stamped = stamp_runtime(w)
    if stamped:
        did.append(f"stamped {len(stamped)} missing prompt/harness files from the factory templates")
    if viewer_up(w):
        did.append("viewer up")
    else:
        unit = subprocess.run(["systemctl", "--user", "cat", "smidja.service"], capture_output=True, text=True)
        if unit.returncode == 0:
            subprocess.run(["systemctl", "--user", "start", "smidja.service"], capture_output=True, text=True)
            did.append("viewer raised (smidja.service)")
        else:
            viz = paths.factory_dir() / "apps" / "visualizer"
            bun = shutil.which("bun")
            if bun and (viz / "server" / "index.ts").is_file():
                env = os.environ.copy()
                env.update({"CMD_DB": str(w.db), "HOST": "127.0.0.1",
                            "PORT": os.environ.get("SMIDJA_VIZ_API_PORT", "8437")})
                log = (w.data / "viewer.log").open("a")
                subprocess.Popen([bun, "run", "server/index.ts"], cwd=viz, env=env, stdout=log,
                                 stderr=log, stdin=subprocess.DEVNULL, start_new_session=True)
                did.append("viewer raised (bun, detached)")
            else:
                did.append("viewer not raised: no smidja.service and no bun — runs still work, only the UI is absent")
        for _ in range(20):
            if viewer_up(w):
                break
            time.sleep(0.25)
    return {"did": did, "viewer": w.viewer, "viewer_up": viewer_up(w), "db": str(w.db)}


def stamp_runtime(w: paths.Where) -> list[str]:
    """The agents' prompts and harness extensions live in the engine's smidja_data/,
    which git does not track — so a fresh tree has none and no run can start. Copy
    every MISSING file from the factory's templates. An existing file is never
    overwritten: a prompt the operator tuned stays theirs."""
    if w.engine is None:
        return []
    templates = paths.factory_dir() / "templates"
    out = []
    for part in ("prompt_engineering", "harness_engineering"):
        src = templates / part
        if not src.is_dir():
            continue
        for f in src.rglob("*"):
            if f.is_file():
                dest = w.engine / "smidja_data" / part / f.relative_to(src)
                if not dest.exists():
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(f, dest)
                    out.append(str(dest))
    return out


DONE_MEANS = re.compile(r"\bdone means\b", re.I)


def run(w: paths.Where, chain: str, ask: str, *, model_id: str | None = None, tier: str | None = None,
        stack: str | None = None, mode: str | None = None, service: str | None = None,
        smidja_id: str | None = None, no_done_check: bool = False, dry_run: bool = False) -> dict:
    """Launch a chain DETACHED (its own session), so no tool-call timeout can kill it
    mid-generation (the sdlc-4027 lesson). Returns at once with the run id."""
    if paths.kill_switch().exists():
        raise Refusal("the emergency kill-switch is set — no run starts while it is",
                      "fix what ran away, then: smidja up (clears it)")
    for kind, name in (("modes", mode), ("services", service)):
        if name:
            preset = next((m for m in _block_list(w, kind, "create-new-teams")[kind] if m.get("name") == name), None)
            if not preset:
                raise Refusal(f"no {kind[:-1]} {name!r} in the config", f"list them with: smidja {kind}")
            chain = preset.get("chain") or chain
            stack = preset.get("stack") or preset.get("roster") or stack
            model_id = preset.get("model") or model_id
            tier = preset.get("tier") or tier
    if not chain:
        raise Refusal("which chain? smidja run <chain> \"<ask>\"", "list them with: smidja chains")
    request = ask
    if ask and Path(ask).is_file():
        request = Path(ask).read_text()
    if not request.strip():
        raise Refusal("the ask is empty")
    if not no_done_check and not DONE_MEANS.search(request):
        raise Refusal("the ask has no 'Done means:' line — the whole chain reads this prompt, and it must say "
                      "what finished looks like (cookbooks/how_to_prompt_for_the_eng.md)",
                      "add 'Done means: <the observable result>' or pass --no-done-check")
    if model_id and catalog_has(model_id) is False:
        raise Refusal(f"{model_id} is not in this machine's model catalog — a model the catalog does not list is a refusal")
    script = chain_script(w, chain)
    smidja_id = smidja_id or secrets.token_hex(4)
    env = paths.run_env(w)
    if model_id:
        env["SMIDJA_LOCAL_MODEL"] = model_id
    if tier:
        env["SMIDJA_MODEL_TIER"] = tier
    if stack:
        env["SMIDJA_ROSTER"] = stack
    session_dir = w.data / "sessions" / smidja_id
    cmd = [_uv(), "run", "--quiet", str(script), request, "--smidja-id", smidja_id]
    if w.config:
        cmd += ["--config", str(w.config)]
    out = {"smidja_id": smidja_id, "chain": script.stem, "project": str(w.project),
           "engine": str(w.engine), "log": str(session_dir / "launch.log"), "viewer": f"{w.viewer}/#/sessions/{smidja_id}",
           "model": model_id or env.get("SMIDJA_LOCAL_MODEL", "(from the config / the home)"),
           "team": stack or "(the config's default)"}
    if dry_run:
        out["would_run"] = cmd[:3] + [script.name, "<ask>", *cmd[5:]]
        return out
    session_dir.mkdir(parents=True, exist_ok=True)
    log = (session_dir / "launch.log").open("a")
    proc = subprocess.Popen(cmd, cwd=w.root or w.project, env=env, stdin=subprocess.DEVNULL,
                            stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    out["pid"] = proc.pid
    # Give it a moment to fail fast (a config refusal exits in under a second).
    for _ in range(12):
        time.sleep(0.25)
        if proc.poll() is not None:
            break
    if proc.poll() not in (None, 0):
        tail = (session_dir / "launch.log").read_text(errors="replace")[-1200:]
        raise Refusal(f"the chain exited {proc.returncode} before its first phase", tail.strip())
    out["state"] = "running" if proc.poll() is None else "finished"
    return out


def sessions(w: paths.Where, n: int = 10) -> dict:
    if not w.db.exists():
        return {"db": str(w.db), "sessions": [], "cause": "no run recorded on this machine yet"}
    return {"db": str(w.db), "sessions": trace.sessions(w.db, n)}


def phases(w: paths.Where, smidja_id: str) -> dict:
    s = _need_run(w, smidja_id)
    return {"smidja_id": smidja_id, "status": s["status"], "phases": trace.phases(w.db, smidja_id)}


def tail(w: paths.Where, smidja_id: str, n: int = 25, after: int = 0) -> dict:
    _need_run(w, smidja_id)
    ev = trace.events(w.db, smidja_id, after=after, limit=n)
    return {"smidja_id": smidja_id, "events": ev, "cursor": ev[-1]["rowid"] if ev else after}


def procs(w: paths.Where, smidja_id: str) -> dict:
    _need_run(w, smidja_id)
    return {"smidja_id": smidja_id, "processes": trace.processes(w.db, smidja_id)}


def gates(w: paths.Where, smidja_id: str) -> dict:
    _need_run(w, smidja_id)
    return {"smidja_id": smidja_id, "gates": trace.gates(w.db, smidja_id)}


def envelopes(w: paths.Where, smidja_id: str) -> dict:
    _need_run(w, smidja_id)
    return {"smidja_id": smidja_id, "envelopes": trace.envelopes(w.db, smidja_id)}


def record(w: paths.Where, smidja_id: str) -> dict:
    """The run as ONE record, from the engine's own reader (runrecord.py)."""
    _need_run(w, smidja_id)
    out = _engine_script(w, "smidja_record.py", smidja_id, "--json")
    if out.returncode != 0:
        raise Refusal(f"the record could not be read (exit {out.returncode})", out.stderr.strip()[-600:])
    try:
        return json.loads(out.stdout)
    except ValueError:
        return {"smidja_id": smidja_id, "record": out.stdout}


# ── control ─────────────────────────────────────────────────────────────────

def stop(w: paths.Where, smidja_id: str) -> dict:
    _need_run(w, smidja_id)
    return trace.stop(w.db, smidja_id)


def pause(w: paths.Where, smidja_id: str) -> dict:
    _need_run(w, smidja_id)
    pids = trace.signal_run(w.db, smidja_id, signal.SIGSTOP, agents_only=True)
    return {"smidja_id": smidja_id, "paused": len(pids), "pids": pids,
            "next": f"smidja steer {smidja_id} \"…\" then smidja continue {smidja_id}"}


def cont(w: paths.Where, smidja_id: str) -> dict:
    """Let a paused run go on (SIGCONT) — not `resume`, which restarts a dead run."""
    _need_run(w, smidja_id)
    pids = trace.signal_run(w.db, smidja_id, signal.SIGCONT, agents_only=True)
    return {"smidja_id": smidja_id, "continued": len(pids), "pids": pids}


def steer(w: paths.Where, smidja_id: str, message: str) -> dict:
    _need_run(w, smidja_id)
    if not message.strip():
        raise Refusal("steer needs a message")
    d = w.data / "sessions" / smidja_id
    d.mkdir(parents=True, exist_ok=True)
    f = d / "steer.md"
    head = "" if f.exists() else "# Engineer steering\n\n"
    with f.open("a") as fh:
        fh.write(f"{head}{trace.now_iso()}\n\n{message.strip()}\n\n")
    return {"smidja_id": smidja_id, "ok": True, "file": str(f),
            "note": "applies on the run's next agent call — pause first for it to land before the current turn"}


def resume(w: paths.Where, smidja_id: str, from_phase: str | None = None, dry_run: bool = False) -> dict:
    """Continue a dead run at its last green phase (smidja_resume.py), detached."""
    _need_run(w, smidja_id)
    if trace.processes(w.db, smidja_id):
        raise Refusal(f"run {smidja_id} is still alive", f"stop it first: smidja stop {smidja_id}")
    args = [smidja_id] + (["--from-phase", from_phase] if from_phase else [])
    if dry_run:
        out = _engine_script(w, "smidja_resume.py", *args, "--dry-run")
        return {"smidja_id": smidja_id, "exit": out.returncode, "plan": (out.stdout + out.stderr).strip()[-2000:]}
    engine = _need_engine(w)
    log = (w.data / "sessions" / smidja_id / "launch.log")
    log.parent.mkdir(parents=True, exist_ok=True)
    cmd = [_uv(), "run", "--quiet", str(engine / "smidja_resume.py")]
    if w.config:
        cmd += ["--config", str(w.config)]
    proc = subprocess.Popen(cmd + args, cwd=w.root or w.project, env=paths.run_env(w),
                            stdin=subprocess.DEVNULL, stdout=log.open("a"), stderr=subprocess.STDOUT,
                            start_new_session=True)
    time.sleep(2)
    if proc.poll() not in (None, 0):
        raise Refusal(f"resume refused (exit {proc.returncode})", log.read_text(errors="replace")[-1200:].strip())
    return {"smidja_id": smidja_id, "pid": proc.pid, "log": str(log)}


def decide(w: paths.Where, smidja_id: str, phase: str, verdict: str, note: str = "") -> dict:
    _need_run(w, smidja_id)
    if verdict not in ("approve", "decline", "cancel"):
        raise Refusal("decide takes approve | decline | cancel")
    args = [smidja_id, phase, verdict] + (["--note", note] if note else [])
    out = _engine_script(w, "smidja_decide.py", *args)
    if out.returncode != 0:
        raise Refusal(f"the decision was not recorded (exit {out.returncode})", (out.stderr or out.stdout).strip()[-600:])
    return {"smidja_id": smidja_id, "phase": phase, "decision": verdict, "out": out.stdout.strip()[-600:]}


def emergency_stop(w: paths.Where) -> dict:
    paths.kill_switch().parent.mkdir(parents=True, exist_ok=True)
    paths.kill_switch().write_text(f"set {trace.now_iso()} by smidja emergency-stop\n")
    out = trace.emergency(w.db)
    out["kill_switch"] = str(paths.kill_switch())
    out["next"] = "fix the cause, then: smidja up (clears the switch)"
    return out


def watch(w: paths.Where, interval: float = 10.0, once: bool = False) -> dict:
    """The watchdog: a run the trace calls `running` with no live process is
    interrupted, and is closed so no resume believes in dead work. While the
    kill-switch is set, any live smithy process is stopped."""
    closed: list[str] = []
    while True:
        if w.db.exists():
            if paths.kill_switch().exists():
                trace.emergency(w.db)
            with trace.connect(w.db) as c:
                running = [r["smidja_id"] for r in trace.rows(c, "select smidja_id from sessions where status='running'")]
            for sid in running:
                if not trace.processes(w.db, sid):
                    trace.finalize(w.db, sid, status="interrupted")
                    closed.append(sid)
        if once:
            return {"closed_as_interrupted": closed}
        time.sleep(interval)


# ── judgement and memory ────────────────────────────────────────────────────

def audit(w: paths.Where, smidja_id: str) -> dict:
    s = _need_run(w, smidja_id)
    calls = trace.tool_calls(w.db, smidja_id)
    ph = trace.phases(w.db, smidja_id)
    gs = trace.gates(w.db, smidja_id)
    flags = []
    for p in ph:
        if p["kind"] == "agent" and p["status"] == "success" and not calls.get(p["owner"]):
            flags.append(f"phase {p['name']}: {p['owner']} claims success with ZERO tool calls — a hallucinated completion")
    flags += [f"gate {g['gate']} failed in {g['phase']}: {g['violations']}" for g in gs if not g["passed"]]
    return {"smidja_id": smidja_id, "status": s["status"], "tool_calls": calls, "phases": ph,
            "gates": gs, "flags": flags, "tokens": s.get("total_tokens"), "cost": s.get("total_cost")}


def diagnose(w: paths.Where, smidja_id: str) -> dict:
    a = audit(w, smidja_id)
    failed = next((p for p in a["phases"] if p["status"] not in ("success", "running", "pending")), None)
    errors = [e for e in trace.events(w.db, smidja_id, limit=200)
              if e["type"] in ("error", "model_error", "model_fallback")]
    why, fix = "the run succeeded", ""
    if a["status"] == "running" and not trace.processes(w.db, smidja_id):
        why, fix = "the run is recorded as running but nothing is alive — it was killed", f"smidja resume {smidja_id}"
    elif any("ZERO tool calls" in f for f in a["flags"]):
        why, fix = "an agent claimed work it never did", "a stronger model for that role, or harden its prompt (smidja model set <role> …)"
    elif any(e["type"] == "model_error" for e in errors):
        why, fix = "the model failed to answer", "check the model is in the catalog and the rail is up (smidja doctor), then smidja resume"
    elif failed and any(not g["passed"] for g in a["gates"]):
        why, fix = f"phase {failed['name']} failed its gate", f"read smidja gates {smidja_id}; resume after the fix"
    elif failed:
        why, fix = f"phase {failed['name']} failed: {failed.get('error') or 'no error recorded'}", f"smidja resume {smidja_id}"
    elif a["status"] == "aborted":
        why, fix = "it was stopped by the emergency stop", "smidja up, then smidja resume"
    return {"smidja_id": smidja_id, "why": why, "fix": fix, "flags": a["flags"],
            "errors": [e["payload"] for e in errors][-5:]}


def learn(w: paths.Where, smidja_id: str) -> dict:
    d = diagnose(w, smidja_id)
    s = trace.session(w.db, smidja_id) or {}
    content = (f"smidja run {smidja_id} ({s.get('smidja_name')}) in {w.project.name}: status {s.get('status')}. "
               f"Why: {d['why']}. Fix: {d['fix'] or 'none'}. Request: {(s.get('request') or '')[:300]}")
    out = _volundr_script("volundr-observe.py", content, "--tags", f"smidja,{w.project.name},{s.get('status')}",
                          "--actors", "volundr")
    if out.returncode != 0:
        raise Refusal("Völundr's memory did not take the lesson", (out.stderr or out.stdout).strip()[-400:])
    return {"smidja_id": smidja_id, "learned": content, "episode": out.stdout.strip()}


def memory(w: paths.Where, project: str, k: int = 5) -> dict:
    out = _volundr_script("volundr-recall.py", project, str(k))
    return {"project": project, "recall": out.stdout.strip(), "exit": out.returncode}


def teach(w: paths.Where, project: str) -> dict:
    root = Path(project).expanduser() if Path(project).expanduser().is_dir() else w.project
    taught = []
    for name in ("AGENTS.md", "README.md", "CHANGELOG.md"):
        f = root / name
        if f.is_file():
            text = f.read_text(errors="replace")[:3000]
            out = _volundr_script("volundr-observe.py", f"{root.name}/{name}: {text}",
                                  "--tags", f"teach,{root.name}", "--actors", "volundr")
            taught.append({"file": name, "ok": out.returncode == 0})
    return {"project": root.name, "taught": taught}


def kaia(w: paths.Where, message: str, session: str = "smidja-cli") -> dict:
    """Talk to Völundr through the viewer's chat (traced, memory-backed)."""
    if not viewer_up(w):
        raise Refusal("Völundr speaks through the viewer, and it is not up", "smidja up")
    reply = _http("POST", w.viewer + "/api/chat/message",
                  {"sessionId": session, "content": message}, timeout=600)
    return {"session": session, "reply": reply}


def admit(w: paths.Where, smidja_id: str) -> dict:
    rec = phases(w, smidja_id)
    msg = (f"Admission notes for smithy run {smidja_id}. Its phases: "
           f"{json.dumps(rec['phases'])[:3000]}. Say what the next agent must know before it continues.")
    return kaia(w, msg, session=f"admit-{smidja_id}")


def recover(w: paths.Where, smidja_id: str) -> dict:
    d = diagnose(w, smidja_id)
    msg = (f"Recovery ticket for smithy run {smidja_id}: {d['why']}. Flags: {d['flags']}. "
           f"Errors: {d['errors']}. Give ONE recovery decision and the exact smidja command to apply it.")
    out = kaia(w, msg, session=f"recover-{smidja_id}")
    out["suggested"] = d["fix"]
    return out


MISSIONS = {
    "T1": ("scout", "Map this repository: name each top-level folder and what it holds, and the command that "
                    "runs its tests.\nDone means: every top-level folder has one line, and the test command is named."),
    "T2": ("plan", "Plan a /health endpoint for this repository's main server, with a test.\n"
                   "Done means: a plan file names the files to change, the route's response shape and the test."),
}


def mission(w: paths.Where, name: str, stack: str | None = None, model_id: str | None = None) -> dict:
    """Bench a team on a fixed task; read it later with audit and learn."""
    if name not in MISSIONS:
        raise Refusal(f"no mission {name!r}", "T1 (read-only recon) | T2 (plan)")
    chain, ask = MISSIONS[name]
    out = run(w, chain, ask, stack=stack, model_id=model_id)
    out["then"] = f"when it ends: smidja audit {out['smidja_id']} && smidja learn {out['smidja_id']}"
    return out


# ── the machine itself ──────────────────────────────────────────────────────

def doctor(w: paths.Where, stack: str | None = None) -> dict:
    """What this machine has, and which verbs it can serve. A missing piece is
    a named skip, never a silent failure."""
    checks = []

    def add(name: str, ok: bool | None, detail: str):
        checks.append({"check": name, "state": "ok" if ok else ("skip" if ok is None else "fail"), "detail": detail})

    add("python", sys.version_info >= (3, 10), sys.version.split()[0])
    add("uv", bool(shutil.which("uv")), shutil.which("uv") or "not on PATH — chains cannot run")
    add("pi (the smithy's only worker)", bool(shutil.which(os.environ.get("PI_PATH", "pi"))),
        shutil.which(os.environ.get("PI_PATH", "pi")) or "not on PATH — no agent can work")
    add("engine", w.engine is not None, f"{w.engine} ({w.engine_road})" if w.engine else f"none in {w.project}")
    add("config", bool(w.config and w.config.is_file()), str(w.config))
    blocks = _config_blocks(w) if w.config and w.config.is_file() else {}
    missing_prompts = []
    for a in blocks.get("agents") or []:
        for ref in ((a.get("prompt_engineering") or {}).values() if isinstance(a, dict) else []):
            if isinstance(ref, str) and w.root and not (w.root / ref).is_file() and not Path(ref).is_file():
                missing_prompts.append(ref)
    add("prompts", not missing_prompts if blocks else None,
        "all present" if not missing_prompts else f"{len(missing_prompts)} missing — `smidja up` stamps them from the factory templates")
    harness_off = [a.get("name") for a in blocks.get("agents") or []
                   if isinstance(a, dict) and (a.get("coding_agent") or (blocks.get("defaults") or {}).get("coding_agent") or "pi") != "pi"]
    add("only pi inside", not harness_off, "every agent runs on pi" if not harness_off else f"not pi: {harness_off}")
    model_set = os.environ.get("SMIDJA_LOCAL_MODEL") or (blocks.get("defaults") or {}).get("model")
    add("model", bool(model_set) or None, model_set or "none in env or config — resolved from the home's agents.yaml at run time")
    add("trace", w.db.exists() or None, f"{w.db} ({w.db_road})" + ("" if w.db.exists() else " — created by the first run"))
    add("viewer", viewer_up(w) or None, w.viewer + ("" if viewer_up(w) else " not up — `smidja up` raises it; runs work without it"))
    add("kill-switch", not paths.kill_switch().exists(), "clear" if not paths.kill_switch().exists() else "SET — `smidja up` clears it")
    root = paths.ymir_root()
    add("Ymir", root is not None or None, f"{root} — the model catalog and MCP seating are borrowed from it" if root
        else "absent — the smithy works alone; the catalog check is skipped")
    if stack:
        teams = [t.get("name") for t in rosters(w)["teams"]]
        add(f"team {stack}", stack in teams, "defined" if stack in teams else f"not in the config (teams: {teams})")
    hosts = ssh_hosts()
    add("remote (--on)", bool(shutil.which("ssh")) and (bool(hosts) or None),
        f"ssh hosts: {', '.join(hosts[:8])}" if hosts else "no hosts in ~/.ssh/config")
    ready = all(c["state"] != "fail" for c in checks)
    return {"ready": ready, "checks": checks, "project": str(w.project)}


def ssh_hosts() -> list[str]:
    cfg = Path.home() / ".ssh" / "config"
    if not cfg.is_file():
        return []
    out = []
    for line in cfg.read_text(errors="replace").splitlines():
        m = re.match(r"\s*Host\s+(.+)", line, re.I)
        if m:
            out += [h for h in m.group(1).split() if not any(ch in h for ch in "*?!")]
    return out

#!/usr/bin/env python3
"""team-run — run the smithy on a chosen machine, and follow the run.

The smithy is its own installed program (the `smidja` command, in the apps home of each machine).
This door runs it where the operator says, over ssh through that machine's own install, and
answers with one short record: run id, machine, runtime, state, link.

    team-run.sh run --task "<text>" [--on HOST|auto] [--team T] [--project P] [--runtime herdr|internal]
                    [--chain C] [--model M] [--phone|--json]
    team-run.sh status <id> [--on HOST] [--phone|--json]
    team-run.sh tail   <id> [--on HOST] [-n N] [--phone|--json]
    team-run.sh stop   <id> [--on HOST] [--phone|--json]
    team-run.sh where  [--json]        which machines can run it, their default runtime, their load

Everything about a machine is read from the operator's home, never written here:

    <home>/config/machines/<host>/smidja.yaml    runtime · ssh · link · project · chain · team · model
    <home>/hodd/data/fleet.json                  the fleet registry (roles, state)

`--on auto` picks, among this machine and every machine that has a smidja.yaml, the one with the
lowest load per core. `--runtime` overrides the machine's configured runtime for one run; the
default is `internal` when nothing says otherwise. The link is the machine's own `link` (the
address its smithy is published at) with the run's path added; with none configured the answer
says the link is local to that machine.

Exit: 0 ok · 1 refused (the reason is printed) · 2 usage.
"""
from __future__ import annotations

import argparse
import json
import os
import shlex
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path

RUNTIMES = ("herdr", "internal")
SSH_OPTS = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=8"]
RUNTIME_WORDS = {"herdr": "agents seated in visible herdr panes", "internal": "agents run headless in the engine"}


class Refusal(Exception):
    def __init__(self, reason: str, help: str = ""):
        super().__init__(reason)
        self.reason, self.help = reason, help


# ── the home and the registry ────────────────────────────────────────────────

def home() -> Path:
    env = os.environ.get("YMIR_HOME")
    if env and Path(env).is_dir():
        return Path(env)
    root = Path(__file__).resolve().parents[2]
    lib = root / "bin" / "vault" / "hoard-lib.sh"
    if lib.is_file():
        out = subprocess.run(["bash", "-c", f'. "{lib}" 2>/dev/null; ymir_home_root H 2>/dev/null; printf %s "$H"'],
                             capture_output=True, text=True, timeout=20)
        if out.stdout.strip() and Path(out.stdout.strip()).is_dir():
            return Path(out.stdout.strip())
    raise Refusal("the home is unresolved", "set YMIR_HOME, or run from a checkout whose bin/vault/hoard-lib.sh answers")


def _yaml(path: Path) -> dict:
    if not path.is_file():
        return {}
    text = path.read_text()
    try:
        import yaml  # type: ignore
        data = yaml.safe_load(text)
        return data if isinstance(data, dict) else {}
    except ImportError:
        out = {}
        for line in text.splitlines():
            line = line.split("#", 1)[0].rstrip()
            if ":" in line and not line.startswith((" ", "-")):
                k, v = line.split(":", 1)
                out[k.strip()] = v.strip().strip("\"'")
        return out


def this_host() -> str:
    return (os.environ.get("YMIR_HOSTNAME") or socket.gethostname()).split(".")[0]


def fleet(h: Path) -> dict:
    f = h / "hodd" / "data" / "fleet.json"
    try:
        return json.loads(f.read_text()).get("hosts", {})
    except (OSError, ValueError):
        return {}


def machine_cfg(h: Path, host: str) -> dict:
    return _yaml(h / "config" / "machines" / host / "smidja.yaml")


def candidates(h: Path) -> list[str]:
    """This machine, plus every machine that opted in with a smidja.yaml."""
    out = [this_host()]
    base = h / "config" / "machines"
    if base.is_dir():
        for d in sorted(base.iterdir()):
            if (d / "smidja.yaml").is_file() and d.name not in out:
                out.append(d.name)
    return out


def known(h: Path, host: str) -> bool:
    return host == this_host() or host in fleet(h) or (h / "config" / "machines" / host / "smidja.yaml").is_file()


# ── reaching a machine ───────────────────────────────────────────────────────

def smidja_bin() -> str:
    env = os.environ.get("SMIDJA_BIN")
    if env:
        return env
    found = shutil.which("smidja")
    if found:
        return found
    apps = Path(os.environ.get("YMIR_APPS_HOME") or Path.home() / ".local/share/ymir-apps") / "smidja/current/scripts/smidja"
    if apps.is_file():
        return str(apps)
    raise Refusal("the smithy is not installed on this machine (no `smidja` command)",
                  "install it: bin/apps/apps.sh install smidja")


def call(h: Path, host: str, argv: list[str], timeout: int = 180) -> tuple[int, object]:
    """Run `smidja <argv> --json` on the machine; return (exit, parsed answer)."""
    cfg = machine_cfg(h, host)
    if host == this_host():
        cmd = [smidja_bin(), *argv, "--json"]
    else:
        target = str(cfg.get("ssh") or host)
        inner = 'PATH="$HOME/.local/bin:$PATH" ' + shlex.join(
            ["smidja", *argv, "--json"])
        cmd = ["ssh", *SSH_OPTS, target, "bash -lc " + shlex.quote(inner)]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        raise Refusal(f"{host} did not answer within {timeout}s")
    if host != this_host() and out.returncode == 255:
        raise Refusal(f"ssh to {host} failed", out.stderr.strip()[-300:])
    if host != this_host() and (out.returncode == 127 or "command not found" in out.stderr):
        raise Refusal(f"the smithy is not installed on {host}", "bin/apps/apps.sh install smidja   (on that machine)")
    text = out.stdout.strip()
    try:
        data = json.loads(text) if text else {}
    except ValueError:
        data = {"output": text, "stderr": out.stderr.strip()[-300:]}
    return out.returncode, data


def load_of(h: Path, host: str) -> dict:
    """Load per core, and whether the smithy is there: probed, never assumed."""
    if host == this_host():
        la = os.getloadavg()[0]
        n = os.cpu_count() or 1
        try:
            smidja_bin()
            has = True
        except Refusal:
            has = False
        return {"host": host, "load": round(la / n, 2), "cores": n, "smithy": has, "up": True}
    target = str(machine_cfg(h, host).get("ssh") or host)
    probe = ("cat /proc/loadavg; nproc; "
             "if command -v smidja >/dev/null 2>&1 || [ -x \"$HOME/.local/bin/smidja\" ]; then echo smithy; else echo none; fi")
    try:
        out = subprocess.run(["ssh", *SSH_OPTS, target, probe], capture_output=True, text=True, timeout=15)
    except subprocess.TimeoutExpired:
        return {"host": host, "up": False, "why": "no answer in 15s"}
    if out.returncode != 0:
        return {"host": host, "up": False, "why": out.stderr.strip()[-120:] or f"exit {out.returncode}"}
    rows = out.stdout.split("\n")
    try:
        la = float(rows[0].split()[0])
        n = int(rows[1])
    except (IndexError, ValueError):
        return {"host": host, "up": False, "why": "unreadable load"}
    return {"host": host, "load": round(la / max(n, 1), 2), "cores": n, "smithy": "smithy" in rows[2:], "up": True}


def choose(h: Path, on: str) -> tuple[str, dict]:
    """The machine, and (for auto) the reason it won."""
    if on and on != "auto":
        if not known(h, on):
            raise Refusal(f"no machine named {on!r}", "machines: " + ", ".join(candidates(h)) + " (or add a smidja.yaml under config/machines/<host>/)")
        return on, {}
    reads = [load_of(h, c) for c in candidates(h)]
    ready = [r for r in reads if r.get("up") and r.get("smithy")]
    if not ready:
        raise Refusal("no machine can run the smithy right now", "; ".join(f"{r['host']}: {r.get('why') or 'smithy not installed'}" for r in reads))
    best = min(ready, key=lambda r: r["load"])
    return best["host"], {"picked_by": "lowest load per core", "load": best["load"], "others": [f"{r['host']}={r['load']}" for r in ready if r is not best]}


# ── the record of which run went where ──────────────────────────────────────

def _log(h: Path) -> Path:
    return h / "state" / "smidja-runs.jsonl"


def remember(h: Path, rid: str, host: str, runtime: str) -> None:
    f = _log(h)
    try:
        f.parent.mkdir(parents=True, exist_ok=True)
        with f.open("a") as fh:
            fh.write(json.dumps({"id": rid, "machine": host, "runtime": runtime,
                                 "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}) + "\n")
    except OSError:
        pass


def where_was(h: Path, rid: str) -> str:
    try:
        for line in reversed(_log(h).read_text().splitlines()):
            row = json.loads(line)
            if row.get("id") == rid:
                return row["machine"]
    except (OSError, ValueError, KeyError):
        pass
    return this_host()


# ── the verbs ────────────────────────────────────────────────────────────────

def link_for(cfg: dict, rid: str, viewer: str, host: str) -> tuple[str, str]:
    base = str(cfg.get("link") or "").strip().rstrip("/")
    if base:
        return f"{base}/#/sessions/{rid}", "published"
    return viewer or "", f"local to {host} (no published link is configured for it)"


def do_run(h: Path, a: argparse.Namespace) -> dict:
    text = (a.task or "").strip()
    if not text:
        raise Refusal("no task text", 'team-run.sh run --task "<what the smithy should do>"')
    host, why = choose(h, a.on or machine_default(h, "on") or "auto")
    cfg = machine_cfg(h, host)
    runtime = (a.runtime or str(cfg.get("runtime") or "") or "internal").lower()
    if runtime not in RUNTIMES:
        raise Refusal(f"unknown runtime {runtime!r}", "herdr (agents in visible panes) | internal (headless in the engine)")
    project = a.project or str(cfg.get("project") or "")
    if not project:
        raise Refusal(f"no project for {host}", f"pass --project <path on {host}>, or set `project:` in config/machines/{host}/smidja.yaml")
    chain = a.chain or str(cfg.get("chain") or "")
    argv = ["run", *([chain] if chain else []), "--task", text, "--project", project, "--runtime", runtime]
    team = a.team or str(cfg.get("team") or "")
    if team:
        argv += ["--team", team]
    if a.model or cfg.get("model"):
        argv += ["--model", a.model or str(cfg["model"])]
    code, out = call(h, host, argv)
    if not isinstance(out, dict):
        out = {"output": out}
    if out.get("refused") or code != 0 and not out.get("smidja_id"):
        raise Refusal(str(out.get("refused") or out.get("output") or f"the smithy on {host} exited {code}"), str(out.get("help") or ""))
    rid = out.get("smidja_id", "")
    remember(h, rid, host, runtime)
    link, kind = link_for(cfg, rid, str(out.get("viewer") or ""), host)
    return {"run_id": rid, "machine": host, "runtime": out.get("runtime", runtime), "state": out.get("state", "running"),
            "team": out.get("team") or team or "(default)", "chain": out.get("chain", ""), "link": link, "link_kind": kind,
            **({"chosen": why} if why else {})}


def machine_default(h: Path, key: str) -> str:
    return str(_yaml(h / "config" / "smidja.yaml").get(key) or "")


def do_status(h: Path, a: argparse.Namespace) -> dict:
    host = a.on or where_was(h, a.id)
    code, out = call(h, host, ["status", a.id])
    if not isinstance(out, dict) or out.get("refused"):
        raise Refusal(str((out or {}).get("refused") if isinstance(out, dict) else out), str((out or {}).get("help", "")) if isinstance(out, dict) else "")
    link, kind = link_for(machine_cfg(h, host), a.id, str(out.get("viewer") or ""), host)
    out.update({"run_id": a.id, "machine": host, "link": link, "link_kind": kind})
    return out


def do_tail(h: Path, a: argparse.Namespace) -> dict:
    host = a.on or where_was(h, a.id)
    code, out = call(h, host, ["tail", a.id, str(a.n)])
    if not isinstance(out, dict) or out.get("refused"):
        raise Refusal(str((out or {}).get("refused") if isinstance(out, dict) else out))
    out.update({"run_id": a.id, "machine": host})
    return out


def do_stop(h: Path, a: argparse.Namespace) -> dict:
    host = a.on or where_was(h, a.id)
    code, out = call(h, host, ["stop", a.id])
    if not isinstance(out, dict) or out.get("refused"):
        raise Refusal(str((out or {}).get("refused") if isinstance(out, dict) else out))
    out.update({"run_id": a.id, "machine": host})
    return out


def do_where(h: Path, a: argparse.Namespace) -> dict:
    rows = []
    for c in candidates(h):
        cfg = machine_cfg(h, c)
        r = load_of(h, c)
        r.update(runtime=str(cfg.get("runtime") or "internal"), link=str(cfg.get("link") or "-"), project=str(cfg.get("project") or "-"))
        rows.append(r)
    return {"this_machine": this_host(), "machines": rows}


# ── how an answer is spoken ──────────────────────────────────────────────────

def phone(verb: str, r: dict) -> str:
    """Six lines at most, plain words, the link last."""
    rid, host = r.get("run_id", ""), r.get("machine", "")
    rt = r.get("runtime", "")
    if verb == "run":
        lines = [f"Smithy run {rid} started on {host}.",
                 f"Runtime: {rt} ({RUNTIME_WORDS.get(rt, '')}).",
                 f"Team: {r.get('team')} · chain: {r.get('chain') or '-'}",
                 f"State: {r.get('state')}"]
        if r.get("chosen"):
            lines.append(f"Machine chosen by {r['chosen']['picked_by']} ({r['chosen']['load']}).")
        lines.append(f"Follow: {r.get('link') or 'no link'}" + ("" if r.get("link_kind") == "published" else f" [{r.get('link_kind')}]"))
        return "\n".join(lines[:6])
    if verb == "status":
        lines = [f"Run {rid} on {host}: {r.get('state')}" + (" (alive)" if r.get("alive") else ""),
                 f"Runtime: {rt} · team: {r.get('team')}",
                 f"Phase: {r.get('phase')} ({r.get('phases_done')}/{r.get('phases_total')} done)",
                 f"Last: {r.get('last') or '-'}",
                 f"Link: {r.get('link') or 'no link'}" + ("" if r.get("link_kind") == "published" else f" [{r.get('link_kind')}]")]
        return "\n".join(lines)
    if verb == "tail":
        ev = r.get("events") or []
        lines = [f"Run {rid} on {host}: last {min(len(ev), 5)} events"]
        for e in ev[-5:]:
            lines.append(f"{e.get('type', '')} {e.get('name', '')}".strip()[:110])
        return "\n".join(lines)
    if verb == "stop":
        return f"Run {rid} on {host}: stop sent. {json.dumps({k: v for k, v in r.items() if k in ('stopped', 'killed', 'pids')})}"
    return json.dumps(r)


def plain(r: dict) -> str:
    out = []
    for k, v in r.items():
        if isinstance(v, (dict, list)):
            v = json.dumps(v, default=str)
        out.append(f"{k}: {v if v not in (None, '') else '-'}")
    return "\n".join(out)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="team-run.sh", description=__doc__.split("\n\n")[0])
    p.add_argument("verb", choices=("run", "status", "tail", "stop", "where"))
    p.add_argument("id", nargs="?")
    p.add_argument("--task")
    p.add_argument("--on", help="a machine name, or auto")
    p.add_argument("--team")
    p.add_argument("--project")
    p.add_argument("--runtime", choices=RUNTIMES)
    p.add_argument("--chain")
    p.add_argument("--model")
    p.add_argument("-n", type=int, default=25)
    fmt = p.add_mutually_exclusive_group()
    fmt.add_argument("--phone", action="store_true", help="six plain lines and the link")
    fmt.add_argument("--json", action="store_true")
    a = p.parse_args(argv)
    try:
        if a.verb in ("status", "tail", "stop") and not a.id:
            raise Refusal(f"{a.verb} needs a run id", f"team-run.sh {a.verb} <id>")
        h = home()
        result = {"run": do_run, "status": do_status, "tail": do_tail, "stop": do_stop, "where": do_where}[a.verb](h, a)
        code = 0
    except Refusal as r:
        result, code = {"refused": r.reason, **({"help": r.help} if r.help else {})}, 1
    if a.json:
        print(json.dumps(result, indent=2, default=str))
    elif code:
        print(f"Refused: {result['refused']}" + (f"\n{result['help']}" if result.get("help") else ""))
    elif a.phone:
        print(phone(a.verb, result))
    else:
        print(plain(result))
    return code


if __name__ == "__main__":
    sys.exit(main())

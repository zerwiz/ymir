#!/usr/bin/env python3
"""stack — turn an app's development stack on and off; never touch what runs in production.

One manifest per machine, never in a repository: ~/.config/collab-kit/stacks.yaml (KIT_STACKS_FILE overrides).

  apps:
    shop:
      repos: [~/code/shop]                 # work start/stop find the app by its repository
      pieces:
        - {kind: unit, name: shop-dev.service, role: dev, health: "curl -fsS http://127.0.0.1:4000/health"}
        - {kind: container, name: shop-db, role: dev}          # podman container
        - {kind: pod, name: shop, role: prod}                  # podman pod
        - {kind: docker, name: shop-web, role: dev}            # docker container
        - {kind: compose, file: ~/code/shop/compose.yml, project: shop, service: web, role: dev}

  role: prod     never stopped by off — naming one is refused, loudly
  role: dev      stopped by off, started by on, health-checked after on
  role: unknown  never touched; listed for a person to decide (owner: says whose it is)

  status [app]          what runs, its role, memory, CPU and age
  on <app>|--all-dev    start the dev pieces, then check their health
  off <app>|--all-dev   stop the dev pieces; prod and unknown pieces are kept and named
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
from pathlib import Path

from . import miniyaml


def manifest_path() -> Path:
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return Path(os.environ.get("KIT_STACKS_FILE") or Path(base) / "collab-kit" / "stacks.yaml")


def load() -> dict:
    p = manifest_path()
    return (miniyaml.load(str(p)) or {}) if p.is_file() else {}


def apps() -> dict:
    return load().get("apps") or {}


def app_for_repo(repo) -> str | None:
    real = os.path.realpath(str(repo))
    for name, app in apps().items():
        for r in app.get("repos") or []:
            if os.path.realpath(os.path.expanduser(r)) == real:
                return name
    return None


def _run(cmd: list[str], timeout=30):
    try:
        return subprocess.run(cmd, text=True, capture_output=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as e:
        return subprocess.CompletedProcess(cmd, 1, "", str(e))


def _label(p: dict) -> str:
    if p.get("kind") == "compose":
        return f"compose:{p.get('project', '')}/{p.get('service', '*')}"
    return f"{p.get('kind')}:{p.get('name')}"


def piece_state(p: dict) -> dict:
    kind, name = p.get("kind"), p.get("name", "")
    st = {"piece": _label(p), "role": p.get("role", "unknown"), "running": False, "mem": "", "cpu": "", "since": ""}
    if kind == "unit":
        r = _run(["systemctl", "--user", "show", name, "-p", "ActiveState,MemoryCurrent,ActiveEnterTimestamp"])
        kv = dict(l.split("=", 1) for l in r.stdout.splitlines() if "=" in l)
        st["running"] = kv.get("ActiveState") == "active"
        mem = kv.get("MemoryCurrent", "")
        st["mem"] = f"{int(mem) // 2**20} MiB" if mem.isdigit() else ""
        st["since"] = kv.get("ActiveEnterTimestamp", "")
    elif kind in ("container", "pod", "docker"):
        eng = "docker" if kind == "docker" else "podman"
        if not shutil.which(eng):
            st["since"] = f"{eng} missing"
            return st
        if kind == "pod":
            r = _run([eng, "pod", "inspect", name, "--format", "{{.State}} {{.Created}}"])
            parts = r.stdout.split(" ", 1)
            st["running"] = r.returncode == 0 and parts[0].strip().lower() == "running"
            st["since"] = parts[1].strip()[:19] if len(parts) > 1 else ""
        else:
            r = _run([eng, "inspect", name, "--format", "{{.State.Running}} {{.State.StartedAt}}"])
            parts = r.stdout.split(" ", 1)
            st["running"] = r.returncode == 0 and parts[0].strip() == "true"
            st["since"] = parts[1].strip()[:19] if len(parts) > 1 else ""
            if st["running"]:
                s = _run([eng, "stats", "--no-stream", "--format", "{{.MemUsage}}|{{.CPUPerc}}", name], timeout=15)
                if s.returncode == 0 and "|" in s.stdout:
                    st["mem"], st["cpu"] = (x.strip() for x in s.stdout.strip().split("|", 1))
    elif kind == "compose":
        f = os.path.expanduser(p.get("file", ""))
        r = _run(["docker", "compose", "-f", f, "-p", p.get("project", ""), "ps", "--format", "json",
                  *([p["service"]] if p.get("service") else [])])
        rows = []
        for line in r.stdout.splitlines():
            try:
                d = json.loads(line)
                rows += d if isinstance(d, list) else [d]
            except ValueError:
                pass
        st["running"] = bool(rows) and all((x.get("State") or "") == "running" for x in rows)
    return st


def _act(p: dict, verb: str) -> tuple[bool, str]:
    kind, name = p.get("kind"), p.get("name", "")
    if kind == "unit":
        r = _run(["systemctl", "--user", verb, name], timeout=90)
    elif kind in ("container", "docker"):
        r = _run(["docker" if kind == "docker" else "podman", verb, name], timeout=90)
    elif kind == "pod":
        r = _run(["podman", "pod", verb, name], timeout=120)
    elif kind == "compose":
        r = _run(["docker", "compose", "-f", os.path.expanduser(p.get("file", "")), "-p", p.get("project", ""), verb,
                  *([p["service"]] if p.get("service") else [])], timeout=180)
    else:
        return False, f"unknown kind {kind!r}"
    return r.returncode == 0, (r.stderr or r.stdout).strip()[:160]


def _healthy(p: dict, tries: int = 10) -> tuple[bool, str]:
    for i in range(tries):
        if p.get("health"):
            r = subprocess.run(p["health"], shell=True, text=True, capture_output=True)
            if r.returncode == 0:
                return True, "health check passed"
        elif piece_state(p)["running"]:
            return True, "running"
        time.sleep(float(os.environ.get("KIT_HEALTH_WAIT", "2")))
    return False, "not healthy after waiting"


def _select(app: str | None, all_dev: bool) -> list[tuple[str, dict]]:
    a = apps()
    if all_dev:
        return [(n, p) for n, x in a.items() for p in x.get("pieces") or []]
    if app not in a:
        raise SystemExit(f"no app {app!r} in {manifest_path()} (known: {', '.join(a) or 'none'})")
    return [(app, p) for p in a[app].get("pieces") or []]


def status(app: str | None) -> list[dict]:
    rows = []
    for name, p in _select(app, app is None):
        st = piece_state(p)
        st["app"] = name
        st["owner"] = p.get("owner", "")
        rows.append(st)
    return rows


def switch(verb: str, app: str | None, all_dev: bool, piece: str | None = None) -> tuple[int, list[str]]:
    out, rc = [], 0
    for name, p in _select(app, all_dev):
        if piece and piece not in (p.get("name"), _label(p)):
            continue
        role = p.get("role", "unknown")
        if role != "dev":
            if piece:
                out.append(f"REFUSED\t{name}\t{_label(p)}\trole {role}: {verb} never touches a {role} piece")
                rc = 1
            else:
                out.append(f"kept\t{name}\t{_label(p)}\trole {role}" + (f" (owner {p['owner']})" if p.get("owner") else ""))
            continue
        ok, msg = _act(p, "stop" if verb == "off" else "start")
        if verb == "on" and ok:
            ok, msg = _healthy(p)
        out.append(f"{'ok' if ok else 'FAILED'}\t{name}\t{_label(p)}\t{verb}: {msg}")
        rc = rc or (0 if ok else 1)
    return rc, out

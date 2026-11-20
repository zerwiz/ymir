#!/usr/bin/env python3
"""host — read-only reports about a machine: check-host, doctor (at session start), and the weekly summary.

check-host never changes anything. --strict exits 1 when any line is over its limit, so a timer or a
session start can stop before the disk fills rather than after.
"""
from __future__ import annotations

import json
import os
import time
from pathlib import Path

from . import config as C
from . import containers as ct
from . import leftovers as lo
from . import worktrees as wt


def _line(rows, area, subject, value, limit, over):
    rows.append({"area": area, "subject": subject, "value": value, "limit": limit, "status": "OVER" if over else "ok"})


def check_host(repos: list[str], sizes: bool) -> list[dict]:
    rows: list[dict] = []
    first = C.load(repos[0]) if repos else None
    d = C.disk(repos[0] if repos else os.path.expanduser("~"))
    floor = first["disk"] if first else C.DEFAULTS["disk"]
    _line(rows, "disk", "/", f"{d['free_gb']:g} GB free of {d['total_gb']:g} GB ({d['free_pct']:g} %)",
          f"{floor['min_free_pct']:g} % and {floor['min_free_gb']:g} GB",
          d["free_pct"] < float(floor["min_free_pct"]) or d["free_gb"] < float(floor["min_free_gb"]))
    busy = C.busy_paths()
    machine = C.machine()
    total_worktrees = 0
    for repo in repos:
        cfg = C.load(repo)
        root = C.main_tree(repo)
        trees = wt.inspect(cfg, root, busy=busy)
        for t in trees:
            wt.judge(cfg, t, set())
        live = [t for t in trees if t.exists]
        total_worktrees += len(live)
        merged = sum(1 for t in live if t.merged and not t.dirty)
        dirty = sum(1 for t in live if t.dirty)
        unpushed = sum(1 for t in live if t.unpushed)
        stale = sum(1 for t in live if t.idle_hours >= float(cfg["worktrees"]["stale_hours"]) and not t.busy_pid)
        leftover = sum(1 for t in trees if t.verdict in ("remove", "salvage"))
        name = cfg["project"]
        _line(rows, "worktrees", name, f"{len(live)} (merged {merged} · dirty {dirty} · unpushed {unpushed} · stale {stale})",
              f"max {cfg['worktrees']['max']}", len(live) > int(cfg["worktrees"]["max"]))
        _line(rows, "leftovers", name, f"{leftover} worktree(s) wait to be closed or salvaged",
              f"max {cfg['worktrees']['max_leftovers']}", leftover > int(cfg["worktrees"]["max_leftovers"]))
        if sizes:
            gb = round(sum(max(wt.size_mb(t.path), 0) for t in live) / 1024, 1)
            budget = float(machine.get("max_gb_per_repo") or cfg["budget"]["max_gb_per_repo"])
            _line(rows, "worktree-size", name, f"{gb:g} GB", f"{budget:g} GB", gb > budget)
    if machine.get("max_worktrees"):
        _line(rows, "worktrees", "this machine", str(total_worktrees), f"max {machine['max_worktrees']}",
              total_worktrees > int(machine["max_worktrees"]))
    cfg = first or C.load(os.getcwd())
    prod, why = C.is_product_host(cfg)
    _line(rows, "role", "this machine", "product host" if prod else "developer machine", why or "-", False)
    if not ct.engine(cfg):
        _line(rows, "containers", cfg["containers"]["engine"], "not installed", "-", False)
        return rows
    conts = ct.containers(cfg) or []
    by_project: dict[str, int] = {}
    for c in conts:
        if (c.get("State") or "").lower() == "running":
            p = (c.get("Labels") or {}).get("project") or "(unlabelled)"
            by_project[p] = by_project.get(p, 0) + 1
    for p, n in sorted(by_project.items()):
        purpose_product = any((c.get("Labels") or {}).get("purpose") == "product" and
                              (c.get("Labels") or {}).get("project") == p for c in conts)
        _line(rows, "running", p, f"{n} container(s)", "product only on a product host",
              (not prod) and purpose_product)
    imgs = ct.images(cfg) or []
    plan = ct.retention_plan(cfg, imgs)
    keep = int(cfg["containers"]["keep_tags"])
    untagged = [i for i in imgs if not ct._tags(i)]
    _line(rows, "images", "untagged", str(len(untagged)), "0", len(untagged) > 0)
    _line(rows, "images", "unlabelled", str(len(plan["unlabelled"])), "0 (labels: " + ",".join(cfg["containers"]["labels"]) + ")",
          len(plan["unlabelled"]) > 0)
    for repo, n in sorted(plan["repos"].items()):
        if n > keep:
            _line(rows, "images", repo, f"{n} tags", f"{keep} (current + previous)", True)
    stopped = ct.stopped_older(cfg, conts, 24)
    _line(rows, "stopped", "older than a day", str(len(stopped)), "0", len(stopped) > 0)
    return rows


def doctor(cfg: C.Config, root) -> tuple[int, list[str]]:
    """At session start: is it safe to begin new work here? Refuses (exit 1) over any budget."""
    out, bad = [], 0
    ok, msg = C.disk_gate(cfg, root)
    out.append(f"{'ok  ' if ok else 'STOP'} disk: {msg}")
    bad += not ok
    rows = lo.run(cfg, root, ["worktrees", "branches", "caches", "scratch"], apply=False, keep=set())
    leftover = [r for r in rows if r["verdict"] in ("remove", "salvage")]
    wts = [r for r in leftover if r["class"] == "worktrees"]
    limit = int(cfg["worktrees"]["max_leftovers"])
    over = len(wts) > limit
    out.append(f"{'STOP' if over else 'ok  '} leftovers: {len(leftover)} ({len(wts)} worktrees; budget {limit} worktrees)")
    bad += over
    live = [t for t in wt.listing(C.main_tree(str(root))) if os.path.isdir(t.path)]
    cap = len(live) >= int(cfg["worktrees"]["max"])
    out.append(f"{'STOP' if cap else 'ok  '} worktrees: {len(live)} of {cfg['worktrees']['max']}")
    bad += cap
    hp = C.git("config", "--get", "core.hooksPath", cwd=str(root)).stdout.strip()
    out.append(f"{'ok  ' if hp == '.githooks' else 'note'} hooks: core.hooksPath = {hp or '(unset)'}")
    out.append(f"ok   config: {cfg.path or 'no project.yaml — defaults'}")
    if bad:
        out.append("help: bash scripts/prune.sh   (see what goes and why), then bash scripts/prune.sh --apply")
    return (1 if bad else 0), out


def summary(root, days: int) -> list[str]:
    since = time.time() - days * 86400
    counts: dict[str, int] = {}
    p = C.ledger_path(root)
    if p.is_file():
        for line in p.read_text().splitlines():
            try:
                rec = json.loads(line)
                at = time.mktime(time.strptime(rec["at"], "%Y-%m-%dT%H:%M:%SZ")) - time.timezone
            except (ValueError, KeyError):
                continue
            if at >= since:
                key = rec["action"] + (f":{rec['cls']}" if rec.get("cls") else "")
                counts[key] = counts.get(key, 0) + 1
    cfg = C.load(root)
    open_now = [t for t in wt.listing(C.main_tree(str(root))) if os.path.isdir(t.path)]
    d = C.disk(root)
    lines = [f"the last {days} days in {cfg['project']}:"]
    lines += [f"  {k}: {v}" for k, v in sorted(counts.items())] or ["  no kit actions recorded"]
    lines.append(f"  open worktrees now: {len(open_now)} (cap {cfg['worktrees']['max']})")
    lines.append(f"  disk now: {d['free_gb']:g} GB free ({d['free_pct']:g} %)")
    return lines


def timer_units(root) -> dict[str, str]:
    root = str(C.main_tree(str(root)))
    name = "collab-kit-prune-" + Path(root).name.lower().replace(" ", "-")
    svc = (f"[Unit]\nDescription=Close finished worktrees and leftovers in {root}\n\n[Service]\nType=oneshot\n"
           f"WorkingDirectory={root}\nExecStart=/usr/bin/env bash scripts/work.sh sweep\n")
    tmr = (f"[Unit]\nDescription=Daily leftover prune for {root}\n\n[Timer]\nOnCalendar=daily\n"
           f"RandomizedDelaySec=1h\nPersistent=true\n\n[Install]\nWantedBy=timers.target\n")
    return {f"{name}.service": svc, f"{name}.timer": tmr}

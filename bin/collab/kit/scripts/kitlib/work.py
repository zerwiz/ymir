#!/usr/bin/env python3
"""work — start, stop and sweep: the three moments a task begins, ends, and is cleaned up after.

  start <id>   refuses over the leftover budget or under the disk floor (and prints what to clean); fetches with
               --prune; makes the worktree from origin/<default>; links dependencies; writes the record
  stop <id>    runs the checks, commits, pushes, opens or refreshes the pull request, stops what the worktree
               started (processes, ports, test databases in the record); merged → removed with its branch and
               caches; not merged → marked "waiting for merge" with a new expiry
  track <id>   adds a process, a port or a test database to the record, so stop can end it
  sweep        closes merged worktrees, salvages stale ones, prunes branches, refs, caches and scratch; reports
               the budget (the daily timer and the start of a session run it)
"""
from __future__ import annotations

import json
import os
import shlex
import subprocess
import time
from pathlib import Path

from . import host, leftovers, platform, stack, worktrees as wt
from .config import Config, busy_paths, disk_gate, git, ledger, main_tree


def _find(cfg, main, wid):
    for t in wt.inspect(cfg, main):
        if t.id == wid or os.path.basename(t.path) == wid:
            return t
    return None


def _write_record(path, rec: dict):
    gd = wt.gitdir_of(path)
    (gd / "kit.json").write_text(json.dumps(rec, indent=2) + "\n")


def start(cfg: Config, root, wid, base, owner, purpose, days) -> int:
    main = main_tree(str(root))
    ok, msg = disk_gate(cfg, main)
    if not ok:
        print(f"refused: the disk is below the floor — {msg}.")
        _print_cleanup(cfg, main)
        return 1
    if wt.has_remote(main):
        git("fetch", "-q", "--prune", "origin", cwd=str(main))
    rc = wt.new(cfg, main, wid, base, owner, purpose, days)
    if rc != 0:
        _print_cleanup(cfg, main)
        return rc
    path = main / cfg["names"]["worktrees"] / wid
    rec = wt.read_record(path)
    rec.update({"started": rec.get("created"), "state": "working", "processes": [], "ports": [], "databases": [],
                "session": session_id(), "agent": os.environ.get("KIT_AGENT") or owner})
    _write_record(path, rec)
    _stack(main, "on")
    print(f"next\tcd {path}   (when finished: bash scripts/work.sh stop {wid} -m \"what changed and why\")")
    return 0


def _stack(main, verb: str):
    """The app's dev stack follows its work: on at start; off when no worktree of the app is open."""
    app = stack.app_for_repo(main)
    if not app:
        return
    if verb == "off":
        open_trees = [t for t in wt.listing(main) if os.path.isdir(t.path)]
        if open_trees:
            print(f"stack\t{app}\tkept on: {len(open_trees)} worktree(s) still open")
            return
    _, lines = stack.switch(verb, app, False)
    for line in lines:
        print(f"stack\t{line}")


def session_id() -> str:
    """The harness session this work belongs to: KIT_SESSION, else the harness's own id when it exports one."""
    for k in ("KIT_SESSION", "CLAUDE_SESSION_ID", "HERMES_SESSION_ID", "OPENCODE_SESSION_ID"):
        if os.environ.get(k):
            return os.environ[k]
    return ""


def session_end(cfg: Config, root, session: str, agent: str, everything: bool, checks: bool = True) -> int:
    """Close every worktree a session (or an agent) opened: stop it, keep nothing that is safe elsewhere, and
    write one paragraph saying what was left and why."""
    main = main_tree(str(root))
    mine = []
    for t in wt.inspect(cfg, main):
        rec = t.record or {}
        if everything or (session and rec.get("session") == session) or (agent and rec.get("agent") == agent):
            mine.append(t)
    lines, left = [], []
    for t in mine:
        purpose = (t.record or {}).get("purpose") or t.id
        msg = f"Session end: {purpose} — saved for the next person"
        rc = stop(cfg, main, t.id, msg if t.dirty else None, no_checks=not checks, quiet_stack=True)
        if rc != 0:  # the checks or a hook refused: save it as found rather than lose it
            t2 = _find(cfg, main, t.id)
            if t2 and (t2.dirty or t2.unpushed):
                ok, note = wt.salvage(main, t2)
                lines.append(f"{t.id}: the checks refused; {note}")
                if not ok:
                    left.append(f"{t.id} ({t2.path}): could not be saved to the remote — {note}")
                    continue
        t3 = _find(cfg, main, t.id)
        if t3 and t3.exists and not t3.dirty and not t3.unpushed and not t3.busy_pid:
            rec = t3.record or {}
            note = wt.remove(main, t3, wt.default_branch(main))
            lines.append(f"{t.id}: {note}; its branch and pull request ({rec.get('pr') or 'none'}) wait for review")
        elif t3 and t3.exists:
            left.append(f"{t.id} ({t3.path}): kept — {'a process works in it' if t3.busy_pid else 'work not on the remote'}")
        else:
            lines.append(f"{t.id}: closed")
    leftovers.run(cfg, main, ["scratch"], apply=True, keep=set())
    _stack(main, "off")
    when = time.strftime("%Y-%m-%d %H:%M %Z")
    para = (f"Session {session or agent or 'end'} ended {when} in {main.name}: {len(mine)} worktree(s) handled. "
            + " ".join(lines)
            + (" Left behind, and why: " + "; ".join(left) + "." if left else " Nothing was left behind."))
    d = wt.common_dir(main) / "kit-handoffs"
    d.mkdir(exist_ok=True)
    out = d / f"{time.strftime('%Y%m%d-%H%M%S')}-{(session or agent or 'session')[:24]}.md"
    out.write_text(f"# Session end — {main.name}\n\n{para}\n")
    ledger(main, "session-end", session=session, agent=agent, handled=len(mine), left=len(left))
    print(para)
    print(f"note\t{out}")
    return 1 if left else 0


def _print_cleanup(cfg, main):
    rows = leftovers.run(cfg, main, ["worktrees", "branches", "caches", "scratch"], apply=False, keep=set())
    go = [r for r in rows if r["verdict"] in ("remove", "salvage")]
    if go:
        print("what to clean (bash scripts/work.sh sweep does it):")
        for r in go[:15]:
            print(f"  {r['class']}\t{r['target']}\t{r['reason']}")


def track(cfg, root, wid, pid=None, port=None, db=None, what="") -> int:
    main = main_tree(str(root))
    t = _find(cfg, main, wid)
    if not t:
        print(f"no worktree named {wid}")
        return 1
    rec = t.record or {"id": wid}
    if pid:
        rec.setdefault("processes", []).append({"pid": int(pid), "what": what})
    if port:
        rec.setdefault("ports", []).append(int(port))
    if db:
        rec.setdefault("databases", []).append(db)
    _write_record(t.path, rec)
    print(f"tracked\t{wid}\t" + " ".join(x for x in (f"pid {pid}" if pid else "", f"port {port}" if port else "",
                                                       f"db {db}" if db else "") if x))
    return 0


def _pids_on_port(port: int) -> list[int]:
    r = subprocess.run(["ss", "-Htlnp", f"sport = :{port}"], text=True, capture_output=True)
    pids = []
    for part in r.stdout.split("pid=")[1:]:
        num = "".join(ch for ch in part if ch.isdigit())
        if num:
            pids.append(int(num))
    return pids


def _stop_started(cfg, t) -> list[str]:
    notes = []
    rec = t.record or {}
    pids = [p["pid"] for p in rec.get("processes", [])]
    for port in rec.get("ports", []):
        pids += _pids_on_port(port)
    for pid in sorted(set(pids)):
        notes.append(platform.stop_process(pid))
    drop = cfg["leftovers"]["test_databases"].get("drop")
    for db in rec.get("databases", []):
        if not drop:
            notes.append(f"database {db}: no leftovers.test_databases.drop command declared — left")
            continue
        r = subprocess.run(drop.replace("{name}", shlex.quote(db)), shell=True, text=True, capture_output=True,
                           cwd=t.path)
        notes.append(f"dropped database {db}" if r.returncode == 0 else f"database {db}: drop failed ({r.stderr.strip()[:80]})")
    return notes


def _pr(t, branch) -> tuple[str, str]:
    """(state, url) of the branch's pull request, opening one when there is none. state: OPEN|MERGED|CLOSED|NONE|NO-GH."""
    if not shutil_which("gh"):
        return "NO-GH", ""
    r = subprocess.run(["gh", "pr", "view", branch, "--json", "state,url"], cwd=t.path, text=True, capture_output=True)
    if r.returncode == 0 and r.stdout.strip():
        d = json.loads(r.stdout)
        return d.get("state", "NONE"), d.get("url", "")
    r = subprocess.run(["gh", "pr", "create", "--fill", "--head", branch], cwd=t.path, text=True, capture_output=True)
    if r.returncode != 0:
        return "NONE", r.stderr.strip()[:160]
    return "OPEN", r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""


def shutil_which(name):
    import shutil
    return shutil.which(name)


def stop(cfg: Config, root, wid, message: str | None, no_checks: bool, quiet_stack: bool = False) -> int:
    main = main_tree(str(root))
    t = _find(cfg, main, wid)
    if not t:
        print(f"no worktree named {wid}")
        return 1
    if not no_checks and (Path(t.path) / "scripts" / "checks.sh").is_file():
        r = subprocess.run(["bash", "scripts/checks.sh", "test"], cwd=t.path)
        if r.returncode != 0:
            print("refused: the checks failed — fix them, then stop again (nothing was committed or removed)")
            return 1
    if t.dirty:
        if not message:
            print(f"refused: {t.dirty} uncommitted change(s) — say what changed and why: -m \"…\"")
            return 1
        git("add", "-A", ".", cwd=t.path)
        r = subprocess.run(["git", "commit", "-q", "-m", message], cwd=t.path, text=True, capture_output=True)
        if r.returncode != 0:
            print(f"refused: the commit was refused:\n{(r.stderr or r.stdout).strip()}")
            return 1
        print(f"committed\t{message.splitlines()[0]}")
    branch = t.branch
    if wt.has_remote(main) and branch:
        r = subprocess.run(["git", "push", "-q", "-u", "origin", branch], cwd=t.path, text=True, capture_output=True)
        if r.returncode != 0:
            print(f"refused: the push was refused:\n{r.stderr.strip()}")
            return 1
        print(f"pushed\t{branch}")
    state, url = _pr(t, branch) if branch else ("NONE", "")
    print(f"pull request\t{state}\t{url}")
    for note in _stop_started(cfg, t):
        print(f"stopped\t{note}")
    git("fetch", "-q", "--prune", "origin", cwd=str(main))
    t = _find(cfg, main, wid)
    if state == "MERGED" or (t and t.merged and not t.dirty and not t.unpushed and state != "OPEN"):
        print(f"closed\t{wid}\t{wt.remove(main, t, wt.default_branch(main))}")
        ledger(main, "close", id=wid, path=t.path, why="stopped after merge")
        if not quiet_stack:
            _stack(main, "off")
        return 0
    rec = t.record or {"id": wid}
    days = float(cfg["worktrees"]["expiry_days"])
    rec.update({"state": "waiting for merge", "pr": url, "stopped": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "expires_epoch": int(time.time() + days * 86400),
                "expires": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + days * 86400))})
    _write_record(t.path, rec)
    ledger(main, "stop", id=wid, state="waiting for merge", pr=url)
    if not quiet_stack:
        _stack(main, "off")
    print(f"waiting\t{wid}\twaiting for merge until {rec['expires']}; the merge door, post-merge or sweep closes it")
    return 0


def sweep(cfg: Config, root, dry_run: bool) -> int:
    main = main_tree(str(root))
    if wt.has_remote(main):
        git("fetch", "-q", "--prune", "origin", cwd=str(main))
    classes = ["worktrees", "branches", "remote_refs", "caches", "scratch"]
    rows = leftovers.run(cfg, main, classes, apply=not dry_run, keep=set())
    for r in rows:
        if r["verdict"] != "keep" or r["done"]:
            print("\t".join([r["class"], r["verdict"], r["target"], r["reason"], r["done"]]))
    if not dry_run:
        _stack(main, "off")
    rc, lines = host.doctor(cfg, main)
    print("\n".join(lines))
    ledger(main, "sweep", dry_run=dry_run, judged=len(rows))
    return rc

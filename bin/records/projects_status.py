#!/usr/bin/env python3
"""projects_status.py — every project the user works on, with its worktrees, PRs, CI and kit (plan 367).

One resolver behind three doors: the Projects panel (Hliðskjálf), `ymir projects`, and Eir's brief.

  projects-status.sh [--json] [--local] [--no-net] [--refresh] [--all]
                     [--realm R] [--seat S] [--has-prs] [--red] [--stale] [--public-view]

What it joins, and where each fact comes from (nothing is kept in this file):
  the registry    $YMIR_HOME/hodd/identity/projects.yaml (plan 345); absent = a solo user with no projects yet
  this seat       the project's clone here: clones[<seat>] first, then local_clone, then `repo` (plan 346)
  other seats     the ssh ring, one call per seat, `--local` there; an unreachable seat is a row, never an error
  worktrees       `git worktree list` in the clone; stale = branch merged into the default branch, or path gone
  claims          the home's state/claims shelf (plan 343.12) names the seat/errand that holds a branch
  PRs and CI      `gh pr list`, cached one minute per repo (PROJECTS_STATUS_TTL), never on --no-net
  the kit         <clone>/.collab-kit.json against bin/collab/standardise.py's VERSION. A repo reports its kit state
                  ONLY when the kit was seated with --report; a repo that did not says "seated, not reporting".

Defaults (the Allfather's word, 2026-11-24): only projects cloned on THIS machine are shown; other seats are asked only
with `--fleet` (an opt-in filter; `--all` lists registry rows with no clone at all); a repo reports back only when seated with --report; a collaborator's repo reports to the
one house that seated it. `--public-view` drops every project not marked public (RULES/04: a private project never
shows in a shared view).

Env: YMIR_HOME · YMIR_SEAT · PROJECTS_STATUS_TTL (60) · PROJECTS_STATUS_GH (gh) · PROJECTS_STATUS_SSH (ssh) ·
     PROJECTS_STATUS_SSH_CMD (the command run on a seat) · YMIR_HOUSE (the house a report must name)
Exit: 0 ok · 2 usage.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VERSION = "1.0.0"
DISK_FLOOR_GB = float(os.environ.get("PROJECTS_MIN_FREE_GB", "40"))

try:
    import yaml
except ImportError:  # pragma: no cover - the house ships pyyaml; a bare box says so
    yaml = None


def home() -> Path:
    h = os.environ.get("YMIR_HOME")
    return Path(h).expanduser() if h else Path.home() / "Documents" / "ymirhome"


def this_seat() -> str:
    return os.environ.get("YMIR_SEAT") or socket.gethostname().split(".")[0]


def registry() -> list[dict]:
    reg = home() / "hodd" / "identity" / "projects.yaml"
    if not reg.is_file() or yaml is None:
        return []
    try:
        return (yaml.safe_load(reg.read_text(encoding="utf-8")) or {}).get("projects") or []
    except yaml.YAMLError:
        return []


def run(args: list[str], cwd: str | None = None, timeout: int = 20) -> tuple[int, str]:
    try:
        r = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout
    except (OSError, subprocess.TimeoutExpired):
        return 127, ""


def clone_here(p: dict, seat: str) -> str:
    """This seat's clone of a project, or '' — a path that does not exist is not a clone."""
    cands: list[str] = []
    clones = p.get("clones") or {}
    for key in (seat, socket.gethostname(), "local"):
        if clones.get(key):
            cands.append(clones[key])
    for key in ("local_clone", "path"):
        if p.get(key):
            cands.append(p[key])
    repo = p.get("repo") or ""
    if repo == ".":
        # The code that RUNS (a pinned release) is not the checkout the work happens in: prefer the dev clone
        # that shares this tree's remote, so the count covers every worktree of it, not one release dir.
        want = run(["git", "config", "--get", "remote.origin.url"], str(ROOT))[1].strip()
        for d in (os.environ.get("YMIR_DEV_CLONE", ""), str(Path.home() / "ymir"), str(Path.home() / "Ymir")):
            if d and os.path.isdir(d) and want and run(["git", "config", "--get", "remote.origin.url"], d)[1].strip() == want:
                cands.append(d)
                break
        cands.append(str(ROOT))
    elif repo:
        cands.append(repo if os.path.isabs(repo) else str(home() / repo))
        cands.append(str(Path.home() / repo))
    for c in cands:
        c = os.path.expanduser(str(c))
        if os.path.isdir(os.path.join(c, ".git")) or (os.path.isdir(c) and run(["git", "rev-parse", "--git-dir"], c)[0] == 0):
            return os.path.realpath(c)
    return ""


def main_checkout(clone: str) -> str:
    """The primary checkout of a repository, even when `clone` is one of its worktrees."""
    rc, out = run(["git", "worktree", "list", "--porcelain"], clone)
    for line in out.splitlines():
        if line.startswith("worktree "):
            return line[9:].strip()
    return clone


def default_branch(p: dict, clone: str) -> str:
    b = (p.get("git") or {}).get("default_branch")
    if b:
        return b
    rc, out = run(["git", "symbolic-ref", "--short", "refs/remotes/origin/HEAD"], clone)
    if rc == 0 and out.strip():
        return out.strip().split("/", 1)[-1]
    return "main"


def claims() -> dict[str, dict]:
    """branch:<owner>/<repo>:<name> -> {seat, errand, state}; only live (not released) claims."""
    out: dict[str, dict] = {}
    shelf = home() / "state" / "claims"
    if not shelf.is_dir():
        return out
    for f in shelf.glob("*/*"):
        try:
            kv = dict(l.split("=", 1) for l in f.read_text().splitlines() if "=" in l)
        except OSError:
            continue
        if kv.get("state") == "released" or not kv.get("key", "").startswith("branch:"):
            continue
        out[kv["key"]] = {"seat": kv.get("seat", ""), "errand": kv.get("errand", "")}
    return out


def worktrees(p: dict, clone: str, base: str, claim_map: dict) -> list[dict]:
    rc, out = run(["git", "worktree", "list", "--porcelain"], clone)
    if rc != 0:
        return []
    ref = f"origin/{base}"
    if run(["git", "rev-parse", "--verify", "-q", ref], clone)[0] != 0:
        ref = base
    merged = set(run(["git", "for-each-ref", f"--merged={ref}", "--format=%(refname:short)", "refs/heads"], clone)[1].split())
    git = p.get("git") or {}
    slug = f"{git.get('owner', '')}/{git.get('repo', '')}"
    rows, cur = [], {}

    def push():
        if not cur.get("path"):
            return
        path = cur["path"]
        branch = cur.get("branch") or ("detached" if cur.get("detached") else "-")
        first = not rows
        wid = "(main)" if first else path.split("/.yggdrasil/", 1)[-1] if "/.yggdrasil/" in path else os.path.basename(path)
        claim = claim_map.get(f"branch:{slug}:{branch}")
        agent = (claim or {}).get("errand") or ((claim or {}).get("seat") or "") or ("-" if first else wid)
        reason = ""
        if not first:
            if not os.path.isdir(path):
                reason = "path gone"
            elif branch in merged and branch not in (base, "-", "detached"):
                reason = "branch merged"
        rows.append({"id": wid, "branch": branch, "path": path, "head": (cur.get("head") or "")[:8],
                     "agent": agent, "claimed": bool(claim), "stale": bool(reason), "reason": reason})

    for line in out.splitlines() + [""]:
        if line.startswith("worktree "):
            push(); cur = {"path": line[9:].strip()}
        elif line.startswith("HEAD "):
            cur["head"] = line[5:].strip()
        elif line.startswith("branch "):
            cur["branch"] = line[7:].strip().replace("refs/heads/", "")
        elif line.strip() == "detached":
            cur["detached"] = True
    push()
    return rows


def kit_current() -> str:
    try:
        m = re.search(r'^VERSION\s*=\s*"([^"]+)"', (ROOT / "bin" / "collab" / "standardise.py").read_text(), re.M)
        return m.group(1) if m else ""
    except OSError:
        return ""


def vtuple(v: str) -> tuple:
    return tuple(int(x) if x.isdigit() else 0 for x in re.split(r"[.\-]", v or "0"))


def kit_state(clone: str, pid: str) -> dict | None:
    f = Path(clone) / ".collab-kit.json"
    if not f.is_file():
        return None
    try:
        m = json.loads(f.read_text())
    except (OSError, ValueError):
        return {"seated": True, "reporting": False, "note": "manifest unreadable"}
    report = m.get("report") or {}
    house = os.environ.get("YMIR_HOUSE", "house")
    reporting = bool(report) and (not report.get("to") or house in report["to"])
    if not reporting:
        return {"seated": True, "reporting": False}   # nothing else is read or shown: the repo did not say it would
    cur, have = kit_current(), str(m.get("kit", ""))
    behind = bool(cur) and vtuple(have) < vtuple(cur)
    hooks = (Path(clone) / ".githooks").is_dir()
    return {"seated": True, "reporting": True, "version": have, "current": cur, "behind": behind,
            "applied": m.get("applied", ""), "guards": "seated" if hooks else "missing",
            "update": f"ymir projects kit update {pid}" if behind or not hooks else ""}


def ci_of(checks: list) -> str:
    if not checks:
        return "none"
    state = "green"
    for c in checks:
        v = (c.get("conclusion") or c.get("state") or c.get("status") or "").upper()
        if v in ("FAILURE", "ERROR", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "STARTUP_FAILURE"):
            return "red"
        if v in ("", "PENDING", "QUEUED", "IN_PROGRESS", "EXPECTED", "WAITING"):
            state = "pending"
    return state


def prs_of(p: dict, net: bool, refresh: bool) -> list[dict]:
    git = p.get("git") or {}
    if not net or git.get("host") != "github.com" or not git.get("owner") or not git.get("repo"):
        return []
    slug = f"{git['owner']}/{git['repo']}"
    ttl = int(os.environ.get("PROJECTS_STATUS_TTL", "60"))
    cache = state_dir() / "projects-status" / (slug.replace("/", "__") + ".json")
    if not refresh and cache.is_file() and time.time() - cache.stat().st_mtime < ttl:
        try:
            return json.loads(cache.read_text())
        except (OSError, ValueError):
            pass
    gh = os.environ.get("PROJECTS_STATUS_GH", "gh")
    if shutil.which(gh) is None and not os.path.isabs(gh):
        return []
    rc, out = run([gh, "pr", "list", "--repo", slug, "--state", "open", "--limit", "30", "--json",
                   "number,title,headRefName,isDraft,reviewDecision,statusCheckRollup,url"], timeout=25)
    if rc != 0:
        return []
    try:
        raw = json.loads(out)
    except ValueError:
        return []
    rows = [{"number": r.get("number"), "title": r.get("title", ""), "branch": r.get("headRefName", ""),
             "draft": bool(r.get("isDraft")), "review": (r.get("reviewDecision") or "none").lower(),
             "ci": ci_of(r.get("statusCheckRollup") or []), "url": r.get("url", "")} for r in raw]
    try:
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_text(json.dumps(rows))
    except OSError:
        pass
    return rows


def state_dir() -> Path:
    s = os.environ.get("YMIR_STATE_DIR")
    return Path(s) if s else home() / "state"


def seat_entry(p: dict, clone: str, seat: str, claim_map: dict) -> dict:
    base = default_branch(p, clone)
    wts = worktrees(p, clone, base, claim_map)
    rc, ts = run(["git", "log", "-1", "--all", "--format=%ct"], clone)
    last = int(ts.strip()) if rc == 0 and ts.strip().isdigit() else 0
    free = round(shutil.disk_usage(clone).free / 2**30, 1)
    return {"seat": seat, "reachable": True, "path": clone, "default_branch": base, "worktrees": wts,
            "worktree_count": len(wts), "stale_count": sum(1 for w in wts if w["stale"]),
            "kit": kit_state(clone, str(p.get("id", ""))), "last_activity": last, "disk_free_gb": free}


def remote_seats(rows_by_id: dict, projects: list[dict], here: str) -> None:
    """Ask every OTHER seat a project names (clones[]) for its own view, over the ssh ring."""
    wanted: dict[str, list[str]] = {}
    for p in projects:
        for s in (p.get("clones") or {}):
            if s != here:
                wanted.setdefault(s, []).append(str(p.get("id")))
    if not wanted:
        return
    hosts = {}
    try:
        hosts = (json.loads((home() / "hodd" / "data" / "fleet.json").read_text()).get("hosts") or {})
    except (OSError, ValueError):
        pass
    ssh = os.environ.get("PROJECTS_STATUS_SSH", "ssh")
    cmd = os.environ.get("PROJECTS_STATUS_SSH_CMD",
                         "bash -lc 'for d in ~/ymir-runtime ~/ymir; do [ -x $d/bin/records/projects-status.sh ] && exec $d/bin/records/projects-status.sh --local --no-net --json; done; exit 127'")
    for seat, ids in wanted.items():
        h = hosts.get(seat) or {}
        target = (f"{h['user']}@{h['tailnet']}" if h.get("user") and h.get("tailnet") else seat) if h or seat else seat
        if h.get("state") == "dark":
            reason = f"seat dark since {h.get('dark_since', '?')}"
            rc, out = 1, ""
        else:
            reason = "unreachable over the ring"
            rc, out = run([ssh, "-o", "BatchMode=yes", "-o", "ConnectTimeout=6", target, cmd], timeout=30)
        got: dict = {}
        if rc == 0:
            try:
                got = {r["id"]: r for r in json.loads(out).get("projects", [])}
            except (ValueError, KeyError, AttributeError):
                reason = "the seat answered, but not with a status"
        for pid in ids:
            row = rows_by_id.get(pid)
            if row is None:
                continue
            if pid in got and got[pid].get("where"):
                row["where"].extend(got[pid]["where"])
            else:
                row["where"].append({"seat": seat, "reachable": False, "reason": reason, "worktrees": [],
                                     "worktree_count": 0, "stale_count": 0, "kit": None})


def health_next(row: dict) -> None:
    health, nxt = [], []
    stale = sum(w.get("stale_count", 0) for w in row["where"])
    if stale:
        health.append(f"{stale} stale worktree(s)")
        nxt.append(f"ymir projects reap {row['id']}")
    for w in row["where"]:
        k = w.get("kit") or {}
        if k.get("reporting") and k.get("update"):
            health.append(f"kit {k.get('version')} → {k.get('current')}" if k.get("behind") else "kit guards missing")
            nxt.append(k["update"])
        if w.get("reachable") and w.get("disk_free_gb", 999) < DISK_FLOOR_GB:
            health.append(f"disk low on {w['seat']} ({w['disk_free_gb']} GB)")
    if row["ci"] == "red":
        health.append("a PR has red checks")
    for w in row["where"]:
        if not w.get("reachable"):
            health.append(f"{w['seat']}: {w.get('reason', 'unreachable')}")
    row["health"], row["next"] = health, nxt


def session_summary(pid: str) -> dict | None:
    """Plan 368: the sessions that touched this project (any tool), read from THIS machine's own index. No index, no field."""
    import importlib.util
    f = Path(__file__).with_name("sessions_index.py")
    try:
        spec = importlib.util.spec_from_file_location("sessions_index", f)
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        r = m.project_summary(pid)
        return r if r["sessions"] else None
    except Exception:
        return None


def build(a) -> dict:
    here = a.seat_name or this_seat()
    projects = registry()
    gmap = claims()
    rows: dict[str, dict] = {}
    for p in projects:
        pid = str(p.get("id", ""))
        if not pid:
            continue
        git = p.get("git") or {}
        vis = ((p.get("handling") or {}).get("visibility") or {}).get("value") or "unknown"
        row = {"id": pid, "name": p.get("name", pid), "realm": p.get("realm", ""), "visibility": vis,
               "remote": f"{git.get('host')}/{git.get('owner')}/{git.get('repo')}" if git.get("owner") else "",
               "where": [], "prs": [], "pr_count": 0, "ci": "none", "health": [], "next": []}
        clone = clone_here(p, here)
        if clone:
            clone = main_checkout(clone)   # from a worktree, still report the whole clone
            row["where"].append(seat_entry(p, clone, here, gmap))
        rows[pid] = row
    if a.fleet and not a.here_only:
        remote_seats(rows, projects, here)   # opt-in: other seats are asked only in fleet mode
    out = []
    by_id = {str(p.get("id")): p for p in projects}
    keep = [pid for pid, row in rows.items() if a.all or row["where"]]   # default: a clone on some seat
    if not a.here_only:
        from concurrent.futures import ThreadPoolExecutor
        with ThreadPoolExecutor(8) as ex:   # one gh call per repo, in parallel; each cached for a minute
            for pid, prs in zip(keep, ex.map(lambda i: prs_of(by_id[i], not a.no_net and bool(rows[i]["where"]), a.refresh), keep)):
                rows[pid]["prs"] = prs
    for pid in keep:
        row = rows[pid]
        row["pr_count"] = len(row["prs"])
        row["ci"] = "red" if any(x["ci"] == "red" for x in row["prs"]) else (
            "pending" if any(x["ci"] == "pending" for x in row["prs"]) else ("green" if row["prs"] else "none"))
        health_next(row)
        row["sessions"] = session_summary(pid) if row["where"] else None
        out.append(row)
    out = [r for r in out if (not a.realm or r["realm"] == a.realm)
           and (not a.seat or any(w["seat"] == a.seat for w in r["where"]))
           and (not a.has_prs or r["pr_count"])
           and (not a.red or r["ci"] == "red")
           and (not a.stale or any(w.get("stale_count") for w in r["where"]))
           and (not a.public_view or r["visibility"] == "public")]
    out.sort(key=lambda r: (-max([w.get("last_activity", 0) for w in r["where"]] or [0]), r["id"]))
    return {"seat": here, "kit_current": kit_current(), "generated": int(time.time()), "count": len(out), "projects": out}


def toon(doc: dict) -> str:
    q = lambda s: '"' + str(s).replace('"', "'") + '"'
    lines = [f"projects[{doc['count']}]{{id,realm,seat,worktrees,stale,prs,ci,kit,next}}:"]
    for r in doc["projects"]:
        seats = ",".join(w["seat"] + ("" if w.get("reachable") else "!") for w in r["where"]) or "-"
        wt = sum(w.get("worktree_count", 0) for w in r["where"])
        st = sum(w.get("stale_count", 0) for w in r["where"])
        kits = [w["kit"] for w in r["where"] if w.get("kit")]
        k = "-" if not kits else ("seated, not reporting" if not kits[0].get("reporting") else
                                  (f"kit {kits[0]['version']} → {kits[0]['current']}" if kits[0].get("behind") else f"kit {kits[0]['version']}"))
        lines.append("  " + ",".join(q(x) for x in (r["id"], r["realm"], seats, wt, st, r["pr_count"], r["ci"], k,
                                                   "; ".join(r["next"]) or "-")))
    return "\n".join(lines)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="projects-status.sh", description=__doc__.split("\n")[0])
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--local", dest="here_only", action="store_true", help="this seat only; no ssh, no PR lookup")
    ap.add_argument("--fleet", action="store_true", help="also ask the other seats over the ring (default: this machine only)")
    ap.add_argument("--no-net", action="store_true", help="no GitHub call")
    ap.add_argument("--refresh", action="store_true", help="ignore the one-minute PR cache")
    ap.add_argument("--all", action="store_true", help="also list registry rows with no clone on any seat")
    ap.add_argument("--realm")
    ap.add_argument("--seat")
    ap.add_argument("--has-prs", action="store_true")
    ap.add_argument("--red", action="store_true")
    ap.add_argument("--stale", action="store_true")
    ap.add_argument("--public-view", action="store_true", help="only projects marked public (a shared view)")
    ap.add_argument("--seat-name", help="name this seat (tests)")
    ap.add_argument("-v", "--version", action="version", version=VERSION)
    a = ap.parse_args(argv)
    doc = build(a)
    print(json.dumps(doc) if a.json else toon(doc))
    return 0


if __name__ == "__main__":
    sys.exit(main())

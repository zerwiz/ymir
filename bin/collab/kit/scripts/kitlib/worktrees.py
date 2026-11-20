#!/usr/bin/env python3
"""worktrees — one task, one worktree, and a lifecycle the kit enforces from creation to removal.

  new      refuses below the disk floor, past the leftover budget or past the cap; closes merged worktrees
           first; links the dependency folders the stack profile names; writes an owner/purpose/expiry record
  list     every worktree of the repository with its state and why
  done     closes one worktree; refuses to lose work (salvage first)
  gc       closes every worktree whose work is safe; salvages a dead worker's work first
  salvage  commits and pushes a dead worker's uncommitted or unpushed work on its own branch

Nothing is removed while a process works inside it, or while it holds work that exists nowhere else.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import time
from dataclasses import dataclass, field, asdict
from pathlib import Path

from .config import Config, busy_in, busy_paths, common_dir, disk_gate, git, ledger, main_tree

SALVAGE_SUBJECT = "WIP (worker gone): saved as found, not reviewed"


@dataclass
class Tree:
    path: str
    head: str = ""
    branch: str = ""
    locked: bool = False
    prunable: bool = False
    record: dict = field(default_factory=dict)
    exists: bool = True
    dirty: int = 0
    unpushed: int = 0
    merged: bool = False
    idle_hours: float = 0.0
    busy_pid: int | None = None
    verdict: str = ""  # remove | salvage | keep
    reason: str = ""

    @property
    def id(self) -> str:
        return self.record.get("id") or os.path.basename(self.path)


def default_branch(root) -> str:
    r = git("symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD", cwd=str(root))
    if r.returncode == 0 and r.stdout.strip():
        return r.stdout.strip()  # origin/main
    for c in ("origin/main", "origin/master", "main", "master"):
        if git("rev-parse", "--verify", "-q", c, cwd=str(root)).returncode == 0:
            return c
    return "HEAD"


def has_remote(root) -> bool:
    return bool(git("remote", cwd=str(root)).stdout.strip())


def gitdir_of(path) -> Path | None:
    r = git("rev-parse", "--path-format=absolute", "--git-dir", cwd=str(path))
    return Path(r.stdout.strip()) if r.returncode == 0 else None


def read_record(path) -> dict:
    gd = gitdir_of(path)
    if gd and (gd / "kit.json").is_file():
        try:
            return json.loads((gd / "kit.json").read_text())
        except ValueError:
            return {}
    return {}


def listing(root) -> list[Tree]:
    r = git("worktree", "list", "--porcelain", cwd=str(root), check=True)
    trees, cur = [], None
    for line in r.stdout.splitlines() + [""]:
        if line.startswith("worktree "):
            cur = Tree(path=line[9:])
        elif cur is None:
            continue
        elif line.startswith("HEAD "):
            cur.head = line[5:]
        elif line.startswith("branch "):
            cur.branch = line[7:].removeprefix("refs/heads/")
        elif line.startswith("locked"):
            cur.locked = True
        elif line.startswith("prunable"):
            cur.prunable = True
        elif line == "":
            trees.append(cur)
            cur = None
    return trees[1:]  # the first is the main tree


def _idle_hours(t: Tree) -> float:
    gd = gitdir_of(t.path)
    stamps = []
    for p in (gd / "index", gd / "HEAD", gd / "logs" / "HEAD") if gd else ():
        try:
            stamps.append(p.stat().st_mtime)
        except OSError:
            pass
    created = t.record.get("created_epoch")
    if created:
        stamps.append(float(created))
    if not stamps:
        try:
            stamps.append(Path(t.path).stat().st_mtime)
        except OSError:
            return 1e9
    return round((time.time() - max(stamps)) / 3600, 1)


def inspect(cfg: Config, root, busy=None, base=None) -> list[Tree]:
    busy = busy_paths() if busy is None else busy
    base = base or default_branch(root)
    trees = listing(root)
    # merged means: in the remote's default branch, or in the local one (a merge made here, before its push)
    merge_refs = [base]
    local = base.split("/", 1)[1] if base.startswith("origin/") else ""
    if local and git("rev-parse", "--verify", "-q", f"refs/heads/{local}", cwd=str(root)).returncode == 0:
        merge_refs.append(f"refs/heads/{local}")
    for t in trees:
        t.exists = os.path.isdir(t.path)
        if not t.exists:
            continue
        t.record = read_record(t.path)
        st = git("status", "--porcelain", "--ignore-submodules=dirty", cwd=t.path)
        t.dirty = len([l for l in st.stdout.splitlines() if l.strip()])
        if has_remote(root):
            up = git("rev-list", "--count", "HEAD", "--not", "--remotes", cwd=t.path)
            t.unpushed = int(up.stdout.strip() or 0) if up.returncode == 0 else 0
        else:
            t.unpushed = int(git("rev-list", "--count", "HEAD", "--not", base, cwd=t.path).stdout.strip() or 0)
        t.merged = any(git("merge-base", "--is-ancestor", "HEAD", ref, cwd=t.path).returncode == 0 for ref in merge_refs)
        t.idle_hours = _idle_hours(t)
        t.busy_pid = busy_in(t.path, busy)
    return trees


def judge(cfg: Config, t: Tree, keep: set[str], merged_only=False) -> Tree:
    stale_h = float(cfg["worktrees"]["stale_hours"])
    expires = t.record.get("expires_epoch")
    expired = bool(expires) and time.time() > float(expires)
    if not t.exists:
        t.verdict, t.reason = "remove", "its folder is gone; git still lists it"
    elif t.locked:
        t.verdict, t.reason = "keep", "locked (git worktree lock)"
    elif t.id in keep or os.path.basename(t.path) in keep:
        t.verdict, t.reason = "keep", "kept by name (--keep)"
    elif t.busy_pid:
        t.verdict, t.reason = "keep", f"a process works in it (pid {t.busy_pid})"
    elif t.dirty or t.unpushed:
        work = f"{t.dirty} uncommitted, {t.unpushed} unpushed"
        if t.idle_hours >= stale_h and not merged_only:
            t.verdict, t.reason = "salvage", f"worker gone (idle {t.idle_hours:g} h): {work} — saved to the remote first"
        else:
            t.verdict, t.reason = "keep", f"work in progress ({work}), active {t.idle_hours:g} h ago"
    elif t.merged:
        t.verdict, t.reason = "remove", "merged into the default branch, clean, nothing unpushed"
    elif merged_only:
        t.verdict, t.reason = "keep", "not merged (merged-only run)"
    elif expired:
        t.verdict, t.reason = "remove", "past its expiry; clean and everything is on the remote"
    elif t.idle_hours >= stale_h:
        t.verdict, t.reason = "remove", f"idle {t.idle_hours:g} h; clean and everything is on the remote"
    else:
        t.verdict, t.reason = "keep", f"active {t.idle_hours:g} h ago, pushed, not merged"
    return t


def _branch_safe_to_delete(root, branch: str, base: str) -> bool:
    if not branch:
        return False
    if git("merge-base", "--is-ancestor", f"refs/heads/{branch}", base, cwd=str(root)).returncode == 0:
        return True
    r = git("rev-list", "--count", f"refs/heads/{branch}", "--not", "--remotes", cwd=str(root))
    return r.returncode == 0 and r.stdout.strip() == "0" and has_remote(root)


def remove(root, t: Tree, base: str) -> str:
    if not t.exists:
        git("worktree", "prune", cwd=str(root))
        return "pruned the stale entry"
    # never follow a dependency link out of the worktree: unlink the kit's links before git removes the folder
    for link in t.record.get("links", []):
        p = Path(t.path) / link
        if p.is_symlink():
            p.unlink()
    r = git("worktree", "remove", "--force", t.path, cwd=str(root))
    if r.returncode != 0:
        return f"git refused: {r.stderr.strip()}"
    note = "removed"
    if t.branch and _branch_safe_to_delete(root, t.branch, base):
        git("branch", "-D", t.branch, cwd=str(root))
        note += f"; branch {t.branch} deleted (its commits are on the remote or merged)"
    elif t.branch:
        note += f"; branch {t.branch} kept (it holds commits not on the remote)"
    return note


def salvage(root, t: Tree) -> tuple[bool, str]:
    """Commit what a dead worker left, on its own branch, and push it. True only once it is on the remote."""
    if not has_remote(root):
        return False, "no remote to save it to — kept"
    branch = t.branch
    if not branch:
        branch = f"salvage/{t.id}-{time.strftime('%Y%m%d-%H%M')}"
        r = git("checkout", "-q", "-b", branch, cwd=t.path)
        if r.returncode != 0:
            return False, f"could not name a branch for it: {r.stderr.strip()}"
    if t.dirty:
        git("add", "-A", ".", cwd=t.path)
        msg = (f"{SALVAGE_SUBJECT}\n\nSaved by the kit's salvage on {time.strftime('%Y-%m-%d %H:%M %Z')} from "
               f"{t.path}: {t.dirty} uncommitted path(s). Nobody has reviewed or tested it.\n")
        # the hooks are skipped on purpose: a dead worker's tree may not pass them, and losing it is worse
        r = subprocess.run(["git", "-c", "core.hooksPath=/dev/null", "commit", "-q", "--no-verify", "-m", msg],
                           cwd=t.path, text=True, capture_output=True)
        if r.returncode != 0:
            return False, f"commit failed: {(r.stderr or r.stdout).strip()}"
    r = subprocess.run(["git", "-c", "core.hooksPath=/dev/null", "push", "-q", "--no-verify", "-u", "origin",
                        f"HEAD:refs/heads/{branch}"], cwd=t.path, text=True, capture_output=True)
    if r.returncode != 0:
        return False, f"push failed — kept: {r.stderr.strip()[:200]}"
    t.branch = branch
    return True, f"saved to origin/{branch}"


def run_gc(cfg: Config, root, apply: bool, keep: set[str], merged_only=False, only: set[str] | None = None) -> list[dict]:
    base = default_branch(root)
    rows = []
    for t in inspect(cfg, root, base=base):
        if only and t.id not in only and os.path.basename(t.path) not in only:
            continue
        judge(cfg, t, keep, merged_only)
        row = {"id": t.id, "path": t.path, "branch": t.branch, "verdict": t.verdict, "reason": t.reason, "done": ""}
        if apply and t.verdict == "salvage":
            ok, note = salvage(root, t)
            row["done"] = note
            if ok:
                ledger(root, "salvage", id=t.id, branch=t.branch, path=t.path)
                row["done"] += "; " + remove(root, t, base)
                ledger(root, "close", id=t.id, path=t.path, why="salvaged")
        elif apply and t.verdict == "remove":
            row["done"] = remove(root, t, base)
            ledger(root, "close", id=t.id, path=t.path, why=t.reason)
        rows.append(row)
    if apply:
        git("worktree", "prune", cwd=str(root))
    return rows


def _link_deps(cfg: Config, main: Path, wt: Path) -> list[str]:
    """Share the dependency folders the stack profile names with the main tree.

    link_mode symlink (the default) points at the main tree's folder. link_mode reflink makes a copy-on-write copy
    (btrfs, XFS, APFS): a real folder that costs almost no disk — for tools that refuse a link leaving the project
    root (Next.js Turbopack does). Where the filesystem cannot reflink, the kit falls back to a symlink and says so.
    """
    links = []
    default_mode = cfg["stack"].get("link_mode") or "symlink"
    wanted = [(".", l, default_mode) for l in cfg["stack"].get("link") or []]
    for part in cfg["stack"].get("parts") or []:
        for l in part.get("link") or []:
            wanted.append((part.get("path", "."), l, part.get("link_mode") or default_mode))
    exclude = common_dir(main) / "info" / "exclude"
    lines = exclude.read_text().splitlines() if exclude and exclude.is_file() else []
    for part_path, l, mode in wanted:
        rel = os.path.normpath(os.path.join(part_path, l))
        src, dst = main / rel, wt / rel
        if not src.exists() or os.path.lexists(dst) or not dst.parent.is_dir():
            continue  # nothing to share, or the tree already carries it (a tracked link stays as it is)
        done = False
        if mode == "reflink":
            r = subprocess.run(["cp", "-a", "--reflink=always", os.path.realpath(src), str(dst)],
                               text=True, capture_output=True)
            if r.returncode == 0:
                done = True
                print(f"reflinked\t{rel}\t(copy-on-write: shares the main tree's blocks)")
            else:
                shutil.rmtree(dst, ignore_errors=True)
                print(f"note\t{rel}: this filesystem cannot reflink — linked instead")
        if not done:
            os.symlink(os.path.realpath(src), dst)
            links.append(rel)
        if f"/{rel}" not in lines:
            lines.append(f"/{rel}")
    exclude.parent.mkdir(parents=True, exist_ok=True)
    exclude.write_text("\n".join(lines) + "\n")
    return links


def new(cfg: Config, root, wid: str, base: str | None, owner: str, purpose: str, expiry_days: float | None,
        no_close: bool = False) -> int:
    if not re.fullmatch(r"[A-Za-z0-9._-]+", wid or ""):
        print(f"refused: unsafe id {wid!r} — letters, digits, dot, dash and underscore only")
        return 2
    main = main_tree(str(root))
    ok, msg = disk_gate(cfg, main)
    if not ok:
        print(f"refused: the disk is below the floor — {msg}.\nhelp: bash scripts/prune.sh to see what can go, then --apply")
        return 1
    wcfg = cfg["worktrees"]
    if wcfg.get("close_merged_on_new", True) and not no_close:
        for row in run_gc(cfg, main, apply=True, keep=set(), merged_only=True):
            if row["verdict"] == "remove":
                print(f"closed\t{row['id']}\t{row['reason']}")
    base_ref = base or default_branch(main)
    trees = inspect(cfg, main, base=base_ref if "/" in base_ref else None)
    for t in trees:
        judge(cfg, t, set())
    leftovers = [t for t in trees if t.verdict in ("remove", "salvage")]
    if len(leftovers) > int(wcfg["max_leftovers"]):
        print(f"refused: {len(leftovers)} worktrees are leftovers (the budget is {wcfg['max_leftovers']}): "
              + ", ".join(t.id for t in leftovers[:5])
              + "\nhelp: bash scripts/worktree.sh gc   (then gc --apply)")
        return 1
    live = [t for t in trees if t.exists]
    if len(live) >= int(wcfg["max"]):
        merged = sorted([t for t in live if t.merged], key=lambda t: -t.idle_hours)
        pick = merged[0] if merged else sorted(live, key=lambda t: -t.idle_hours)[0]
        what = "oldest merged" if merged else "oldest"
        print(f"refused: {len(live)} worktrees already (the cap is {wcfg['max']}). The {what} is {pick.id} "
              f"({pick.path}, idle {pick.idle_hours:g} h).\nhelp: bash scripts/worktree.sh done {pick.id}")
        return 1
    if "/" not in base_ref and has_remote(main):
        git("fetch", "-q", "origin", base_ref, cwd=str(main))
        if git("rev-parse", "--verify", "-q", f"origin/{base_ref}", cwd=str(main)).returncode == 0:
            base_ref = f"origin/{base_ref}"
    elif has_remote(main):
        git("fetch", "-q", "origin", cwd=str(main))
    path = main / cfg["names"]["worktrees"] / wid
    branch = f"{cfg['names']['branch_prefix']}/{wid}"
    if os.path.lexists(path):
        print(f"refused: {path} already exists")
        return 1
    path.parent.mkdir(parents=True, exist_ok=True)
    r = git("worktree", "add", "-q", "--no-track", "-b", branch, str(path), base_ref, cwd=str(main))
    if r.returncode != 0:
        print(f"refused: git worktree add failed: {r.stderr.strip()}")
        return 1
    links = _link_deps(cfg, main, path)
    from .hooks import seat_worktree
    seat_worktree(main, path)
    now = time.time()
    days = float(expiry_days if expiry_days is not None else wcfg["expiry_days"])
    rec = {"id": wid, "branch": branch, "base": base_ref, "owner": owner, "purpose": purpose,
           "created": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now)), "created_epoch": int(now),
           "expires": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now + days * 86400)),
           "expires_epoch": int(now + days * 86400), "links": links, "kit": "2.0.0"}
    gd = gitdir_of(path)
    (gd / "kit.json").write_text(json.dumps(rec, indent=2) + "\n")
    ledger(main, "new", id=wid, branch=branch, owner=owner, purpose=purpose, path=str(path))
    print(f"worktree\t{wid}\t{branch}\t{path}")
    if links:
        print("linked\t" + " ".join(links))
    print(f"expires\t{rec['expires']}\t(closed by gc once merged or idle; salvage saves unfinished work first)")
    return 0


def done(cfg: Config, root, wid: str, do_salvage: bool) -> int:
    main = main_tree(str(root))
    base = default_branch(main)
    match = [t for t in inspect(cfg, main, base=base) if t.id == wid or os.path.basename(t.path) == wid]
    if not match:
        print(f"no worktree named {wid}")
        return 1
    t = match[0]
    if t.busy_pid:
        print(f"refused: a process works in {t.path} (pid {t.busy_pid}) — stop it first")
        return 1
    if t.dirty or t.unpushed:
        if not do_salvage:
            print(f"refused: {t.id} holds {t.dirty} uncommitted and {t.unpushed} unpushed change(s).\n"
                  f"help: commit and push them, or: bash scripts/worktree.sh done {t.id} --salvage")
            return 1
        ok, note = salvage(main, t)
        print(f"salvage\t{t.id}\t{note}")
        if not ok:
            return 1
        ledger(main, "salvage", id=t.id, branch=t.branch, path=t.path)
    note = remove(main, t, base)
    ledger(main, "close", id=t.id, path=t.path, why="done")
    print(f"closed\t{t.id}\t{note}")
    return 0


def size_mb(path) -> int:
    r = subprocess.run(["du", "-sxm", str(path)], text=True, capture_output=True)
    try:
        return int(r.stdout.split()[0])
    except (IndexError, ValueError):
        return -1


def list_rows(cfg: Config, root, sizes=False) -> list[dict]:
    main = main_tree(str(root))
    rows = []
    for t in inspect(cfg, main):
        judge(cfg, t, set())
        row = {"id": t.id, "branch": t.branch or "(detached)", "state": t.verdict, "why": t.reason,
               "owner": t.record.get("owner", ""), "purpose": t.record.get("purpose", ""),
               "expires": t.record.get("expires", ""), "path": t.path}
        if sizes:
            row["mb"] = size_mb(t.path) if t.exists else 0
        rows.append(row)
    return rows

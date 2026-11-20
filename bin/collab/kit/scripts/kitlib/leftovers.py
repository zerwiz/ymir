"""leftovers — everything a development task leaves behind, each class declared in project.yaml with its rule.

  worktrees           closed when merged, or idle and safe; a dead worker's work is salvaged first
  branches            local branches already merged into the default branch, checked out nowhere
  remote_refs         remote-tracking refs whose branch is gone from the remote
  caches              build outputs (stack never_share) inside worktrees nobody has touched for idle_hours
  scratch             files under the declared scratch folder older than older_than_hours
  test_databases      databases matching the declared pattern (list/drop commands declared by the project)
  images              the project's dangling images and every tag past containers.keep_tags
  volumes             the project's dangling volumes
  stopped_containers  the project's containers stopped longer than older_than_hours

A report by default; --apply acts. Nothing with a live process in it, nothing holding work that exists
nowhere else, and nothing on a product host.
"""
from __future__ import annotations

import fnmatch
import os
import shlex
import shutil
import subprocess
import time
from pathlib import Path

from . import containers as ct
from . import worktrees as wt
from .config import Config, busy_in, busy_paths, git, is_product_host, ledger, main_tree

CLASSES = ["worktrees", "branches", "remote_refs", "caches", "scratch", "test_databases", "images", "volumes",
           "stopped_containers"]


def _row(cls, target, verdict, reason, done=""):
    return {"class": cls, "target": target, "verdict": verdict, "reason": reason, "done": done}


def c_worktrees(cfg, root, apply, keep, merged_only=False):
    return [_row("worktrees", r["id"], r["verdict"], r["reason"], r["done"])
            for r in wt.run_gc(cfg, root, apply, keep, merged_only)]


def c_branches(cfg, root, apply, keep):
    base = wt.default_branch(root)
    short = base.split("/", 1)[-1]
    out_in_use = {t.branch for t in wt.listing(root)}
    cur = git("branch", "--show-current", cwd=str(root)).stdout.strip()
    out_in_use.add(cur)
    rows = []
    for b in git("for-each-ref", "--format=%(refname:short)", "refs/heads", cwd=str(root)).stdout.split():
        if b in (short, "main", "master") or b in out_in_use or b in keep:
            continue
        if git("merge-base", "--is-ancestor", f"refs/heads/{b}", base, cwd=str(root)).returncode != 0:
            continue  # unmerged branches are someone's work: not a leftover this class judges
        row = _row("branches", b, "remove", f"merged into {base}, checked out nowhere")
        if apply:
            r = git("branch", "-D", b, cwd=str(root))
            row["done"] = "deleted" if r.returncode == 0 else r.stderr.strip()
            ledger(root, "prune", cls="branches", target=b)
        rows.append(row)
    return rows


def c_remote_refs(cfg, root, apply, keep):
    rows = []
    for remote in git("remote", cwd=str(root)).stdout.split():
        r = git("remote", "prune", "--dry-run", remote, cwd=str(root))
        for line in r.stdout.splitlines():
            line = line.strip()
            if line.startswith("* [would prune]"):
                rows.append(_row("remote_refs", line.split("]", 1)[1].strip(), "remove", "gone from the remote"))
        if apply and rows:
            git("remote", "prune", remote, cwd=str(root))
            for row in rows:
                row["done"] = "pruned"
            ledger(root, "prune", cls="remote_refs", n=len(rows))
    return rows


def _never_share(cfg) -> list[str]:
    out = list(cfg["stack"].get("never_share") or [])
    for part in cfg["stack"].get("parts") or []:
        for n in part.get("never_share") or []:
            out.append(os.path.normpath(os.path.join(part.get("path", "."), n)))
    return out


def c_caches(cfg, root, apply, keep):
    hours = float(cfg["leftovers"]["caches"].get("idle_hours", 24))
    busy = busy_paths()
    rows = []
    for t in wt.inspect(cfg, root, busy=busy):
        if not t.exists or t.busy_pid or t.idle_hours < hours or t.id in keep:
            continue
        for rel in _never_share(cfg):
            p = Path(t.path) / rel
            if not p.is_dir() or p.is_symlink():
                continue
            if git("check-ignore", "-q", rel, cwd=t.path).returncode != 0:
                continue  # only an ignored build output is a cache; a tracked folder is work
            row = _row("caches", str(p), "remove", f"build output in a worktree idle {t.idle_hours:g} h")
            if apply:
                shutil.rmtree(p, ignore_errors=True)
                row["done"] = "removed"
                ledger(root, "prune", cls="caches", target=str(p))
            rows.append(row)
    return rows


def _scratch_dir(cfg, root) -> Path | None:
    d = (cfg["leftovers"]["scratch"].get("dir") or "").strip()
    if not d:
        return None
    p = Path(os.path.expanduser(d))
    p = p if p.is_absolute() else Path(root) / p
    p = Path(os.path.realpath(p))
    home = Path(os.path.realpath(os.path.expanduser("~")))
    if p in (Path("/"), home, Path(os.path.realpath(root))) or len(p.parts) < 3:
        raise SystemExit(f"refused: the scratch folder {p} is too broad to empty")
    return p


def c_scratch(cfg, root, apply, keep):
    d = _scratch_dir(cfg, root)
    if not d or not d.is_dir():
        return []
    hours = float(cfg["leftovers"]["scratch"].get("older_than_hours", 24))
    busy = busy_paths()
    now, rows = time.time(), []
    for p in sorted(d.iterdir()):
        try:
            age = (now - p.lstat().st_mtime) / 3600
        except OSError:
            continue
        if age < hours or p.name in keep:
            continue
        if busy_in(p, busy):
            rows.append(_row("scratch", str(p), "keep", "a process works in it"))
            continue
        row = _row("scratch", str(p), "remove", f"scratch, untouched {age:.0f} h")
        if apply:
            if p.is_dir() and not p.is_symlink():
                shutil.rmtree(p, ignore_errors=True)
            else:
                p.unlink(missing_ok=True)
            row["done"] = "removed"
            ledger(root, "prune", cls="scratch", target=str(p))
        rows.append(row)
    return rows


def c_test_databases(cfg, root, apply, keep):
    spec = cfg["leftovers"]["test_databases"]
    pattern, list_cmd, drop_cmd = spec.get("pattern"), spec.get("list"), spec.get("drop")
    if not (pattern and list_cmd):
        return []
    r = subprocess.run(list_cmd, shell=True, text=True, capture_output=True, cwd=str(root))
    if r.returncode != 0:
        return [_row("test_databases", pattern, "keep", f"the list command failed: {r.stderr.strip()[:120]}")]
    rows = []
    for name in sorted({l.strip() for l in r.stdout.splitlines() if l.strip()}):
        if not fnmatch.fnmatch(name, pattern) or name in keep:
            continue
        row = _row("test_databases", name, "remove", f"a test database ({pattern})")
        if apply and spec.get("apply") and drop_cmd:
            d = subprocess.run(drop_cmd.replace("{name}", shlex.quote(name)), shell=True, text=True,
                               capture_output=True, cwd=str(root))
            row["done"] = "dropped" if d.returncode == 0 else f"drop failed: {d.stderr.strip()[:120]}"
            ledger(root, "prune", cls="test_databases", target=name)
        elif apply:
            row["done"] = "report only (leftovers.test_databases.apply is false)"
        rows.append(row)
    return rows


def _container_guard(cfg, cls) -> list[dict] | None:
    prod, why = is_product_host(cfg)
    if prod:
        return [_row(cls, "*", "keep", f"a product host ({why}): only the operator's deploy door removes here")]
    if not ct.engine(cfg):
        return []
    return None


def c_images(cfg, root, apply, keep):
    g = _container_guard(cfg, "images")
    if g is not None:
        return g
    plan = ct.retention_plan(cfg, ct.images(cfg) or [], cfg["project"])
    e = ct.engine(cfg)
    rows = [_row("images", i, "remove", "dangling image the project's builds left") for i in plan["dangling"]]
    rows += [_row("images", t, "remove", f"past the newest {cfg['containers']['keep_tags']} tags") for t in plan["extra_tags"]]
    if apply:
        for row in rows:
            r = subprocess.run([e, "rmi", row["target"]], text=True, capture_output=True)
            row["done"] = "removed" if r.returncode == 0 else r.stderr.strip()[:120]
            ledger(root, "prune", cls="images", target=row["target"])
    return rows


def c_volumes(cfg, root, apply, keep):
    g = _container_guard(cfg, "volumes")
    if g is not None:
        return g
    e = ct.engine(cfg)
    rows = [_row("volumes", v.get("Name", ""), "remove", "dangling volume labelled for the project")
            for v in (ct.volumes(cfg, cfg["project"]) or []) if v.get("Name") not in keep]
    if apply:
        for row in rows:
            r = subprocess.run([e, "volume", "rm", row["target"]], text=True, capture_output=True)
            row["done"] = "removed" if r.returncode == 0 else r.stderr.strip()[:120]
            ledger(root, "prune", cls="volumes", target=row["target"])
    return rows


def c_stopped_containers(cfg, root, apply, keep):
    g = _container_guard(cfg, "stopped_containers")
    if g is not None:
        return g
    e = ct.engine(cfg)
    hours = float(cfg["leftovers"]["stopped_containers"].get("older_than_hours", 24))
    rows = [_row("stopped_containers", c["name"] or c["id"], "remove", f"stopped {c['hours']:g} h")
            for c in ct.stopped_older(cfg, ct.containers(cfg) or [], hours, cfg["project"]) if c["name"] not in keep]
    if apply:
        for row in rows:
            r = subprocess.run([e, "rm", row["target"]], text=True, capture_output=True)
            row["done"] = "removed" if r.returncode == 0 else r.stderr.strip()[:120]
            ledger(root, "prune", cls="stopped_containers", target=row["target"])
    return rows


def run(cfg: Config, root, classes: list[str], apply: bool, keep: set[str], merged_only=False) -> list[dict]:
    root = main_tree(str(root))
    rows = []
    for cls in classes:
        if cls not in CLASSES:
            raise SystemExit(f"unknown class {cls!r}; known: {', '.join(CLASSES)}")
        spec = cfg["leftovers"].get(cls) or {}
        act = apply and spec.get("apply", True) is not False
        fn = globals()[f"c_{cls}"]
        rows += fn(cfg, root, act, keep, merged_only) if cls == "worktrees" else fn(cfg, root, act, keep)
        if apply and not act:
            for r in rows:
                if r["class"] == cls and not r["done"]:
                    r["done"] = "report only (leftovers.%s.apply is false)" % cls
    return rows

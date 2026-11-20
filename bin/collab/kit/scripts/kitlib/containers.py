#!/usr/bin/env python3
"""containers — the door every container and image command of a project goes through.

  a developer machine builds; a product host runs the product, one pod per host
  no worker creates, removes, untags or prunes anything on a product host — the operator's deploy door does
  one image build at a time per machine (a lock), and every image carries the labels project/purpose/release
  after a release ships: keep the current and the previous tag, clear the project's build leftovers
"""
from __future__ import annotations

import fcntl
import json
import os
import shutil
import subprocess
import time
from pathlib import Path

from .config import Config, disk_gate, is_product_host, ledger

MUTATING = {"run", "create", "rm", "rmi", "prune", "untag", "tag", "kill", "stop", "start", "restart",
            "build", "pull", "push", "load", "import", "commit", "pod", "volume", "network", "system", "image",
            "container", "builder", "buildx", "compose", "play", "kube", "update", "rename"}
READ_ONLY_SUB = {"ls", "list", "inspect", "ps", "logs", "top", "stats", "exists", "history", "port", "diff"}


def engine(cfg: Config) -> str | None:
    e = cfg["containers"].get("engine") or "podman"
    return e if shutil.which(e) else None


def _json(cmd: list[str]):
    r = subprocess.run(cmd, text=True, capture_output=True)
    if r.returncode != 0:
        return None
    out = r.stdout.strip()
    if not out:
        return []
    try:
        data = json.loads(out)
        return data if isinstance(data, list) else [data]
    except ValueError:
        return [json.loads(l) for l in out.splitlines() if l.strip().startswith("{")]


def images(cfg: Config) -> list[dict] | None:
    e = engine(cfg)
    return _json([e, "images", "--format", "json"]) if e else None


def containers(cfg: Config) -> list[dict] | None:
    e = engine(cfg)
    return _json([e, "ps", "-a", "--format", "json"]) if e else None


def volumes(cfg: Config, project: str) -> list[dict] | None:
    e = engine(cfg)
    if not e:
        return None
    return _json([e, "volume", "ls", "--filter", f"label=project={project}", "--filter", "dangling=true",
                  "--format", "json"])


def _labels(obj) -> dict:
    return obj.get("Labels") or {}


def _tags(img) -> list[str]:
    names = img.get("Names") or img.get("RepoTags") or []
    return [n for n in names if n and "<none>" not in n]


def _created(img) -> float:
    c = img.get("Created", 0)
    if isinstance(c, (int, float)):
        return float(c)
    try:
        return time.mktime(time.strptime(str(c)[:19], "%Y-%m-%dT%H:%M:%S"))
    except ValueError:
        return 0.0


def retention_plan(cfg: Config, imgs: list[dict], project: str | None = None) -> dict:
    """What retention would remove: the project's dangling images and every tag past keep_tags per repository."""
    keep = int(cfg["containers"]["keep_tags"])
    required = cfg["containers"].get("labels") or []
    dangling, extra, unlabelled, per_repo = [], [], [], {}
    for img in imgs:
        labels = _labels(img)
        if any(k not in labels for k in required):
            unlabelled.append(img.get("Id", "")[:12])
        if project and labels.get("project") != project:
            continue
        tags = _tags(img)
        if not tags:
            if labels.get("project"):
                dangling.append(img.get("Id", "")[:12])
            continue
        for t in tags:
            repo = t.rsplit(":", 1)[0]
            per_repo.setdefault(repo, []).append((_created(img), t))
    for repo, tagged in per_repo.items():
        tagged.sort(reverse=True)
        extra.extend(t for _, t in tagged[keep:])
    return {"dangling": dangling, "extra_tags": extra, "unlabelled": unlabelled,
            "repos": {r: len(v) for r, v in per_repo.items()}}


def stopped_older(cfg: Config, conts: list[dict], hours: float, project: str | None = None) -> list[dict]:
    now, out = time.time(), []
    for c in conts:
        if project and _labels(c).get("project") != project:
            continue
        state = (c.get("State") or "").lower()
        if state not in ("exited", "stopped", "created", "dead"):
            continue
        at = c.get("ExitedAt") or c.get("Created") or 0
        if isinstance(at, (int, float)) and at > 0 and now - float(at) >= hours * 3600:
            out.append({"id": (c.get("Id") or "")[:12], "name": (c.get("Names") or [""])[0],
                        "hours": round((now - float(at)) / 3600, 1)})
    return out


def lock_path() -> Path:
    base = os.environ.get("KIT_LOCK_DIR") or os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
    return Path(base) / f"collab-kit-image-build-{os.getuid()}.lock"


def build(cfg: Config, root, tag: str, purpose: str, release: str, context: str, extra: list[str]) -> int:
    prod, why = is_product_host(cfg)
    if prod:
        print(f"refused: this machine is a product host ({why}) — images are built on a developer machine")
        return 1
    ok, msg = disk_gate(cfg, root)
    if not ok:
        print(f"refused: the disk is below the floor — {msg}")
        return 1
    if not (tag and purpose and release):
        print("refused: a build needs --tag, --purpose and --release (the labels project/purpose/release)")
        return 2
    e = engine(cfg)
    if not e:
        print(f"refused: {cfg['containers']['engine']} is not installed")
        return 1
    lp = lock_path()
    fh = open(lp, "a+")
    try:
        fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        fh.seek(0)
        print(f"refused: another image build holds the lock ({fh.read().strip() or lp}) — one build at a time")
        return 1
    fh.seek(0)
    fh.truncate()
    fh.write(f"pid {os.getpid()} project {cfg['project']} tag {tag}\n")
    fh.flush()
    cmd = [e, "build", "--label", f"project={cfg['project']}", "--label", f"purpose={purpose}",
           "--label", f"release={release}", "-t", tag, *extra, context]
    print("build\t" + " ".join(cmd))
    r = subprocess.run(cmd)
    ledger(root, "image-build", tag=tag, release=release, rc=r.returncode)
    fcntl.flock(fh, fcntl.LOCK_UN)
    fh.close()
    if r.returncode == 0:
        print("next\tbash scripts/containers.sh retain --apply   (keep the current and the previous tag)")
    return r.returncode


def door(cfg: Config, args: list[str]) -> int:
    """Pass a command to the engine, refusing a mutating one on a product host unless the deploy door sent it."""
    e = engine(cfg)
    if not e:
        print(f"refused: {cfg['containers']['engine']} is not installed")
        return 1
    verb = args[0] if args else ""
    sub = args[1] if len(args) > 1 else ""
    mutating = verb in MUTATING and not (verb in ("image", "container", "volume", "pod", "network", "system")
                                         and sub in READ_ONLY_SUB)
    prod, why = is_product_host(cfg)
    if prod and mutating and os.environ.get("KIT_OPERATOR_DEPLOY") != "1":
        print(f"refused: '{e} {' '.join(args[:2])}' changes a product host ({why}). Only the operator's deploy "
              f"door creates, removes, untags or prunes here.")
        return 1
    return subprocess.run([e, *args]).returncode

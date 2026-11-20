#!/usr/bin/env python3
"""deploy — the door for a project that ships images: one builder, labelled, shipped, verified, two tags kept.

project.yaml:
  deploy:
    images:                       # what to build; or `build:` — the project's own build command
      - {name: localhost/app-web, context: ., file: Containerfile, purpose: product}
    build: ""                     # runs under the lock with RELEASE in the environment; replaces `images`
    ship: ""                      # per image: {image} {tag} {ref}; empty = nothing to ship
    hook: ""                      # the project's own deploy + verify; RELEASE and PREVIOUS in the environment
    rollback: ""                  # how to return to PREVIOUS; printed on any failure, run with --rollback

Order: refuse on a product host → the storage driver for this filesystem → the disk floor → the one-builder lock →
build (labels project/purpose/release) → ship → hook → keep the newest `containers.keep_tags` tags → clear the
project's dangling build leftovers. Any failure stops there, leaves the previous release running, and prints the
rollback. `--dry-run` prints the plan and changes nothing.
"""
from __future__ import annotations

import fcntl
import json
import os
import shlex
import shutil
import subprocess
import time
from pathlib import Path

from . import containers as ct
from .config import Config, disk_gate, is_product_host, ledger

DEFAULT_GRAPHROOT = "~/.local/share/containers/storage"


def fs_type(path: str) -> str:
    fake = os.environ.get("KIT_FAKE_FS")
    if fake:
        return fake
    p = Path(os.path.expanduser(path))
    while not p.exists() and p != p.parent:
        p = p.parent
    r = subprocess.run(["stat", "-f", "-c", "%T", str(p)], text=True, capture_output=True)
    return r.stdout.strip() or "unknown"


def storage_choice(engine: str) -> tuple[list[str], str]:
    """Engine flags that make podman use the driver this filesystem supports, and a sentence saying why."""
    if os.path.basename(engine) != "podman":
        return [], f"storage: {engine} manages its own driver"
    info = subprocess.run([engine, "info", "--format", "{{.Store.GraphDriverName}} {{.Store.GraphRoot}}"],
                          text=True, capture_output=True)
    parts = info.stdout.split()
    current = parts[0] if info.returncode == 0 and parts else ""
    root = parts[1] if len(parts) > 1 else os.path.expanduser(DEFAULT_GRAPHROOT)
    fs = fs_type(root)
    want = "btrfs" if fs == "btrfs" else "overlay"
    if current == want:
        return [], f"storage: {fs} filesystem at {root} → driver {want} (podman already uses it)"
    why = f"podman reported '{current}'" if current else "podman info failed"
    return ["--storage-driver", want], (f"storage: {fs} filesystem at {root} → driver {want} ({why}; passing "
                                        f"--storage-driver {want}. Make it permanent: driver = \"{want}\" in "
                                        f"~/.config/containers/storage.conf)")


def _tags(engine_cmd, project, name) -> list[tuple[float, str]]:
    out = subprocess.run([*engine_cmd, "images", "--format", "json"], text=True, capture_output=True)
    try:
        imgs = json.loads(out.stdout or "[]")
    except ValueError:
        imgs = []
    res = []
    for img in imgs:
        if (img.get("Labels") or {}).get("project") != project:
            continue
        for t in ct._tags(img):
            if t.rsplit(":", 1)[0] == name:
                res.append((ct._created(img), t))
    return sorted(res, reverse=True)


def _sh(cmd: str, env: dict) -> int:
    print(f"run\t{cmd}")
    return subprocess.run(cmd, shell=True, env={**os.environ, **env}).returncode


def run(cfg: Config, root, release: str, dry_run: bool, rollback: bool) -> int:
    spec = cfg.get("deploy") or {}
    project = cfg["project"]
    eng = ct.engine(cfg)
    if not spec:
        print("refused: project.yaml declares no deploy: section")
        return 2
    prod, why = is_product_host(cfg)
    if prod:
        print(f"refused: this machine is a product host ({why}) — deploy runs from a developer machine")
        return 1
    if not eng:
        print(f"refused: {cfg['containers']['engine']} is not installed")
        return 1
    flags, sentence = storage_choice(eng)
    print(sentence)
    E = [eng, *flags]
    images = spec.get("images") or []
    previous = {i["name"]: (_tags(E, project, i["name"]) or [(0, "")])[0][1] for i in images}
    prev_release = next((t.rsplit(":", 1)[1] for t in previous.values() if t), "")
    env = {"RELEASE": release, "PREVIOUS": prev_release, "KIT_STORAGE_FLAGS": " ".join(flags)}
    back = (spec.get("rollback") or "").replace("{previous}", prev_release or "previous")
    rollback_line = back or (f"the previous images ({', '.join(t for t in previous.values() if t) or 'none'}) are untouched; "
                             "point the hosts back at them")
    if rollback:
        if not back:
            print("refused: project.yaml declares no deploy.rollback command")
            return 2
        return _sh(back, env)
    ok, msg = disk_gate(cfg, root)
    if not ok and not dry_run:
        print(f"refused: the disk is below the floor — {msg}")
        return 1
    print(f"disk: {msg}" + ("" if ok else " — BELOW THE FLOOR: a real deploy refuses here"))
    plan = ([f"build {i['name']}:{release}" for i in images] if not spec.get("build") else [f"build: {spec['build']}"])
    plan += [f"ship: {spec['ship']}"] if spec.get("ship") else []
    plan += [f"hook: {spec['hook']}"] if spec.get("hook") else []
    plan += [f"keep the newest {cfg['containers']['keep_tags']} tags per image; clear dangling build leftovers"]
    if dry_run:
        print("plan (dry run — nothing changes):")
        for line in plan:
            print(f"  {line}")
        print(f"  on failure: {rollback_line}")
        return 0
    lp = ct.lock_path()
    fh = open(lp, "a+")
    try:
        fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        fh.seek(0)
        print(f"refused: another image build holds the lock ({fh.read().strip() or lp}) — one build at a time")
        return 1
    fh.seek(0)
    fh.truncate()
    fh.write(f"pid {os.getpid()} project {project} deploy {release}\n")
    fh.flush()

    def fail(step):
        print(f"FAILED at {step}. The previous release keeps running.\nrollback: {rollback_line}")
        ledger(root, "deploy", release=release, failed=step)
        return 1

    try:
        if spec.get("build"):
            if _sh(spec["build"], env) != 0:
                return fail("build")
        for i in images:
            ref = f"{i['name']}:{release}"
            cmd = [*E, "build", "--label", f"project={project}", "--label", f"purpose={i.get('purpose', 'product')}",
                   "--label", f"release={release}", "-t", ref]
            if i.get("file"):
                cmd += ["-f", i["file"]]
            cmd.append(i.get("context", "."))
            if not spec.get("build"):
                print("run\t" + " ".join(shlex.quote(c) for c in cmd))
                if subprocess.run(cmd, cwd=str(root)).returncode != 0:
                    return fail(f"build {ref}")
            if spec.get("ship"):
                line = spec["ship"].replace("{image}", i["name"]).replace("{tag}", release).replace("{ref}", ref)
                if _sh(line, env) != 0:
                    return fail(f"ship {ref}")
        if spec.get("hook") and _sh(spec["hook"], env) != 0:
            return fail("hook (deploy/verify)")
        keep = int(cfg["containers"]["keep_tags"])
        for i in images:
            for _, t in _tags(E, project, i["name"])[keep:]:
                subprocess.run([*E, "rmi", t], text=True, capture_output=True)
                print(f"removed\t{t}\t(past the newest {keep})")
        subprocess.run([*E, "image", "prune", "-f", "--filter", f"label=project={project}"], text=True, capture_output=True)
        print("cleared\tthe project's dangling build leftovers")
        ledger(root, "deploy", release=release, previous=prev_release)
        print(f"deployed\t{release}\t(previous {prev_release or 'none'})")
        return 0
    finally:
        fcntl.flock(fh, fcntl.LOCK_UN)
        fh.close()

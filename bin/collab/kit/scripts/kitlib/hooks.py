#!/usr/bin/env python3
"""hooks — seat the kit's hooks without taking anyone else's.

install   points core.hooksPath at .githooks. Before it moves, the folder that held the repository's hooks — a
          previous core.hooksPath, or .git/hooks when it holds a real hook (not a *.sample) — is recorded in
          `git config collab.hooks.previous`. Every kit hook runs that folder's hook of the same name after its
          own checks (scripts/hooks-chain.sh), as it does each folder listed in project.yaml hooks.chain.
uninstall puts core.hooksPath back as it was.
check     says what is seated and what runs after it.
"""
from __future__ import annotations

import os
from pathlib import Path

from .config import Config, common_dir, git

OURS = ".githooks"
KEY = "collab.hooks.previous"


def _has_real_hook(d: Path) -> bool:
    if not d.is_dir():
        return False
    return any(f.is_file() and os.access(f, os.X_OK) and not f.name.endswith(".sample") for f in d.iterdir())


def install(cfg: Config, root: Path) -> list[str]:
    out = []
    cur = git("config", "--get", "core.hooksPath", cwd=str(root)).stdout.strip()
    prev = git("config", "--get", KEY, cwd=str(root)).stdout.strip()
    common = common_dir(root)
    if cur and cur.rstrip("/") not in (OURS, os.path.join(str(root), OURS)):
        if not prev:
            git("config", KEY, cur, cwd=str(root))
            out.append(f"kept: the hooks in {cur} keep running after the kit's ({KEY})")
        else:
            out.append(f"kept: {KEY} = {prev} (already recorded)")
    elif not cur and _has_real_hook(common / "hooks") and not prev:
        git("config", KEY, str(common / "hooks"), cwd=str(root))
        names = sorted(f.name for f in (common / "hooks").iterdir()
                       if os.access(f, os.X_OK) and not f.name.endswith(".sample"))
        out.append(f"kept: {', '.join(names)} in {common / 'hooks'} keep running after the kit's ({KEY})")
    for d in cfg["hooks"].get("chain") or []:
        out.append(f"kept: the repository's own hooks in {d} run after the kit's (project.yaml hooks.chain)")
    hooks_dir = root / OURS
    for f in hooks_dir.iterdir() if hooks_dir.is_dir() else []:
        if f.is_file():
            f.chmod(f.stat().st_mode | 0o111)
    git("config", "core.hooksPath", OURS, cwd=str(root))
    out.append(f"seated: core.hooksPath = {OURS}")
    return out


def uninstall(root: Path) -> list[str]:
    prev = git("config", "--get", KEY, cwd=str(root)).stdout.strip()
    common = str(common_dir(root) / "hooks")
    if prev and prev != common:
        git("config", "core.hooksPath", prev, cwd=str(root))
        msg = f"restored: core.hooksPath = {prev} (as it was before the kit)"
    else:
        git("config", "--unset", "core.hooksPath", cwd=str(root))
        msg = "restored: core.hooksPath unset (git uses .git/hooks again)"
    git("config", "--unset", KEY, cwd=str(root))
    return [msg]


def chain_targets(cfg: Config, root: Path) -> list[str]:
    out = []
    prev = git("config", "--get", KEY, cwd=str(root)).stdout.strip()
    if prev:
        out.append(prev)
    out += list(cfg["hooks"].get("chain") or [])
    return out


def check(cfg: Config, root: Path) -> tuple[int, list[str]]:
    cur = git("config", "--get", "core.hooksPath", cwd=str(root)).stdout.strip()
    lines = [f"core.hooksPath = {cur or '(unset)'}"]
    for t in chain_targets(cfg, root):
        p = Path(t) if os.path.isabs(t) else root / t
        names = sorted(f.name for f in p.iterdir() if os.access(f, os.X_OK) and not f.name.endswith(".sample")) if p.is_dir() else []
        lines.append(f"then: {t} ({', '.join(names) or 'no hooks found'})")
    return (0 if cur == OURS else 1), lines

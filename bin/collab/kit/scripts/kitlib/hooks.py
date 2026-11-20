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
    """Seat .githooks for THIS checkout only.

    core.hooksPath in the shared config would change every other checkout of the repository — a worktree on
    another branch, or the main clone, where .githooks may not exist, so their hooks would silently stop. The kit
    therefore writes it to this worktree's own config (git's extensions.worktreeConfig), and leaves the shared
    setting as it was. A shared setting that already points at .githooks (an earlier kit) is kept.
    """
    out = []
    shared = git("config", "--local", "--get", "core.hooksPath", cwd=str(root)).stdout.strip()
    prev = git("config", "--get", KEY, cwd=str(root)).stdout.strip()
    common = common_dir(root)
    if shared.rstrip("/") == OURS:
        out.append(f"kept: the shared core.hooksPath already is {OURS}")
    else:
        if shared and not prev:
            prev = shared if os.path.isabs(shared) else str(main_tree_of(root) / shared)
            git("config", KEY, prev, cwd=str(root))
            out.append(f"kept: the hooks in {shared} keep running after the kit's ({KEY})")
        elif not shared and _has_real_hook(common / "hooks") and not prev:
            git("config", KEY, str(common / "hooks"), cwd=str(root))
            names = sorted(f.name for f in (common / "hooks").iterdir()
                           if os.access(f, os.X_OK) and not f.name.endswith(".sample"))
            out.append(f"kept: {', '.join(names)} in {common / 'hooks'} keep running after the kit's ({KEY})")
        elif prev:
            out.append(f"kept: {KEY} = {prev} (already recorded)")
        git("config", "extensions.worktreeConfig", "true", cwd=str(root))
        git("config", "--worktree", "core.hooksPath", OURS, cwd=str(root))
        out.append(f"seated: core.hooksPath = {OURS} for this checkout only (other checkouts keep "
                   f"{shared or 'their own hooks'})")
    for d in cfg["hooks"].get("chain") or []:
        out.append(f"kept: the repository's own hooks in {d} run after the kit's (project.yaml hooks.chain)")
    hooks_dir = root / OURS
    for f in hooks_dir.iterdir() if hooks_dir.is_dir() else []:
        if f.is_file():
            f.chmod(f.stat().st_mode | 0o111)
    return out


def seat_worktree(root: Path, wt: Path) -> bool:
    """A new worktree of a repository whose hooks the kit seated gets them too."""
    if not (wt / OURS).is_dir():
        return False
    if git("config", "--local", "--get", "core.hooksPath", cwd=str(root)).stdout.strip().rstrip("/") == OURS:
        return True
    if git("config", "--get", "extensions.worktreeConfig", cwd=str(root)).stdout.strip() != "true":
        return False
    git("config", "--worktree", "core.hooksPath", OURS, cwd=str(wt))
    return True


def main_tree_of(root: Path) -> Path:
    c = common_dir(root)
    return c.parent if c.name == ".git" else c


def uninstall(root: Path) -> list[str]:
    prev = git("config", "--get", KEY, cwd=str(root)).stdout.strip()
    common = str(common_dir(root) / "hooks")
    git("config", "--worktree", "--unset", "core.hooksPath", cwd=str(root))
    shared = git("config", "--local", "--get", "core.hooksPath", cwd=str(root)).stdout.strip()
    if shared.rstrip("/") == OURS:  # an earlier kit wrote the shared setting
        if prev and prev != common:
            git("config", "core.hooksPath", prev, cwd=str(root))
        else:
            git("config", "--unset", "core.hooksPath", cwd=str(root))
    shared = git("config", "--get", "core.hooksPath", cwd=str(root)).stdout.strip()
    git("config", "--unset", KEY, cwd=str(root))
    return [f"restored: core.hooksPath = {shared or '(unset — git uses .git/hooks again)'}"]


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

"""Where the engine's roots live — the ONE Python reader of the home law.

`bin/hoard-lib.sh` owns this contract in bash; this module is its Python twin
and resolves the same answer: **env → the machine's recorded choice → the one
documented default** (Rule 07). No path is hardcoded twice, and the engine never
writes inside the code tree.

    home     the operator's home          ($YMIR_HOME → recorded → ~/Documents/ymirhome)
    hoard    the hoard within it          ($YMIR_HOARD → <home>/hodd)
    state    runtime state                ($YMIR_STATE_DIR → <home>/state)
    data     this machine's records       ($YMIR_DATA_DIR → <hoard>/data)
    config   the operator's settings      ($YMIR_SETTINGS_DIR → <home>/config)
    root     the code tree (the package's own repo), for .yggdrasil worktrees

The `BROKK_*_OVERRIDE` variables win over the `YMIR_*` ones because the bash
doors have always resolved them that way; a seat that must not touch the
primary's state sets them, and the engine honours the same precedence.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping

DEFAULT_HOME = "~/Documents/ymirhome"


@dataclass(frozen=True)
class Roots:
    home: Path
    hoard: Path
    state: Path
    data: Path
    config: Path
    root: Path
    wt_root: Path


def _config_dir(env: Mapping[str, str]) -> Path:
    explicit = env.get("YMIR_CONFIG_DIR")
    if explicit:
        return Path(explicit).expanduser()
    xdg = env.get("XDG_CONFIG_HOME") or "~/.config"
    return Path(xdg).expanduser() / "ymir"


def recorded_home(env: Mapping[str, str]) -> str:
    """The home recorded at installation, or empty. Machine state, not user data."""
    pointer = _config_dir(env) / "home"
    try:
        return pointer.read_text(encoding="utf-8").splitlines()[0].strip()
    except (OSError, IndexError):
        return ""


def ymir_home(env: Mapping[str, str]) -> Path:
    explicit = env.get("YMIR_HOME")
    if explicit:
        return Path(explicit).expanduser()
    return Path(recorded_home(env) or DEFAULT_HOME).expanduser()


def repo_root(env: Mapping[str, str], *, module_file: str = __file__) -> Path:
    """The CODE tree — where `src/` and the sibling `bin/` doors live.

    `YMIR_ENGINE_ROOT` is set by `bin/ymir-engine.sh`, so the engine always knows
    the tree it was launched from. `BROKK_ROOT_OVERRIDE`/`BROKK_HOME` are the
    fallbacks for a direct `python3 -m ymir_runtime` call. This is deliberately
    NOT the same notion as the worktree root: a caller may point `BROKK_HOME` at
    a project (the shell door does exactly that) without moving the code.
    """
    for key in ("YMIR_ENGINE_ROOT", "BROKK_ROOT_OVERRIDE", "BROKK_HOME"):
        value = env.get(key)
        if value:
            return Path(value).expanduser()
    return Path(module_file).resolve().parents[2]


def brokk_home(env: Mapping[str, str], *, module_file: str = __file__) -> Path:
    """The Brokk home whose `.yggdrasil/` holds this machine's task worktrees."""
    for key in ("BROKK_HOME", "BROKK_ROOT_OVERRIDE"):
        value = env.get(key)
        if value:
            return Path(value).expanduser()
    return repo_root(env, module_file=module_file)


def _first(env: Mapping[str, str], *keys: str) -> str:
    for key in keys:
        value = env.get(key)
        if value:
            return value
    return ""


def resolve(env: Mapping[str, str] | None = None) -> Roots:
    """Resolve every root the engine may touch, once, from the home law."""
    environ = dict(os.environ) if env is None else dict(env)
    home = ymir_home(environ)
    hoard = Path(_first(environ, "YMIR_HOARD") or home / "hodd").expanduser()
    state = Path(
        _first(environ, "BROKK_STATE_OVERRIDE", "YMIR_STATE_DIR") or home / "state"
    ).expanduser()
    data = Path(
        _first(environ, "BROKK_DATA_OVERRIDE", "YMIR_DATA_DIR") or hoard / "data"
    ).expanduser()
    config = Path(
        _first(environ, "BROKK_CONFIG_OVERRIDE", "YMIR_SETTINGS_DIR", "BROKK_CONFIG")
        or home / "config"
    ).expanduser()
    root = repo_root(environ)
    wt_root = Path(
        _first(environ, "BROKK_WT_ROOT") or brokk_home(environ) / ".yggdrasil"
    ).expanduser()
    return Roots(
        home=home,
        hoard=hoard,
        state=state,
        data=data,
        config=config,
        root=root,
        wt_root=wt_root,
    )

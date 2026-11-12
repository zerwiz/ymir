"""Where the engine's roots live — the ONE Python reader of the home law.

`bin/vault/hoard-lib.sh` owns this contract in bash; this module is its Python twin
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

    `YMIR_ENGINE_ROOT` is set by `bin/engine/ymir-engine.sh`, so the engine always knows
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


def runtime_env(env: Mapping[str, str] | None = None) -> dict[str, str]:
    """`<home>/config/runtime.env` as a mapping — the pin's own record (RULES/02 §7).

    The file is the one the shell ward reads (`runtime-pinned-guard.sh`); `$HOME` and a
    leading `~` are expanded, nothing else. A missing file is an empty mapping.
    """
    environ = dict(os.environ) if env is None else dict(env)
    conf = resolve(environ).config / "runtime.env"
    values: dict[str, str] = {}
    try:
        text = conf.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return values
    home = environ.get("HOME") or os.path.expanduser("~")
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("export "):
            stripped = stripped[len("export "):].strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        value = value.strip().strip('"').strip("'")
        value = value.replace("${HOME}", home).replace("$HOME", home)
        if value.startswith("~/"):
            value = home + value[1:]
        values[key.strip()] = value
    return values


def runtime_pin_dir(env: Mapping[str, str] | None = None) -> Path:
    """The pinned runtime checkout (RULES/02 §7) — `runtime.env`'s YMIR_RUNTIME_DIR.

    A unit or a harness that executes from a WORKING tree is a machine running whatever
    branch the last agent left checked out; the pin is the ONE checkout that may
    supervise (plan 257 H6). This reads the SAME file the shell ward reads —
    `runtime-pinned-guard.sh` and `bin/pi/arm-pin-lib.sh` — never a second path.
    Empty when no pin is configured.
    """
    environ = dict(os.environ) if env is None else dict(env)
    explicit = environ.get("YMIR_RUNTIME_DIR")
    if explicit:
        return Path(explicit).expanduser()
    value = runtime_env(environ).get("YMIR_RUNTIME_DIR", "")
    return Path(value).expanduser() if value else Path("")


def runtime_pin_branch(env: Mapping[str, str] | None = None) -> str:
    """The branch the pin follows — YMIR_RUNTIME_BRANCH, the ward's default `main`."""
    environ = dict(os.environ) if env is None else dict(env)
    return environ.get("YMIR_RUNTIME_BRANCH") or runtime_env(environ).get("YMIR_RUNTIME_BRANCH") or "main"

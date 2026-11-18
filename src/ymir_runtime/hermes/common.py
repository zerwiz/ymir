"""What every Hermes verb shares: where things are, one subprocess helper, one error type.

Rules this module enforces for the package (plan 318 §2):

* every path resolves from the environment or from `ymir_runtime.paths` — never a literal home;
* every subprocess has a timeout, keeps its stderr, and a missing binary is a result, not a crash;
* a failure is a `HermesError` with a sentence that names the fix — never a success line.
"""

from __future__ import annotations

import datetime as _dt
import difflib
import json
import os
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping, Sequence

from .. import paths as paths_mod
from ..errors import EngineError

# The descriptor's own word for the Hermes we were measured against; `doctor` compares it.
DESCRIPTOR = (".agents", "harnesses", "hermes.yaml")


class HermesError(EngineError):
    """A Hermes verb failed. `remedy` is the command or step that would fix it."""

    def __init__(self, reason: str, remedy: str = "") -> None:
        super().__init__(reason)
        self.reason = reason
        self.remedy = remedy

    def __str__(self) -> str:
        return f"{self.reason} (remedy: {self.remedy})" if self.remedy else self.reason


@dataclass(frozen=True)
class Result:
    rc: int
    out: str
    err: str

    @property
    def ok(self) -> bool:
        return self.rc == 0


def run(
    argv: Sequence[str],
    *,
    timeout: float,
    env: Mapping[str, str] | None = None,
    cwd: str | None = None,
    input_text: str | None = None,
) -> Result:
    """Run argv with a timeout that is never optional. Never raises on failure.

    124 is a timeout (the coreutils convention), 127 a missing binary; both carry the reason in
    `err`, so a caller reports the real cause instead of a guess.
    """
    try:
        p = subprocess.run(
            list(argv),
            cwd=cwd,
            env=dict(env) if env is not None else None,
            capture_output=True,
            text=True,
            timeout=timeout,
            input=input_text,
        )
    except FileNotFoundError:
        return Result(127, "", f"not found: {argv[0]}")
    except subprocess.TimeoutExpired as exc:
        out = exc.stdout if isinstance(exc.stdout, str) else (exc.stdout or b"").decode(errors="replace")
        return Result(124, out, f"timed out after {timeout:g}s: {' '.join(argv[:4])}")
    except OSError as exc:
        return Result(126, "", f"could not run {argv[0]}: {exc}")
    return Result(p.returncode, p.stdout or "", p.stderr or "")


def environ(env: Mapping[str, str] | None) -> dict[str, str]:
    return dict(os.environ) if env is None else dict(env)


def user_home(env: Mapping[str, str]) -> Path:
    return Path(env.get("HOME") or os.path.expanduser("~"))


def hermes_home(env: Mapping[str, str]) -> Path:
    return Path(env["HERMES_HOME"]) if env.get("HERMES_HOME") else user_home(env) / ".hermes"


def hermes_config(env: Mapping[str, str]) -> Path:
    return Path(env["HERMES_CONFIG"]) if env.get("HERMES_CONFIG") else hermes_home(env) / "config.yaml"


def owned_ledger(env: Mapping[str, str]) -> Path:
    """The side ledger of what Ymir seated in Hermes (plan 317 §4.2, the reversible choice)."""
    return Path(env["YMIR_HERMES_LEDGER"]) if env.get("YMIR_HERMES_LEDGER") else hermes_home(env) / ".ymir-owned.json"


def hermes_scripts(env: Mapping[str, str]) -> Path:
    return hermes_home(env) / "scripts"


def packet_list(env: Mapping[str, str]) -> Path:
    """The ONE packet list every harness copies (`mcp-config-seat.py` renders it)."""
    if env.get("YMIR_MCP_ADAPTER"):
        return Path(env["YMIR_MCP_ADAPTER"])
    return user_home(env) / ".pi" / "agent" / "mcp-adapter.json"


def state_dir(env: Mapping[str, str]) -> Path:
    """Machine-local state for the Hermes verbs — the same place the session hook always used."""
    if env.get("YMIR_HERMES_STATE"):
        return Path(env["YMIR_HERMES_STATE"])
    base = Path(env["XDG_STATE_HOME"]) if env.get("XDG_STATE_HOME") else user_home(env) / ".local" / "state"
    return base / "ymir" / "hermes"


def pin_link(env: Mapping[str, str]) -> Path:
    """The pin as a LINK path (`~/ymir-runtime`), never its resolved release.

    A seated path names the link, so an update that flips the link moves every harness with it.
    """
    return paths_mod.runtime_pin_dir(env)


def tree_root() -> Path:
    """The tree this module was loaded from (the pin, or a checkout under test)."""
    return Path(__file__).resolve().parents[3]


def hermes_bin(env: Mapping[str, str]) -> str:
    return env.get("HERMES_BIN") or shutil.which("hermes", path=env.get("PATH")) or "hermes"


def herdr_bin(env: Mapping[str, str]) -> str:
    return env.get("YMIR_HERDR") or shutil.which("herdr", path=env.get("PATH")) or "herdr"


def stamp() -> str:
    return _dt.datetime.now(_dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def now_iso() -> str:
    return _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def backup(path: Path) -> Path | None:
    """A dated copy beside the file, taken before any write. None when there was nothing to keep."""
    if not path.exists():
        return None
    dst = path.with_name(f"{path.name}.bak-{stamp()}")
    shutil.copy2(path, dst)
    return dst


def write_atomic(path: Path, text: str, mode: int | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".ymir.tmp")
    tmp.write_text(text, encoding="utf-8")
    if mode is not None:
        os.chmod(tmp, mode)
    os.replace(tmp, path)


def unified(path: Path, before: str, after: str) -> str:
    return "".join(difflib.unified_diff(
        before.splitlines(keepends=True), after.splitlines(keepends=True),
        fromfile=f"{path} (now)", tofile=f"{path} (after)"))


def load_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return default
    except (OSError, ValueError) as exc:
        raise HermesError(f"{path} does not parse: {exc}", f"repair or move {path} aside") from exc


def row(*cells: str) -> str:
    return "  " + ",".join('"' + str(c).replace('"', "'") + '"' for c in cells)

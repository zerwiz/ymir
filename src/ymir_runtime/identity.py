"""Hœnir's own name — the helm's identity, resolved once and WRITTEN into the lease.

Plan 254 appended two questions the record could not answer (B1b, B1c) and plan 257
H8 added a third, and all three are the same sentence: *who holds this helm, what is
it FOR, which machine and fleet does it stand on, and which pinned code does it run?*

Until now the lease carried `pid starttime gen mode role session heartbeat state` —
a process, a generation, a shape, a duty set and a shelf. It said nothing about whose
hand it was, and the answer to "which machine" could only be guessed from a path.

So every field here is resolved ONCE, at take, and written into `.arm.lease`:

    seat=      the name this seat answers as (`.ymir-seat` `primary=`), else `unnamed`
    charter=   what the house's main agent is FOR — the Allfather's own definition
    host=      `.ymir-seat` `host=`, else the machine's own name
    machine=   the seat key in the fleet registry for this host
    fleetrole= `bin/skuld/role.sh resolve` — heart · forge · dev · hand
    fleet=     the fleet this seat belongs to, from the seat registry
    pin=       the PINNED runtime's sha at YMIR_RUNTIME_DIR
    pin_behind= `git rev-list --count HEAD..origin/main` for that pin

The laws this module keeps:

* **Rule 44 — a name is never invented.** A seat with no sealed name renders `unnamed`
  and still holds the helm. The name is rendered, not guessed.
* **The record answers the question, never an inference.** These values are written at
  take, so a reader never has to re-derive them (and a lease copied to another machine
  reports that machine's host, because it is written there, never inherited).
* **A holder that cannot resolve its host or its role does not HOLD.** It stands
  `identity=readonly` and names the missing field; the arm still beats (a dead arm
  tells nobody anything), but no errand may be seated under it.
"""

from __future__ import annotations

import os
import re
import socket
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping

from . import paths as paths_mod
from . import proc

# The Allfather's own definition of the helm's work (plan 254 B1b, quoted verbatim):
# *planning · mail · the thing over all they working with* — and the arm sends the
# Eindri out. A lease field can carry no spaces, so the charter travels comma-joined
# and is rendered with middots by the reader.
CHARTER = "planning,mail,the-work-in-hand,dispatch-on"
CHARTER_TEXT = "planning · mail · the work in hand · dispatch on"
SEAT_FILE_NAME = ".ymir-seat"

# `unnamed` is a RENDERED word, never an invented name (Rule 44).
UNNAMED = "unnamed"
DEFAULT_PIN = "~/ymir-runtime"

# The pin's age costs two git calls; a poll loop must not pay them every cycle.
IDENTITY_TTL_SECONDS = 300
_CACHE: dict[tuple[str, ...], tuple[float, "Helm"]] = {}


@dataclass(frozen=True)
class Helm:
    """The helm, as the record will carry it."""

    seat: str = UNNAMED
    charter: str = CHARTER
    host: str = ""
    machine: str = ""
    fleet: str = ""
    fleetrole: str = ""
    pin: str = "none"
    pin_behind: str = "none"
    missing: tuple[str, ...] = ()

    @property
    def identity(self) -> str:
        """`held` when the helm may seat an errand, `readonly` when a field is missing."""
        return "readonly" if self.missing else "held"

    @property
    def charter_text(self) -> str:
        return render_charter(self.charter)

    def lease_tokens(self) -> str:
        """The lease's own spelling: whitespace-free values, one token per field."""
        return " ".join(
            [
                f"seat={self.seat}",
                f"charter={self.charter}",
                f"host={self.host or 'none'}",
                f"machine={self.machine or 'none'}",
                f"fleetrole={self.fleetrole or 'none'}",
                f"fleet={self.fleet or 'none'}",
                f"pin={self.pin}",
                f"pin_behind={self.pin_behind}",
                f"identity={self.identity}",
                f"missing={','.join(self.missing) or 'none'}",
            ]
        )

    def readonly_reason(self) -> str:
        """One line naming what the holder could not resolve — never a bare refusal."""
        return ", ".join(self.missing)


def render_charter(charter: str) -> str:
    """`planning,mail,the-work-in-hand,dispatch-on` → `planning · mail · the work in hand · dispatch on`."""
    parts = [part.replace("-", " ").strip() for part in (charter or CHARTER).split(",")]
    return " · ".join(part for part in parts if part)


def seat_file(env: Mapping[str, str]) -> Path:
    """The seat record's path: `$PI_EXT_HOME/.ymir-seat`, else the harness's own home."""
    explicit = env.get("YMIR_SEAT_FILE")
    if explicit:
        return Path(explicit).expanduser()
    ext = env.get("PI_EXT_HOME") or "~/.pi/agent/extensions"
    return Path(ext).expanduser() / SEAT_FILE_NAME


def read_seat(env: Mapping[str, str]) -> dict[str, str]:
    """The seat record as a mapping. An absent file is an EMPTY mapping, never a guess."""
    try:
        text = seat_file(env).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}
    values: dict[str, str] = {}
    for line in text.splitlines():
        key, separator, value = line.partition("=")
        if separator:
            values[key.strip()] = value.strip()
    return values


def _token(value: str) -> str:
    """A lease-safe token: lowercase, no whitespace, no punctuation a parser could eat."""
    cleaned = re.sub(r"[^a-z0-9._-]+", "-", (value or "").strip().lower())
    return cleaned.strip("-")


def _registry(env: Mapping[str, str], roots: paths_mod.Roots) -> tuple[str, str, str]:
    """(fleet, seat key, host) from the seat registry — parsed, never guessed.

    The registry is `hodd/identity/seats.yaml`: a top-level `fleet:` block carrying
    `name:`, and a `seats:` map whose entries carry `machine: { host: }`. A parser
    that asked for yaml would make the engine depend on an interpreter's extras, so
    this reads the two shapes it needs and answers empty when they are not there.
    """
    candidates = [
        env.get("YMIR_SEATS_FILE", ""),
        str(roots.hoard / "identity" / "seats.yaml"),
        str(roots.home / "hodd" / "identity" / "seats.yaml"),
    ]
    text = ""
    for candidate in candidates:
        if not candidate:
            continue
        try:
            text = Path(candidate).expanduser().read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        break
    if not text:
        return "", "", ""

    wanted = _hostname(env).lower()
    fleet = ""
    seat_key = ""
    seat_host = ""
    seat_region = False
    in_fleet = False
    current = ""
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())
        stripped = line.strip()
        if indent == 0:
            in_fleet = stripped.startswith("fleet:")
            seat_region = stripped.startswith("seats:")
            current = ""
            continue
        if in_fleet and indent == 2 and stripped.startswith("name:"):
            fleet = stripped.partition(":")[2].strip().strip("'\"")
            continue
        if not seat_region:
            continue
        if indent == 2 and stripped.endswith(":"):
            current = stripped[:-1].strip()
            continue
        if indent >= 6 and current and stripped.startswith("host:"):
            value = stripped.partition(":")[2].strip().strip("'\"")
            if value.lower() == wanted and not seat_host:
                seat_key, seat_host = current, value
    return _token(fleet), seat_key, seat_host


def _hostname(env: Mapping[str, str]) -> str:
    """This machine's own name — the seat record wins, the OS answers next."""
    from_seat = (read_seat(env).get("host") or "").strip()
    if from_seat:
        return from_seat
    try:
        name = socket.gethostname()
    except OSError:  # pragma: no cover - not a normal host
        return ""
    return (name.split(".")[0] or "").lower()


def _fleetrole(roots: paths_mod.Roots, env: Mapping[str, str], runner: proc.Runner) -> str:
    """`bin/skuld/role.sh resolve` — the role the fleet registry gives this host."""
    if env.get("YMIR_ROLE"):
        return _token((env.get("YMIR_ROLE") or "").split(",")[0])
    door = roots.root / "bin" / "skuld" / "role.sh"
    if not os.access(door, os.X_OK):
        return ""
    answer = runner(["bash", str(door), "resolve"], env=dict(env))
    if not proc.ok(answer):
        return ""
    return _token((answer.stdout or "").strip().split(",")[0])


def _pin_dir(env: Mapping[str, str], roots: paths_mod.Roots) -> Path:
    """The pinned runtime: `$YMIR_RUNTIME_DIR`, else the home's runtime.env, else the default."""
    explicit = (env.get("YMIR_RUNTIME_DIR") or "").strip()
    if explicit:
        return Path(explicit).expanduser()
    conf = roots.config / "runtime.env"
    try:
        text = conf.read_text(encoding="utf-8", errors="replace")
    except OSError:
        text = ""
    for line in text.splitlines():
        match = re.match(r"^\s*YMIR_RUNTIME_DIR\s*=\s*(.+?)\s*$", line)
        if match:
            # the config writes `$HOME/ymir-runtime`; an unexpanded variable in a config
            # is resolved ONCE, here, exactly as bin/fleet/fleet-ensure.sh resolves it
            value = match.group(1).strip().strip("'\"").replace("$HOME", str(Path.home()))
            return Path(value).expanduser()
    return Path(DEFAULT_PIN).expanduser()


def _git(args: list[str], *, cwd: Path, env: Mapping[str, str], runner: proc.Runner) -> str:
    """Ask git about the PIN, never about the caller's repository.

    A hook exports GIT_DIR (and friends); with them set, `git -C <other tree>` answers
    about the PUSHING tree instead of the one it was pointed at (measured 2026-11-02
    in the pinned-runtime ward). The same subtraction is made here, once.
    """
    child = {key: value for key, value in env.items() if not key.startswith("GIT_")}
    answer = runner(["git", *args], cwd=str(cwd), env=child)
    return (answer.stdout or "").strip() if proc.ok(answer) else ""


def pin_age(env: Mapping[str, str], roots: paths_mod.Roots, runner: proc.Runner) -> tuple[str, str]:
    """(sha, commits behind origin/main) for the pinned checkout — `none` when there is none."""
    pin = _pin_dir(env, roots)
    if not (pin / ".git").exists():
        return "none", "none"
    sha = _git(["rev-parse", "--short", "HEAD"], cwd=pin, env=env, runner=runner)
    if not sha:
        return "none", "none"
    behind = _git(["rev-list", "--count", "HEAD..origin/main"], cwd=pin, env=env, runner=runner)
    return sha, behind if behind.isdigit() else "unknown"


def resolve(
    env: Mapping[str, str] | None = None,
    *,
    runner: proc.Runner = proc.run,
    ttl: float = IDENTITY_TTL_SECONDS,
    now: float | None = None,
) -> Helm:
    """Resolve the helm's identity for THIS machine, once per ttl.

    The pin's age costs two git calls and the role costs one subprocess, so a poll
    loop must not pay them on every beat. The cache is keyed by the roots the answer
    was resolved from — never by the answer — so two seats sharing a process can
    never read each other's identity.
    """
    environ = dict(os.environ) if env is None else dict(env)
    roots = paths_mod.resolve(environ)
    key = (
        str(roots.home),
        str(roots.root),
        str(roots.state),
        environ.get("YMIR_RUNTIME_DIR", ""),
        environ.get("PI_EXT_HOME", ""),
        environ.get("YMIR_SEAT_FILE", ""),
    )
    moment = time.time() if now is None else now
    if ttl > 0:
        cached = _CACHE.get(key)
        if cached and moment - cached[0] < ttl:
            return cached[1]

    seat_record = read_seat(environ)
    fleet, seat_key, registry_host = _registry(environ, roots)

    seat = (seat_record.get("primary") or "").strip() or UNNAMED
    host = _hostname(environ)
    fleetrole = _fleetrole(roots, environ, runner)
    sha, behind = pin_age(environ, roots, runner)

    missing: list[str] = []
    if not host:
        missing.append("host")
    if not fleetrole:
        missing.append("fleetrole")

    helm = Helm(
        seat=seat,
        host=host,
        machine=seat_key or registry_host or host,
        fleet=fleet,
        fleetrole=fleetrole,
        pin=sha,
        pin_behind=behind,
        missing=tuple(missing),
    )
    if ttl > 0:
        _CACHE[key] = (moment, helm)
    return helm


def reset_cache() -> None:
    """Forget every resolved identity — a test's clean room, and an explicit re-read."""
    _CACHE.clear()

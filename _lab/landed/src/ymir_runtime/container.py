"""Utgard — the sandbox decision, made honestly and once.

Utgard is the EXCEPTION: a container for untrusted code or an outsized task.
herdr (the worktree, no container) is the ordinary road. This module reads the
brief's own declaration (`Isolation: herdr|utgard — <why>`) and answers whether
the engine may own the seat.

Phase 1 is honest about its own reach: the engine can own a **herdr** seat. It
canNOT yet launch the Utgard sandbox — that road still belongs to
`bin/agents/einherjar-spawn.sh` until the container module's own phase. So a declared
or forced utgard produces an `EngineRefusal`, never a silent downgrade, and the
adapter keeps the old road. A declared utgard with no engine or no image is the
same loud refusal the shell door makes.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Callable, Mapping

from . import proc

UTGARD_IMAGE = "utgard-runner:latest"

_DECLARATION = re.compile(
    r"^[ \t]*#?[ \t]*Isolation:[ \t]+(?P<word>[A-Za-z]+)(?P<rest>.*)$",
    re.MULTILINE,
)


@dataclass(frozen=True)
class IsolationPlan:
    declared: str
    effective: str
    reason: str
    engine: str
    image_present: bool
    supported: bool
    refusal: str = ""

    @property
    def sandboxed(self) -> bool:
        return self.effective == "on"


def declared_from_brief(text: str) -> tuple[str, str]:
    """Parse `Isolation: herdr|utgard — <why>` from a brief, else the default."""
    match = _DECLARATION.search(text or "")
    if not match:
        return "herdr", "no Isolation: line in the brief — herdr is the ordinary road"
    word = match.group("word").lower()
    rest = match.group("rest").strip().lstrip("—–-").strip()
    if word not in ("herdr", "utgard"):
        return "herdr", f"unrecognized isolation declaration '{word}' — herdr is the ordinary road"
    return word, (rest or "declared in the brief")


def detect_engine(*, env: Mapping[str, str] | None = None, probe: Callable[[str], str] = proc.which) -> str:
    """The container engine this host has, or empty. Never assumes one binary."""
    environ = env or {}
    for name in ("YMIR_CONTAINER_ENGINE", "CONTAINER_ENGINE"):
        if environ.get(name):
            return environ[name]
    for name in ("docker", "podman"):
        if probe(name):
            return name
    return ""


def image_present(engine: str, image: str = UTGARD_IMAGE, *, runner: proc.Runner = proc.run) -> bool:
    if not engine:
        return False
    result = runner([engine, "image", "inspect", image])
    return proc.ok(result)


def plan(
    *,
    declared: str = "herdr",
    reason: str = "",
    override: str = "",
    env: Mapping[str, str] | None = None,
    runner: proc.Runner = proc.run,
    probe: Callable[[str], str] = proc.which,
    image: str = UTGARD_IMAGE,
) -> IsolationPlan:
    """Decide the effective isolation, or name the refusal plainly."""
    declared = (declared or "herdr").lower()
    reason = reason or "declared in the brief"
    engine = detect_engine(env=env, probe=probe)
    present = image_present(engine, image, runner=runner) if engine else False

    if override == "off":
        if declared == "utgard":
            return IsolationPlan(
                declared=declared,
                effective="off",
                reason=reason,
                engine=engine,
                image_present=present,
                supported=False,
                refusal=(
                    "brief declares Isolation: utgard but --isolation off forces the worktree — "
                    "a declared isolation is never silently downgraded; edit the brief's declaration "
                    "(Isolation: herdr — <why>) or relaunch without --isolation off"
                ),
            )
        return IsolationPlan(declared, "off", reason, engine, present, True)

    if declared == "utgard" and override != "on":
        if not engine:
            return IsolationPlan(
                declared=declared,
                effective="off",
                reason=reason,
                engine=engine,
                image_present=False,
                supported=False,
                refusal=(
                    "isolation=utgard requires a container engine, but neither docker nor podman is "
                    "reachable — REFUSED, not downgraded. Remedy: start docker/podman, or edit the "
                    "brief to 'Isolation: herdr — <why>'."
                ),
            )
        if not present:
            return IsolationPlan(
                declared=declared,
                effective="off",
                reason=reason,
                engine=engine,
                image_present=False,
                supported=False,
                refusal=(
                    f"isolation=utgard requires the Utgard image '{image}', which is absent — "
                    "REFUSED, not downgraded. Remedy: build it (bin/forge/utgard.sh build) or edit the "
                    "brief to 'Isolation: herdr — <why>'."
                ),
            )

    if override == "on" or declared == "utgard":
        return IsolationPlan(
            declared="utgard",
            effective="on",
            reason=reason,
            engine=engine,
            image_present=present,
            supported=False,
            refusal=(
                "the engine does not launch the Utgard sandbox yet — Phase 1 seats herdr (the "
                "ordinary road) only; the sandbox road still belongs to bin/agents/einherjar-spawn.sh"
            ),
        )

    return IsolationPlan("herdr", "off", reason, engine, present, True)

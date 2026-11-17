"""Sýn's mind — the supervisor loop: measure → judge → act → prove → record.

The heart has eight observers and no supervisor (plan 004). An observer tests one
thing and reports it; it can say a port is closed and cannot decide what to do
about it. The Allfather's correction, 2026-11-17:

    "the supervisor must work for the intended outcome … and an agent must be
     involved in the loop."

So the loop has five steps, and the MIDDLE one is a hand, not a threshold:

    measure  one cheap pass, no judgement: memory, swap, load, restart counts,
             the registry's own audit, and one line per surface the registry
             names for THIS seat.
    judge    an agent reads the measurement and the runbook library, and answers
             with ONE verb from a runbook plus the reason. The model is resolved
             by `bin/model/agent-model.sh` and served through `bin/agents/syn-judge.sh`
             — never a hardcoded prompt with a hardcoded threshold.
    act      one verb only, and only while the arm is held (`bin/voice/rodd-arm.sh
             who`, plan 310): the arm is the authority, never this file.
    prove    the SAME measurement that reported the fault runs again; if the
             surface is not well, the act is recorded as FAILED, loudly.
    record   one line in the machine's `fixes.md` and one rune.

What this module refuses, on purpose:

  · a verb that is not in `VERBS` — the model may choose, the house names the choices;
  · a target that is not a surface THIS seat's registry names;
  · any act on a surface the registry marks `criticality: always` — that question is
    the Allfather's (plan 004 §5.1), and a fault that needs him is escalated in ONE
    message instead of retried;
  · acting with no arm held — refusal is exit 3, never a quiet attempt.

The module writes nothing into the code tree: `fixes.md` and the rune ledger live
in the home (Rule 04), and the registry is read, never written.
"""

from __future__ import annotations

import json
import os
import re
import socket
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Mapping, Sequence

from . import paths as paths_mod
from . import proc

VERSION = "1.0.0"

EXIT_OK = 0
EXIT_FAILED = 1
EXIT_USAGE = 2
EXIT_REFUSED = 3

# ── the vocabulary ────────────────────────────────────────────────────────────
# One verb per runbook page, named here so the judge chooses from the house's own
# words instead of inventing one. A verb's guard is the law, not the model's taste.
VERBS: dict[str, dict[str, str]] = {
    "none": {"does": "nothing — nothing this loop owns is faulted", "guard": "always"},
    "start-container": {"does": "docker start <container>", "guard": "the surface's criticality is wanted or dormant"},
    "restart-container": {"does": "docker restart <container>", "guard": "the surface's criticality is wanted or dormant"},
    "start-unit": {"does": "systemctl --user start <unit>", "guard": "the unit is named in this seat's registry"},
    "restart-unit": {"does": "systemctl --user restart <unit>", "guard": "the unit is named in this seat's registry"},
    "escalate": {"does": "say it once to the Allfather — no retry", "guard": "always"},
}

CRITICAL_ALWAYS = "always"


# ── the measurement ───────────────────────────────────────────────────────────
@dataclass(frozen=True)
class Surface:
    """One thing the registry names for this seat, and what it is doing now."""

    service_id: str
    container: str
    criticality: str
    state: str  # up | down | unknown
    kind: str = "container"  # container | unit — which road a verb must use

    @property
    def healthy(self) -> bool:
        return self.state == "up"

    @property
    def actable(self) -> bool:
        """May this loop touch it at all? `always` is the Allfather's, not ours."""
        return self.criticality != CRITICAL_ALWAYS

    def line(self) -> str:
        return (
            f"{self.container} — {self.kind} — {self.state} — "
            f"criticality: {self.criticality} (service {self.service_id})"
        )


@dataclass(frozen=True)
class Measurement:
    host: str
    machine: tuple[tuple[str, str], ...]
    surfaces: tuple[Surface, ...]
    audit: str
    registry: str
    note: str = ""

    @property
    def faulted(self) -> tuple[Surface, ...]:
        # `unknown` is NOT a fault: a state that could not be read cannot be proved
        # well either, and a loop that acts on a guess is the fault this replaces.
        return tuple(s for s in self.surfaces if s.state == "down")

    def lines(self) -> tuple[str, ...]:
        rows = [f"{key}: {value}" for key, value in self.machine]
        rows.append(f"registry-audit: {self.audit}")
        if self.note:
            rows.append(f"registry: {self.note}")
        rows.extend(surface.line() for surface in self.surfaces)
        if not self.surfaces:
            rows.append("surfaces: none — this registry names nothing on this seat")
        return tuple(rows)


def machine_facts(
    *,
    meminfo: Path = Path("/proc/meminfo"),
    loadavg: Path = Path("/proc/loadavg"),
    cpu_count: int | None = None,
) -> tuple[tuple[str, str], ...]:
    """Memory, swap and load — cheap reads, no judgement, no shelling out."""
    facts: list[tuple[str, str]] = []
    values: dict[str, int] = {}
    try:
        for raw in meminfo.read_text(encoding="utf-8").splitlines():
            key, _, rest = raw.partition(":")
            parts = rest.split()
            if parts and parts[0].isdigit():
                values[key.strip()] = int(parts[0])
    except OSError:
        facts.append(("memory", "unreadable"))
    if values:
        total = values.get("MemTotal", 0) or 0
        avail = values.get("MemAvailable", 0) or 0
        swap_total = values.get("SwapTotal", 0) or 0
        swap_free = values.get("SwapFree", 0) or 0
        if total:
            facts.append(("memory-available", f"{(100 * avail) // total}% of {total // 1024} MiB"))
        if swap_total:
            used = 100 * (swap_total - swap_free) // swap_total
            facts.append(("swap-used", f"{used}% of {swap_total // 1024} MiB"))
        else:
            facts.append(("swap-used", "none configured"))
    try:
        load = loadavg.read_text(encoding="utf-8").split()
        cpus = cpu_count if cpu_count is not None else (os.cpu_count() or 0)
        facts.append(("load-1m", f"{load[0]} of {cpus} cpu"))
    except (OSError, IndexError):
        facts.append(("load-1m", "unreadable"))
    return tuple(facts)


def read_registry(path: Path) -> dict:
    """The registry, or a refusal — an unreadable registry is not an empty one."""
    try:
        import yaml  # noqa: PLC0415 — the config layer's dependency, probed at use
    except ImportError as exc:  # pragma: no cover - a venv without PyYAML
        raise SupervisorRefused(
            f"the registry cannot be read without PyYAML ({path}) — bin/engine/ymir-engine-ensure.sh"
        ) from exc
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except OSError as exc:
        raise SupervisorRefused(f"registry unreadable: {path} ({exc})") from exc
    if not isinstance(data, dict) or not isinstance(data.get("services"), list):
        raise SupervisorRefused(f"registry has no `services:` list: {path}")
    return data


def container_states(
    names: Sequence[str], *, runner: proc.Runner = proc.run
) -> dict[str, str]:
    """`docker inspect` once for every name — one call, no per-container spray."""
    if not names:
        return {}
    result = runner(
        ["docker", "inspect", "--format", "{{.Name}} {{.State.Status}}", *names],
        timeout=60,
    )
    states: dict[str, str] = {}
    if result.returncode != 0:
        return states
    for raw in result.stdout.splitlines():
        parts = raw.split()
        if len(parts) >= 2:
            states[parts[0].lstrip("/")] = parts[1].strip().lower()
    return states


def render_states(states: Mapping[str, str]) -> dict[str, str]:
    """Docker's own words, mapped to the two the loop reasons about."""
    rendered: dict[str, str] = {}
    for name, state in states.items():
        rendered[name] = "up" if state in ("running", "paused", "restarting") else "down"
    return rendered


def measure(
    *,
    registry: Path,
    host: str,
    any_host: bool = False,
    runner: proc.Runner = proc.run,
    probe: Callable[[str], str] = proc.which,
    facts: Sequence[tuple[str, str]] | None = None,
    audit: str | None = None,
    docker_states: Mapping[str, str] | None = None,
    root: Path | None = None,
) -> Measurement:
    """One cheap pass. No judgement lives here — only what is, measured."""
    data = read_registry(registry)
    facts = tuple(facts) if facts is not None else machine_facts()
    registry_host = str(data.get("host") or "").strip()
    mine = host in (registry_host, socket.gethostname(), socket.gethostname().split(".")[0])

    surfaces: list[Surface] = []
    note = ""
    if not mine and not any_host:
        note = (
            f"the registry names host={registry_host or 'nobody'} and this seat is {host} — "
            "no surface here is this supervisor's to act on"
        )

    if mine or any_host:
        wanted: list[tuple[str, str, str]] = []
        for service in data.get("services") or []:
            if not isinstance(service, dict):
                continue
            row_host = str(service.get("host") or registry_host).strip()
            if not any_host and row_host and row_host != host:
                continue
            criticality = str(service.get("criticality") or "unknown").strip().lower()
            for container in service.get("containers") or []:
                wanted.append((str(service.get("id") or "unnamed"), str(container), criticality))
        states = docker_states
        if states is None:
            states = render_states(container_states([name for _, name, _ in wanted], runner=runner))
        for service_id, container, criticality in wanted:
            surfaces.append(
                Surface(
                    service_id=service_id,
                    container=container,
                    criticality=criticality,
                    state=states.get(container, "unknown"),
                )
            )

    if audit is None:
        audit = registry_audit_line(registry, runner=runner, probe=probe, root=root)

    return Measurement(
        host=host,
        machine=facts,
        surfaces=tuple(surfaces),
        audit=audit,
        registry=str(registry),
        note=note,
    )


def registry_audit_line(
    registry: Path, *, runner: proc.Runner = proc.run, probe: Callable[[str], str] = proc.which,
    root: Path | None = None,
) -> str:
    """The registry's own audit, re-used — never a second truth.

    `bin/records/registry-audit.sh` owns "is every running container named". This
    asks it the same question, pointed at the same registry the loop measures.
    """
    door = ""
    if root is not None:
        candidate = Path(root) / "bin" / "records" / "registry-audit.sh"
        if candidate.is_file():
            door = str(candidate)
    if not door:
        door = probe("registry-audit.sh")
    if not door:
        return "not measured (bin/records/registry-audit.sh absent)"
    result = runner(["bash", door, "--quiet", "--registry", str(registry)], timeout=120)
    line = (result.stdout or result.stderr or "").strip().splitlines()
    return line[-1] if line else "not measured (the audit printed nothing)"


# ── the judgement ────────────────────────────────────────────────────────────
@dataclass(frozen=True)
class Verdict:
    verb: str
    target: str
    runbook: str
    reason: str
    needs_allfather: bool
    raw: str = ""

    def as_row(self) -> tuple[str, ...]:
        return (self.verb, self.target, self.runbook, self.reason)


class SupervisorRefused(Exception):
    """The loop will not proceed, and says why. Never a silent skip."""


def judging_prompt(measurement: Measurement, runbook_index: str) -> str:
    """The prompt the judge is handed: what is measured, the library, the verbs.

    Nothing here decides anything — it hands over the facts the Allfather said the
    supervisor must work from.
    """
    verb_lines = "\n".join(
        f"  {name:18s} {spec['does']}  (allowed when {spec['guard']})"
        for name, spec in VERBS.items()
    )
    faulted = measurement.faulted
    fault_lines = "\n".join(f"  {surface.line()}" for surface in faulted) or "  none"
    return f"""You are Sýn's judgement — the middle step of the supervisor loop on {measurement.host}.
You are handed a MEASUREMENT (facts only) and the RUNBOOK LIBRARY index (situation → page).
Answer with ONE verb from the list below, and the reason. Never invent a verb.

VERBS — the only ones that exist:
{verb_lines}

THE LAW YOU KEEP:
  · one verb only, and its target must be one of the surfaces measured below;
  · `*-container` acts on a surface whose kind is `container`; `*-unit` acts on a `unit`;
  · a surface whose criticality is `always` is NEVER acted on — answer `escalate`;
  · a fault whose cure needs the Allfather (a credential, money, a critical door, a Gimlé surface,
    another hand's unit, a door this machine may not touch) is `escalate`, in ONE message, no retry;
  · a surface whose container restarts but whose port answers is not faulted;
  · nothing faulted means `none` — an idle loop is a working loop.

FAULTED SURFACES (state is not up):
{fault_lines}

MEASUREMENT
{chr(10).join(measurement.lines())}

RUNBOOK LIBRARY (situation → page)
{runbook_index}

Answer with ONE JSON object and nothing else, exactly these keys:
{{"verb": "<one of the verbs above>", "target": "<the container or unit, or the surface id>", "runbook": "<the runbook page you read>", "reason": "<one sentence>", "needs_allfather": <true|false>}}
"""


_JSON_OBJECT = re.compile(r"\{[^{}]*\}", re.DOTALL)


def parse_verdict(text: str) -> Verdict:
    """The model's answer, read strictly — a verb outside the vocabulary is refused."""
    candidate = ""
    for match in _JSON_OBJECT.finditer(text or ""):
        candidate = match.group(0)
    if not candidate:
        raise SupervisorRefused("the judge answered with no JSON object — no verb can be read")
    try:
        payload = json.loads(candidate)
    except json.JSONDecodeError as exc:
        raise SupervisorRefused(f"the judge's JSON did not parse: {exc}") from exc
    verb = str(payload.get("verb") or "").strip()
    if verb not in VERBS:
        raise SupervisorRefused(
            f"the judge named the verb `{verb or '(empty)'}`, which is not in the house's vocabulary"
            f" ({', '.join(sorted(VERBS))}) — refused rather than guessed"
        )
    return Verdict(
        verb=verb,
        target=str(payload.get("target") or "").strip(),
        runbook=str(payload.get("runbook") or "").strip(),
        reason=str(payload.get("reason") or "").strip(),
        needs_allfather=bool(payload.get("needs_allfather")) or verb == "escalate",
        raw=candidate,
    )


def runbook_index(path: Path, *, limit: int = 4000) -> str:
    """The library's situation → page table, read from the one index page.

    The judge opens the RIGHT page instead of improvising: the index is the shelf's
    own `README.md`, and its second half IS the situation table.
    """
    try:
        body = path.read_text(encoding="utf-8")
    except OSError:
        return "(the runbook library index is absent — judge from the measurement alone and say so in the reason)"
    rows = [line for line in body.splitlines() if line.strip().startswith("|")]
    table = "\n".join(rows) if rows else body
    return table[:limit]


def judge(
    measurement: Measurement,
    *,
    index_path: Path,
    door: Path,
    runner: proc.Runner = proc.run,
    timeout: float = 300,
) -> Verdict:
    """One model turn through the door the house carries; the answer, read strictly."""
    prompt = judging_prompt(measurement, runbook_index(index_path))
    if not Path(door).is_file():
        raise SupervisorRefused(f"the judge door is absent: {door}")
    result = runner(["bash", str(door)], input_text=prompt, timeout=timeout)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout or "").strip().splitlines()
        raise SupervisorRefused(
            f"the judge door refused or failed (exit {result.returncode}): {detail[-1] if detail else 'no output'}"
        )
    return parse_verdict(result.stdout)


# ── the escalation ───────────────────────────────────────────────────────────
def helm_state(roots: paths_mod.Roots, env: Mapping[str, str]) -> Path:
    """Where a message FOR THE HELM goes — never a worker's private seat state.

    Measured 2026-11-17, the day this loop was built: the first escalation landed in
    `$BROKK_STATE_OVERRIDE`, which on a worker is its own seat dir — a wake nobody
    reads (plan 272, fault 1). The house already owns this rule in bash
    (`bin/agents/eindri-wake-lib.sh:eindri_helm_state`); this is its one Python twin:

        BROKK_HELM_STATE              the helm's queue, named outright
        BROKK_STATE_OVERRIDE          honoured UNLESS it is this seat's own machine state
        <home>/state                  otherwise (YMIR_STATE_DIR, then the home law)
    """
    explicit = (env.get("BROKK_HELM_STATE") or "").strip()
    if explicit:
        return Path(explicit).expanduser()
    override = (env.get("BROKK_STATE_OVERRIDE") or "").strip()
    machine = (env.get("BROKK_MACHINE_STATE_DIR") or "").strip()
    if override and override != machine:
        return Path(override).expanduser()
    named = (env.get("YMIR_STATE_DIR") or "").strip()
    return Path(named).expanduser() if named else roots.home / "state"


def surface_for(verdict: Verdict, measurement: Measurement) -> Surface | None:
    return next(
        (
            s
            for s in measurement.surfaces
            if s.container == verdict.target or s.service_id == verdict.target
        ),
        None,
    )


def escalate(
    verdict: Verdict,
    measurement: Measurement,
    *,
    state_dir: Path,
    root: Path,
    runner: proc.Runner = proc.run,
    why: str = "",
) -> tuple[bool, str]:
    """ONE message to the helm — never a retry, never a silent skip.

    The road is the house's own: a `check:` line in the durable wake queue, which
    Sýn's arm drains and hands to the session (plan 310 — only a holder that can
    speak may act, and what it cannot do it says aloud).
    """
    surface = surface_for(verdict, measurement)
    measured = surface.line() if surface else (verdict.target or measurement.host)
    line = (
        f"check: syn-supervisor — {measured} needs the Allfather: "
        f"{why or verdict.reason or 'the judge named escalate'}"
        f" (verb: {verdict.verb}; runbook: {verdict.runbook or 'none named'}; host: {measurement.host})"
    )
    try:
        state_dir.mkdir(parents=True, exist_ok=True)
        with (state_dir / ".wake-queue").open("a", encoding="utf-8") as handle:
            handle.write(line + "\n")
    except OSError as exc:
        return False, f"the wake could not be written ({state_dir}/.wake-queue): {exc}"

    runes = Path(root) / "bin" / "records" / "runes-append.sh"
    if runes.is_file():
        runner(
            [
                "bash",
                str(runes),
                "syn",
                "supervisor-escalate",
                "--message",
                f"{measured} escalated: {why or verdict.reason or 'needs the Allfather'}",
            ],
            timeout=120,
        )
    return True, line


# ── the arm, the act, the proof, the record ───────────────────────────────────
def arm_held(*, root: Path, runner: proc.Runner = proc.run) -> tuple[bool, str]:
    """Is a holder with a voice on the arm right now? (plan 310 — the arm is the authority)"""
    door = Path(root) / "bin" / "voice" / "rodd-arm.sh"
    if not door.is_file():
        return False, f"the arm door is absent ({door}) — no authority to act"
    result = runner(["bash", str(door), "who"], timeout=60)
    if result.returncode != 0:
        return False, "no arm is held — a supervisor with no authority does not act"
    detail = (result.stdout or "").strip().splitlines()
    return True, detail[-1] if detail else "arm held"


def act(
    verdict: Verdict,
    *,
    measurement: Measurement,
    root: Path,
    runner: proc.Runner = proc.run,
    dry_run: bool = False,
) -> tuple[bool, str]:
    """Perform the ONE verb, or refuse. A refusal is visible, never a quiet retry."""
    if verdict.verb == "escalate":
        return False, "escalated to the Allfather — one message, no retry"
    if verdict.verb == "none":
        return False, "the judge found nothing to do"
    surface = surface_for(verdict, measurement)
    if surface is None:
        raise SupervisorRefused(
            f"the judge named the target `{verdict.target or '(empty)'}`, which this registry does not "
            "name for this seat — a target outside the measurement is refused"
        )
    # The verb's road must fit the surface's KIND: `start-unit` on a container is a
    # judgement that reads right and runs wrong (measured 2026-11-17 — the judge said
    # `start-unit` for a docker container), so the pairing is the house's, not the model's.
    wanted_kind = "unit" if verdict.verb.endswith("-unit") else "container"
    if surface.kind != wanted_kind:
        raise SupervisorRefused(
            f"`{verdict.verb}` acts on a {wanted_kind}, and `{surface.container}` is a {surface.kind} "
            "in this registry — the verb does not fit the surface"
        )
    if not surface.actable:
        raise SupervisorRefused(
            f"`{surface.container}` is criticality: {surface.criticality} — the question is the "
            "Allfather's (plan 004 §5.1), so the loop escalates instead of acting"
        )
    if dry_run:
        return True, f"would run `{verdict.verb} {surface.container}` (dry run)"
    if verdict.verb == "start-container":
        argv = ["docker", "start", surface.container]
    elif verdict.verb == "restart-container":
        argv = ["docker", "restart", surface.container]
    elif verdict.verb in ("start-unit", "restart-unit"):
        verb = "start" if verdict.verb == "start-unit" else "restart"
        argv = ["systemctl", "--user", verb, surface.container]
    else:  # pragma: no cover - guarded by VERBS and parse_verdict
        raise SupervisorRefused(f"the verb `{verdict.verb}` has no road here")
    result = runner(argv, timeout=180)
    detail = (result.stderr or result.stdout or "").strip().splitlines()
    tail = detail[-1] if detail else ""
    if result.returncode != 0:
        return False, f"`{' '.join(argv)}` failed (exit {result.returncode}){': ' + tail if tail else ''}"
    return True, f"`{' '.join(argv)}`"


def prove(
    verdict: Verdict,
    before: Measurement,
    *,
    remeasure: Callable[[], Measurement],
    expected: str | None = None,
) -> tuple[bool, str, Measurement]:
    """Run the SAME measurement again: the fault must be gone, or the act failed."""
    after = remeasure()
    target = verdict.target
    if verdict.verb == "none":
        return True, "nothing was acted on, so nothing is proved", after
    for surface in after.surfaces:
        if surface.container == target or surface.service_id == target:
            if surface.state == (expected or "up"):
                return True, f"re-measured: {surface.container} is {surface.state}", after
            return False, f"re-measured: {surface.container} is {surface.state} — the act did not hold", after
    return False, f"re-measured: `{target}` is not in the measurement any more — cannot be proved", after


def record(
    verdict: Verdict,
    before: Measurement,
    after: Measurement | None,
    proved: bool,
    *,
    fixes_path: Path,
    root: Path,
    runner: proc.Runner = proc.run,
    stamp: str = "",
) -> tuple[bool, str]:
    """One line in the machine's fixes.md, one rune. Every act, proved or not."""
    stamp = stamp or time.strftime("%Y-%m-%d %H:%M")
    surfaces_before = ", ".join(f"{s.container}={s.state}" for s in before.surfaces) or "none"
    surfaces_after = ", ".join(f"{s.container}={s.state}" for s in (after.surfaces if after else ())) or "none"
    verdict_word = "proved" if proved else "FAILED"
    detail = (
        f"Sýn judged `{verdict.verb}{' ' + verdict.target if verdict.target else ''}` "
        f"(runbook: {verdict.runbook or 'none named'}) — {verdict.reason or 'no reason given'}. "
        f"measured [{surfaces_before}] → [{surfaces_after}] — {verdict_word}."
    )
    line = f"- **{stamp}** — {detail}"
    try:
        fixes_path.parent.mkdir(parents=True, exist_ok=True)
        if not fixes_path.exists():
            fixes_path.write_text(
                f"# {before.host} — what was fixed, dated\n\n"
                "Append-only. One line per fix, with the day and the evidence. The supervisor writes here\n"
                "itself, once per act, with the judgement and the re-measurement.\n\n",
                encoding="utf-8",
            )
        with fixes_path.open("a", encoding="utf-8") as handle:
            handle.write(line + "\n")
    except OSError as exc:
        return False, f"the fixes line could not be written ({fixes_path}): {exc}"

    runes = Path(root) / "bin" / "records" / "runes-append.sh"
    if not runes.is_file():
        return False, f"fixes.md written; the rune door is absent ({runes})"
    result = runner(
        [
            "bash",
            str(runes),
            "syn",
            "supervisor-act",
            "--message",
            f"{verdict.verb} {verdict.target or before.host} — {verdict_word} — {verdict.reason or 'no reason'}",
        ],
        timeout=120,
    )
    if result.returncode != 0:
        return False, f"fixes.md written; the rune failed (exit {result.returncode})"
    return True, "fixes.md line + one rune"


# ── the cycle ────────────────────────────────────────────────────────────────
@dataclass
class Outcome:
    measurement: Measurement
    verdict: Verdict | None = None
    acted: bool = False
    proved: bool = False
    recorded: bool = False
    escalated: bool = False
    refused: str = ""
    detail: str = ""
    steps: list[tuple[str, str]] = field(default_factory=list)

    def toon(self) -> str:
        rows = [
            f'  "measure","{self.measurement.host}","{len(self.measurement.surfaces)} surfaces, '
            f'{len(self.measurement.faulted)} faulted"',
        ]
        if self.verdict is not None:
            rows.append(
                f'  "judge","{self.verdict.verb} {self.verdict.target}","{_clean(self.verdict.reason)}"'
            )
        rows.append(f'  "act","{"yes" if self.acted else "no"}","{_clean(self.detail)}"')
        rows.append(f'  "prove","{"yes" if self.proved else "no"}","{_clean(self.proof_detail())}"')
        rows.append(f'  "record","{"yes" if self.recorded else "no"}","{_clean(self.record_detail())}"')
        return "supervise[1]{step,what,detail}:\n" + "\n".join(rows) + "\n"

    def proof_detail(self) -> str:
        for name, detail in self.steps:
            if name == "prove":
                return detail
        return "not reached"

    def record_detail(self) -> str:
        for name, detail in self.steps:
            if name == "record":
                return detail
        return "not reached"


def _clean(text: str) -> str:
    return " ".join((text or "").split()).replace('"', "'")[:300]


def cycle(
    *,
    registry: Path,
    host: str,
    root: Path,
    fixes_path: Path,
    index_path: Path,
    judge_door: Path,
    state_dir: Path,
    any_host: bool = False,
    dry_run: bool = False,
    measure_fn: Callable[..., Measurement] = measure,
    judge_fn: Callable[..., Verdict] = judge,
    arm_fn: Callable[..., tuple[bool, str]] = arm_held,
    act_fn: Callable[..., tuple[bool, str]] = act,
    escalate_fn: Callable[..., tuple[bool, str]] = escalate,
    runner: proc.Runner = proc.run,
    probe: Callable[[str], str] = proc.which,
) -> Outcome:
    """One full pass of the five steps. Every decision is a parameter, so the
    loop's own contract is assertable without a container, a model or an arm."""
    before = measure_fn(
        registry=registry, host=host, any_host=any_host, runner=runner, probe=probe, root=root
    )
    outcome = Outcome(measurement=before)
    outcome.steps.append(("measure", ", ".join(before.lines())))

    try:
        verdict = judge_fn(before, index_path=index_path, door=judge_door, runner=runner)
    except SupervisorRefused as exc:
        outcome.refused = str(exc)
        outcome.detail = str(exc)
        outcome.steps.append(("judge", f"refused: {exc}"))
        return outcome
    outcome.verdict = verdict
    outcome.steps.append(("judge", f"{verdict.verb} {verdict.target} — {verdict.reason}"))

    if verdict.verb == "none":
        outcome.detail = "nothing to do"
        outcome.steps.append(("act", "none"))
        return outcome

    # A fault whose cure is the Allfather's is SAID, once — never retried, never
    # attempted on the arm's authority (plan 004 §5.1: `criticality: always` is his).
    target = surface_for(verdict, before)
    escalate_why = ""
    if verdict.verb == "escalate" or verdict.needs_allfather:
        escalate_why = verdict.reason or "the judge named escalate"
    elif target is not None and not target.actable:
        escalate_why = (
            f"`{target.container}` is criticality: {target.criticality} — the question is the Allfather's"
        )
    if escalate_why:
        if dry_run:
            outcome.detail = f"would escalate: {escalate_why}"
            outcome.steps.append(("act", outcome.detail))
            return outcome
        sent, detail = escalate_fn(
            verdict, before, state_dir=state_dir, root=root, runner=runner, why=escalate_why
        )
        outcome.detail = detail
        outcome.escalated = sent
        outcome.steps.append(("act", f"escalated: {detail}" if sent else f"escalation FAILED: {detail}"))
        if not sent:
            outcome.refused = detail
            return outcome
        return outcome

    held, arm_detail = arm_fn(root=root, runner=runner)
    if not held:
        outcome.refused = arm_detail
        outcome.detail = arm_detail
        outcome.steps.append(("act", f"refused: {arm_detail}"))
        return outcome

    try:
        acted, detail = act_fn(
            verdict, measurement=before, root=root, runner=runner, dry_run=dry_run
        )
    except SupervisorRefused as exc:
        outcome.refused = str(exc)
        outcome.detail = str(exc)
        outcome.steps.append(("act", f"refused: {exc}"))
        return outcome
    outcome.acted = acted
    outcome.detail = detail
    outcome.steps.append(("act", detail))

    if not acted:
        return outcome

    if dry_run:
        outcome.steps.append(("prove", "dry run — nothing to prove"))
        return outcome

    proved, proof_detail, after = prove(
        verdict,
        before,
        remeasure=lambda: measure_fn(
            registry=registry, host=host, any_host=any_host, runner=runner, probe=probe, root=root
        ),
    )
    outcome.proved = proved
    outcome.steps.append(("prove", proof_detail))

    recorded, record_detail = record(
        verdict,
        before,
        after,
        proved,
        fixes_path=fixes_path,
        root=root,
        runner=runner,
    )
    outcome.recorded = recorded
    outcome.steps.append(("record", record_detail))
    return outcome


def main(
    argv: Sequence[str],
    *,
    env: Mapping[str, str] | None = None,
    runner: proc.Runner = proc.run,
    probe: Callable[[str], str] = proc.which,
) -> int:
    """The verb's own face: `supervise [--once|--every N] [--registry P] …`."""
    args = list(argv)
    registry_arg = ""
    judge_arg = ""
    index_arg = ""
    host = ""
    fix_target = ""
    every = 0
    once = True
    any_host = False
    dry_run = False
    toon = False

    index = 0
    while index < len(args):
        item = args[index]
        if item in ("-h", "--help"):
            print(
                "supervise [--once] [--every SECONDS] [--registry PATH] [--judge PATH]\n"
                "          [--runbook-index PATH] [--host NAME] [--fixes PATH] [--any-host] [--dry-run] [--toon]\n\n"
                "the supervisor loop: measure → judge (an agent) → act under the arm → prove → record."
            )
            return EXIT_OK
        if item == "--once":
            once, every = True, 0
        elif item == "--every":
            index += 1
            every = int(args[index])
            once = False
        elif item == "--registry":
            index += 1
            registry_arg = args[index]
        elif item == "--judge":
            index += 1
            judge_arg = args[index]
        elif item == "--runbook-index":
            index += 1
            index_arg = args[index]
        elif item == "--host":
            index += 1
            host = args[index]
        elif item == "--fixes":
            index += 1
            fix_target = args[index]
        elif item == "--any-host":
            any_host = True
        elif item == "--dry-run":
            dry_run = True
        elif item == "--toon":
            toon = True
        else:
            print(f"supervise: unknown flag {item}", file=sys.stderr)
            return EXIT_USAGE
        index += 1

    roots = paths_mod.resolve(env)
    root = roots.root
    host = host or (socket.gethostname().split(".")[0] or "unknown")
    registry = Path(registry_arg).expanduser() if registry_arg else roots.hoard / "identity" / "services.yaml"
    harness_judge = Path(judge_arg).expanduser() if judge_arg else root / "bin" / "agents" / "syn-judge.sh"
    index_path = (
        Path(index_arg).expanduser()
        if index_arg
        else roots.hoard / "docs" / "runbooks" / "README.md"
    )
    fixes_path = (
        Path(fix_target).expanduser()
        if fix_target
        else roots.hoard / "machines" / host / "fixes.md"
    )

    def one_pass() -> int:
        try:
            outcome = cycle(
                registry=registry,
                host=host,
                root=root,
                fixes_path=fixes_path,
                index_path=index_path,
                judge_door=harness_judge,
                state_dir=helm_state(roots, env if env is not None else dict(os.environ)),
                any_host=any_host,
                dry_run=dry_run,
                runner=runner,
                probe=probe,
            )
        except SupervisorRefused as exc:
            print(f"refused: {exc}", file=sys.stderr)
            return EXIT_REFUSED
        if toon:
            print(outcome.toon(), end="")
        else:
            for name, detail in outcome.steps:
                print(f"{name}: {detail}")
        if outcome.refused:
            print(f"refused: {outcome.refused}", file=sys.stderr)
            return EXIT_REFUSED
        if outcome.acted and not outcome.proved:
            return EXIT_FAILED
        return EXIT_OK

    if once:
        return one_pass()
    while True:  # pragma: no cover - the standing loop, the unit's ExecStart
        one_pass()
        time.sleep(max(30, every))

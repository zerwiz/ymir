"""Load a hoard config WITH its schema — one road from a file to trusted values.

`load_config(path)` answers the only question a door should ask: "is this file a
config I may act on?" It reads the file, picks the registered schema for its
kind, validates, runs the kind's semantic checks, and only then returns the
data. A missing kind, a missing schema, a parse fault, a shape fault and a
semantic fault all refuse loudly — none of them returns a default.

The kinds are the configs the RUNTIME actually resolves (plan 58, Phase 7):

    agents.yaml            bin/fleet/agents-config.sh · bin/fleet/dispatch-profile.sh
                           bin/model/local-model-lock.sh · bin/agents/einherjar-spawn.sh
    cron.yaml              bin/time/nornir-cron-start.sh · bin/time/snotra/hall-snapshot.sh
    fleet.json             bin/fleet/topology.sh · bin/agents/eindri-route.sh
                           bin/bridge/mcp-gateway.sh · bin/model/model-placement.sh · bin/model/rail-resolve.sh
    eindri-dispatch.json   bin/fleet/dispatch-profile.sh

A config the runtime does NOT read gets no schema and is not loaded here —
boilerplate schemas were the fault this phase avoids.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Mapping

from .. import paths
from .schema import (
    ConfigError,
    ConfigUnavailable,
    ConfigValidationError,
    validate,
)

Semantic = Callable[..., None]

_CRON_TIME = re.compile(r"^([01][0-9]|2[0-3]):[0-5][0-9]$")
_CRON_GATE = re.compile(r"^@[A-Za-z][A-Za-z0-9_-]*(?:,[A-Za-z][A-Za-z0-9_-]*)*$")
_AGENT_OVERLAY = re.compile(r"^agents\.[^.]+\.yaml$")


@dataclass(frozen=True)
class ConfigSpec:
    """One registered kind: its schema file, its parser, its semantic checks."""

    kind: str
    schema: str
    parse: str  # "yaml" | "json" | "cron"
    semantics: tuple[Semantic, ...] = ()


# ── the semantic checks (things JSON Schema cannot say) ──────────────────────


def _agents_are_rostered(doc: Mapping[str, Any], *, source: str, root: Path | None = None, **_ignored: Any) -> None:
    """Every agent name must be a rostered figure (.agents/agents is canonical)."""
    roster_dir = (root or paths.resolve().root) / ".agents" / "agents"
    if not roster_dir.is_dir():
        return  # a config-only context has no roster to judge against
    figures = [entry.stem for entry in roster_dir.glob("*.md")]
    for name in sorted((doc.get("agents") or {}).keys()):
        if name in figures:
            continue
        if any(figure.startswith(f"{name}-") for figure in figures):
            continue
        raise ConfigValidationError(
            f"agent {name!r} is not a rostered figure "
            f"(.agents/agents/{name}.md or {name}-*.md is canonical)",
            source=source,
            key=f"agents.{name}",
        )


def _fleet_heart_is_declared(doc: Mapping[str, Any], *, source: str, **_ignored: Any) -> None:
    """The heart must be a row in hosts, or the fleet has no record holder."""
    hosts = doc.get("hosts") or {}
    heart = str(doc.get("heart") or "")
    if heart and heart not in hosts:
        raise ConfigValidationError(
            f"heart {heart!r} is not a declared host — the record would land nowhere",
            source=source,
            key="heart",
        )


def _fleet_host_is_itself(doc: Mapping[str, Any], *, source: str, host: str | None = None, **_ignored: Any) -> None:
    """A registry naming a host that is not itself is a loud refusal at boot."""
    if not host:
        return
    hosts = doc.get("hosts") or {}
    if host not in hosts:
        raise ConfigValidationError(
            f"this host {host!r} has no row in the registry — the machine cannot read itself",
            source=source,
            key="hosts",
        )


def _grants_obey_the_realm_law(doc: Mapping[str, Any], *, source: str, **_ignored: Any) -> None:
    """Every grant obeys the realm law — signed per Heimdall when it crosses.

    Imported lazily so the package's own init never drags the grants module in
    before its door (`python3 -m ymir_runtime.grants`) runs.
    """
    from ..grants import check_registry

    check_registry(doc, source=source)


# ── the parsers ──────────────────────────────────────────────────────────────


def _parse_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ConfigError(f"{path}: not valid JSON: {exc}") from exc


def _parse_yaml(path: Path) -> Any:
    try:
        import yaml
    except Exception as exc:  # pragma: no cover - exercised by the unavailability tests
        raise ConfigUnavailable("PyYAML") from exc
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        raise ConfigError(f"{path}: not valid YAML: {exc}") from exc


def _parse_cron(path: Path) -> Any:
    """Parse `HH:MM [@role[,role]] <command>` (either order) into the schema document.

    A line the scheduler cannot parse is a job that silently never fires — so the
    parse itself refuses, naming the file and the line.
    """
    jobs: list[dict[str, Any]] = []
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        # No role gate, or the role-first form `@heart 06:00 cmd`.
        gate = ""
        head, _, rest = line.partition(" ")
        if head.startswith("@"):
            gate, line = head, rest.strip()
        # `HH:MM cmd` or `HH:MM @heart cmd`.
        time_token, _, after = line.partition(" ")
        after = after.strip()
        if after.startswith("@"):
            gate, _, after = after.partition(" ")
            after = after.strip()
        command = after
        if not _CRON_TIME.match(time_token):
            raise ConfigError(f"{path}: line {number}: not a valid HH:MM time: {time_token!r}")
        if not command:
            raise ConfigError(f"{path}: line {number}: no command after {time_token!r} — a job that never runs")
        if gate and not _CRON_GATE.match(gate):
            raise ConfigError(f"{path}: line {number}: malformed role gate {gate!r} (want @heart,@forge)")
        job: dict[str, Any] = {"time": time_token, "command": command}
        if gate:
            job["roles"] = [role for role in gate[1:].split(",") if role]
        jobs.append(job)
    return {"jobs": jobs}


_PARSERS: dict[str, Callable[[Path], Any]] = {
    "json": _parse_json,
    "yaml": _parse_yaml,
    "cron": _parse_cron,
}


KNOWN: dict[str, ConfigSpec] = {
    "agents": ConfigSpec("agents", "agents.schema.json", "yaml", (_agents_are_rostered,)),
    "cron": ConfigSpec("cron", "cron.schema.json", "cron"),
    "fleet": ConfigSpec("fleet", "fleet.schema.json", "json", (_fleet_heart_is_declared, _fleet_host_is_itself)),
    "eindri-dispatch": ConfigSpec("eindri-dispatch", "eindri-dispatch.schema.json", "json"),
    "grants": ConfigSpec("grants", "grants.schema.json", "yaml", (_grants_obey_the_realm_law,)),
}


def spec_for(path: str | Path, kind: str | None = None) -> ConfigSpec:
    """The registered kind for a config path — or a refusal, never a guess."""
    if kind:
        try:
            return KNOWN[kind]
        except KeyError:
            raise ConfigError(
                f"unknown config kind {kind!r}; known: {', '.join(sorted(KNOWN))}"
            ) from None
    name = Path(path).name
    if name.endswith(".example"):
        name = name[: -len(".example")]
    if name == "cron.yaml":
        return KNOWN["cron"]
    if name == "fleet.json":
        return KNOWN["fleet"]
    if name == "eindri-dispatch.json":
        return KNOWN["eindri-dispatch"]
    if name == "grants.yaml":
        return KNOWN["grants"]
    if name == "agents.yaml" or _AGENT_OVERLAY.match(name):
        return KNOWN["agents"]
    raise ConfigError(
        f"{path}: no schema is registered for this config — refusing to load it unvalidated"
    )


def schema_path(spec: ConfigSpec, *, root: str | Path | None = None, schema_dir: str | Path | None = None) -> Path:
    """Resolve the schema file, or refuse: a schema that cannot be found is not skipped."""
    if schema_dir:
        candidate = Path(schema_dir).expanduser() / spec.schema
        if candidate.is_file():
            return candidate
        raise ConfigError(f"no {spec.schema} under {schema_dir}")
    base = Path(root).expanduser() if root else paths.resolve().root
    for candidate in (base / "config" / spec.schema, base / ".agents" / "config" / spec.schema):
        if candidate.is_file():
            return candidate
    raise ConfigError(
        f"{spec.schema} not found under {base}/config — the schema must travel with the code"
    )


def _read_schema(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ConfigError(f"{path}: the schema itself is not valid JSON: {exc}") from exc


def load_config(
    path: str | Path,
    *,
    kind: str | None = None,
    root: str | Path | None = None,
    schema_dir: str | Path | None = None,
    host: str | None = None,
) -> Any:
    """Read, parse, validate and return a config — or refuse loudly.

    `kind` overrides name inference; `root` locates `config/*.schema.json` and the
    agent roster; `host` arms the fleet self-row check; `schema_dir` overrides the
    schema home (tests).
    """
    source = Path(path).expanduser()
    if not source.is_file():
        raise ConfigError(f"{source}: config not found")
    spec = spec_for(source, kind)
    schema = _read_schema(schema_path(spec, root=root, schema_dir=schema_dir))
    data = _PARSERS[spec.parse](source)
    if data is None:
        raise ConfigError(f"{source}: config is empty")
    validate(data, schema, source=str(source), schema_name=spec.schema)
    base = Path(root).expanduser() if root else None
    for check in spec.semantics:
        check(data, source=str(source), root=base, host=host)
    return data

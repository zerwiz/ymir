"""JSON Schema validation for the hoard's configs — a loud refusal, never a default.

Plan 58, Phase 7. Every config the runtime reads is validated against a JSON
Schema in `config/*.schema.json` BEFORE a single value leaves this package:

  * a shape fault raises `ConfigValidationError`, naming the offending KEY and
    the FILE — the caller prints it and stops;
  * a missing validator raises `ConfigUnavailable`, naming the DEPENDENCY and
    the remedy. There is deliberately no branch that returns an unvalidated
    config: silence is the failure this phase exists to end.

`jsonschema` is the validator; it is declared in `src/pyproject.toml` and the
engine's private venv (`bin/engine/ymir-engine-ensure.sh`) installs it. Absence is a
refusal, never a downgrade.
"""

from __future__ import annotations

import re
from typing import Any, Mapping

from ..errors import EngineError

try:  # the dependency is declared, not assumed
    import jsonschema as _jsonschema
    from jsonschema.exceptions import best_match as _best_match
    from jsonschema.exceptions import SchemaError as _SchemaError
except Exception:  # pragma: no cover - exercised by the unavailability tests
    _jsonschema = None
    _best_match = None
    _SchemaError = None  # type: ignore[assignment]

REMEDY = "bin/engine/ymir-engine-ensure.sh ensure (installs the declared dependencies)"


class ConfigError(EngineError):
    """A config could not be trusted; the load stops here."""


class ConfigUnavailable(ConfigError):
    """The tool that would validate or parse this config is not installed.

    This is a REFUSAL, not a fallback: the config is not returned.
    """

    def __init__(self, dependency: str, remedy: str = REMEDY) -> None:
        super().__init__(f"{dependency} is required and is not installed")
        self.dependency = dependency
        self.remedy = remedy


class ConfigValidationError(ConfigError):
    """The config parsed but broke its schema — the key and the file are named."""

    def __init__(self, message: str, *, source: str, key: str = "<root>", schema_name: str = "") -> None:
        super().__init__(message)
        self.message = message
        self.source = source
        self.key = key
        self.schema_name = schema_name

    def __str__(self) -> str:
        where = f"{self.source}: {self.key}"
        if self.schema_name:
            where = f"{where} (schema {self.schema_name})"
        return f"{where}: {self.message}"


def available() -> bool:
    """Is the JSON Schema validator importable? Never a reason to skip a check."""
    return _jsonschema is not None


def _key_of(error: Any) -> str:
    """The dotted key path of a jsonschema error, with the key NAMED."""
    parts: list[str] = []
    for step in error.absolute_path:
        if isinstance(step, int):
            parts.append(f"[{step}]")
        elif parts:
            parts.append(f".{step}")
        else:
            parts.append(str(step))
    key = "".join(parts) or "<root>"
    if getattr(error, "validator", "") == "required":
        match = re.search(r"'([^']+)' is a required property", error.message)
        if match:
            missing = match.group(1)
            key = f"{key}.{missing}" if key != "<root>" else missing
    return key


def validate(instance: Any, schema: Mapping[str, Any], *, source: str, schema_name: str = "") -> None:
    """Validate `instance` against `schema` or refuse loudly.

    Raises `ConfigUnavailable` when no validator is installed and
    `ConfigValidationError` (key + file named) on the first/most relevant fault.
    """
    if _jsonschema is None:
        raise ConfigUnavailable("jsonschema")
    try:
        validator_cls = _jsonschema.validators.validator_for(schema)
        validator_cls.check_schema(schema)
    except _SchemaError as exc:  # the schema itself is broken — a code fault
        raise ConfigError(f"{schema_name or source}: the schema itself is invalid: {exc.message}") from exc
    errors = list(validator_cls(schema).iter_errors(instance))
    if not errors:
        return
    error = _best_match(errors)
    raise ConfigValidationError(
        error.message,
        source=str(source),
        key=_key_of(error),
        schema_name=schema_name,
    )

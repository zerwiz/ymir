"""The config layer's public face (plan 58, Phase 7).

    load_config(path)  -> validated data | ConfigError
    KNOWN              the configs the runtime reads and their schemas
    available()        is the JSON Schema validator installed?

Doors reach the layer through the package's own module CLI
(`python3 -m ymir_runtime.config`), so the engine's four-verb interface is
unbroken.
"""

from __future__ import annotations

from .load import KNOWN, ConfigSpec, load_config, schema_path, spec_for
from .schema import (
    ConfigError,
    ConfigUnavailable,
    ConfigValidationError,
    available,
)

__all__ = [
    "ConfigError",
    "ConfigSpec",
    "ConfigUnavailable",
    "ConfigValidationError",
    "KNOWN",
    "available",
    "load_config",
    "schema_path",
    "spec_for",
]

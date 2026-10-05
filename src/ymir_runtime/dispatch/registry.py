"""`dispatch/registry.py` — where a figure's model comes from, and nothing else.

Two roads, and only two, because conflating them is how a model value ends up
committed to a public tree:

  * **configured(figure)** — the operator's own declared choice, read at runtime
    from `$YMIR_HOME/config/agents.yaml` (with the per-host overlay the config
    layer applies) and validated against `config/agents.schema.json`. This is a
    LOOKUP of declared data, not resolution: the model is already a concrete
    `provider/model` token. The only rule applied is the one the YAML itself
    declares (`harness.local`, `harness.online`, `harness.local_providers`).
    An absent config is a refusal naming `agents.<figure>.model` and the exact
    path — never a silent default.

  * **request(text)** — a human model request ("qwen 3.6 iq3", "deepseek",
    `llama.cpp/…@q2_k_xl`) is RESOLVED by the fleet's own door
    `bin/model/model-resolve.sh` (the loop is bash), whose TOON row is read back. This
    module never re-implements that fuzzy match; it may CALL the door or read its
    output, and it does exactly that. The door is the fleet registry; a second
    copy of its logic would be the drift this package exists to prevent.

Nothing here writes. Nothing here carries a model value: the tree ships none.
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping

from .. import paths, proc
from ..config import ConfigError, load_config
from ..errors import EngineError

MODEL_RESOLVE = Path("bin") / "model-resolve.sh"

_TOON_HEADER = re.compile(r"^(?P<name>[A-Za-z][A-Za-z0-9_-]*)\[(?P<n>\d+)\]\{(?P<cols>[^}]*)\}:\s*$")
_TOON_CELL = re.compile(r'"((?:[^"\\]|\\.)*)"')


class ModelUnavailable(EngineError):
    """No model could be resolved, and silence is never the answer.

    `key` names the config key at fault (e.g. `agents.sindri.model`); `path`
    names the file; `remedy` says what would mend it.
    """

    def __init__(self, message: str, *, key: str = "", path: str | Path | None = None, remedy: str = "") -> None:
        super().__init__(message)
        self.message = message
        self.key = key
        self.path = str(path) if path is not None else ""
        self.remedy = remedy

    def __str__(self) -> str:  # pragma: no cover - trivial
        where = f" (key {self.key})" if self.key else ""
        tail = f" (remedy: {self.remedy})" if self.remedy else ""
        return f"{self.message}{where}{tail}"


@dataclass(frozen=True)
class Configured:
    """A figure's declared model, with its harness and provenance."""

    figure: str
    model: str
    harness: str
    provenance: str


@dataclass(frozen=True)
class ModelRequest:
    """The fleet registry's answer to a human model request."""

    request: str
    resolved: bool
    harness: str = ""
    provider: str = ""
    model: str = ""
    locality: str = ""
    confidence: str = ""
    provenance: str = f"{MODEL_RESOLVE.as_posix()} (fleet registry)"


def _toon_row(text: str) -> tuple[list[str], list[str]] | None:
    """Read the first TOON row out of a door's output — header + one quoted line."""
    lines = (text or "").splitlines()
    for index, line in enumerate(lines):
        match = _TOON_HEADER.match(line.strip())
        if not match:
            continue
        columns = [cell.strip() for cell in match.group("cols").split(",") if cell.strip()]
        for follow in lines[index + 1 :]:
            follow = follow.strip()
            if not follow:
                continue
            if not follow.startswith('"'):
                break
            return columns, _TOON_CELL.findall(follow)
    return None


def _harness_for(model: str, document: Mapping[str, Any]) -> str:
    """The YAML's own local/online rule, applied to a declared model token."""
    harness = document.get("harness") or {}
    if not isinstance(harness, Mapping):
        harness = {}
    local_providers = {str(item) for item in (harness.get("local_providers") or [])}
    provider = model.split("/", 1)[0] if "/" in model else ""
    local = provider in local_providers
    name = (
        str(harness.get("local" if local else "online") or "")
        or str(document.get("default_harness") or "")
        or ("pi" if local else "opencode")
    )
    return name


class HoardModels:
    """The hoard's configured models, and the fleet's request resolver."""

    def __init__(
        self,
        *,
        root: str | Path | None = None,
        override: str | Path | None = None,
        env: Mapping[str, str] | None = None,
        runner: proc.Runner = proc.run,
    ) -> None:
        self._root = Path(root).expanduser() if root else None
        self._override = Path(override).expanduser() if override else None
        self._env = dict(env) if env is not None else None
        self._runner = runner

    @property
    def root(self) -> Path:
        """The CODE tree — where `bin/model/model-resolve.sh` and the schemas live."""
        return self._root or paths.resolve(self._env).root

    def _environ(self) -> dict[str, str]:
        return dict(os.environ) if self._env is None else dict(self._env)

    def config_path(self) -> Path:
        """`$YMIR_AGENTS_YAML` → the hoard's `config/agents.yaml` (Rule 07)."""
        if self._override is not None:
            return self._override
        explicit = self._environ().get("YMIR_AGENTS_YAML")
        if explicit:
            return Path(explicit).expanduser()
        return paths.resolve(self._env).config / "agents.yaml"

    # ── the configured road ──────────────────────────────────────────────────

    def configured(self, figure: str) -> Configured:
        """The figure's declared model and harness — or a refusal naming the key."""
        path = self.config_path()
        if not path.is_file():
            raise ModelUnavailable(
                f"no model is configured for '{figure}': {path} is absent",
                key=f"agents.{figure}.model",
                path=path,
                remedy="write config/agents.yaml under the operator's home (bin/fleet/agents-config.sh init) — the tree ships no model value",
            )
        try:
            document = load_config(path, kind="agents", root=self.root)
        except ConfigError as exc:
            raise ModelUnavailable(f"{path}: {exc}", key=f"agents.{figure}", path=path) from exc
        agents = document.get("agents") or {}
        if figure not in agents:
            raise ModelUnavailable(
                f"{path}: the hoard's agents.yaml names no agent '{figure}'",
                key=f"agents.{figure}",
                path=path,
                remedy="add the figure to config/agents.yaml, or choose a role whose figure the hoard knows",
            )
        spec = agents[figure]
        default_model = str(document.get("default_model") or "")
        declared_harness = ""
        if isinstance(spec, Mapping):
            model = str(spec.get("model") or default_model or "")
            declared_harness = str(spec.get("harness") or "")
        else:
            model = str(spec or default_model or "")
        if not model:
            raise ModelUnavailable(
                f"{path}: agent '{figure}' names no model and the hoard names no default_model",
                key=f"agents.{figure}.model",
                path=path,
                remedy="set the figure's model, or a default_model, in config/agents.yaml",
            )
        harness = declared_harness or _harness_for(model, document)
        return Configured(
            figure=figure,
            model=model,
            harness=harness,
            provenance=f"hoard {path} (agents.{figure})",
        )

    # ── the request road (delegated, never forked) ───────────────────────────

    def request(self, text: str) -> ModelRequest:
        """Resolve a model request through `bin/model/model-resolve.sh` and read its TOON."""
        door = self.root / MODEL_RESOLVE
        if not door.is_file():
            raise ModelUnavailable(
                f"the fleet registry door is absent: {door}",
                remedy="bin/model/model-resolve.sh ships with the code tree",
            )
        result = self._runner([str(door), "resolve", text], env=self._environ())
        if not proc.ok(result):
            detail = (result.stderr or "").strip() or "no reason given"
            raise ModelUnavailable(f"{door} resolve '{text}' failed: {detail}")
        row = _toon_row(result.stdout or "")
        if row is None:
            raise ModelUnavailable(f"{door} returned no readable resolution for '{text}'")
        columns, cells = row
        data = dict(zip(columns, cells))
        if data.get("resolution") == "unresolved" or data.get("ask") == "yes":
            return ModelRequest(request=text, resolved=False)
        return ModelRequest(
            request=text,
            resolved=True,
            harness=data.get("harness", ""),
            provider=data.get("provider", ""),
            model=data.get("model", ""),
            locality=data.get("locality", ""),
            confidence=data.get("confidence", ""),
        )

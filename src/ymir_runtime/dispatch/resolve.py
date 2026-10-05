"""`dispatch/resolve.py` — one errand, one resolution.

The whole point of the decision table: a single call answers, for one errand,
WHICH figure takes it, WHICH harness and model it wears, and WHICH seat type it
rides. Nothing is launched; `seat()` still owns the seat.

    role     the table's wiring          .agents/roles.yaml   (data)
    figure   the smith the role summons  .agents/roles.yaml   (data)
    tools    what that figure holds      .agents/roles.yaml   (data)
    model    the operator's own choice   $YMIR_HOME/config/agents.yaml (hoard)
    harness  the YAML's local/online rule (hoard)
    seat     herdr | utgard              the brief's own declaration

The seat type is not re-decided here: `container.declared_from_brief` owns the
`Isolation:` parse and this module reuses it, so one declaration cannot be read
two ways. An explicit `isolation` argument wins over the brief, exactly as the
engine's own `--isolation` flag does.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Mapping

from .. import container
from ..paths import resolve as resolve_paths
from .registry import HoardModels, ModelUnavailable
from .table import DEFAULT_ROLE, Role, Table, TableRefusal, read as read_table

KINDS = ("ship", "scout")
SEATS = ("herdr", "utgard")


@dataclass(frozen=True)
class Resolution:
    """The answer for one errand — the five links of the chain, with provenance."""

    role: str
    figure: str
    craft: str
    tools: tuple[str, ...]
    skills: tuple[str, ...]
    model: str
    harness: str
    effort: str
    seat: str
    kind: str
    provenance: Mapping[str, str] = field(default_factory=dict)

    def as_row(self) -> tuple[str, ...]:
        """The TOON row: role · figure · craft · tools · harness · model · seat · kind."""
        return (
            self.role,
            self.figure,
            self.craft,
            self.tools_cell(),
            self.harness,
            self.model,
            self.seat,
            self.kind,
        )

    def tools_cell(self) -> str:
        return " ".join(self.tools)


def resolve(
    *,
    role: str = "",
    task: str = "",
    brief: str = "",
    kind: str = "ship",
    effort: str = "",
    isolation: str = "",
    model_request: str = "",
    table: Table | None = None,
    models: HoardModels | None = None,
    root: str | Path | None = None,
    env: Mapping[str, str] | None = None,
) -> Resolution:
    """Resolve one errand to its role, figure, tools, model, harness and seat.

    `role` is a role key OR a figure name (the two names a caller speaks); when
    it is empty, `task` is scored against the table's keywords, exactly as the
    shell chooser does. `brief` supplies the `Isolation:` declaration; `kind` is
    `ship` or `scout`; `model_request` (when given) is resolved by the fleet's
    registry door instead of the hoard's configured model.
    """
    # One env, one root (Forseti, 2026-09-27): when a caller passes env but
    # no root, the table and the model registry must read the SAME root —
    # otherwise env can select the model config while os.environ selects the
    # table (the rootA/rootB divergence Forseti demonstrated).
    if root is None and env:
        root = resolve_paths(env).root

    if kind not in KINDS:
        raise TableRefusal(
            f"unsupported seat kind '{kind}' (supported: {', '.join(KINDS)})",
            key="kind",
        )
    if isolation and isolation not in SEATS:
        raise TableRefusal(
            f"unsupported isolation '{isolation}' (supported: {', '.join(SEATS)})",
            key="isolation",
        )

    resolved_table = table if table is not None else read_table(root=root)
    registry = models if models is not None else HoardModels(root=root, env=env)

    chosen, chooser_score = _choose(resolved_table, role=role, task=task)
    configured = registry.configured(chosen.figure)

    model, harness, model_provenance = configured.model, configured.harness, configured.provenance
    if model_request:
        requested = registry.request(model_request)
        if not requested.resolved:
            raise ModelUnavailable(
                f"the fleet registry could not resolve '{model_request}'",
                key="model",
                remedy="ask the Allfather, or run bin/model/model-resolve.sh list",
            )
        model = requested.model or model
        harness = requested.harness or harness
        model_provenance = requested.provenance

    seat = isolation or container.declared_from_brief(brief or "")[0]

    return Resolution(
        role=chosen.name,
        figure=chosen.figure,
        craft=chosen.craft,
        tools=chosen.tools,
        skills=chosen.skills,
        model=model,
        harness=harness,
        effort=effort or "",
        seat=seat,
        kind=kind,
        provenance={
            "role": f"{resolved_table.path} (roles.{chosen.name})",
            "figure": f"{resolved_table.path} (roles.{chosen.name}.figure)",
            "tools": f"{resolved_table.path} (roles.{chosen.name}.tools)",
            "model": model_provenance,
            "harness": model_provenance,
            "seat": "the brief's Isolation: declaration" if not isolation else "explicit --isolation",
            "chooser_score": str(chooser_score),
        },
    )


def _choose(table: Table, *, role: str, task: str) -> tuple[Role, int]:
    if role:
        return table.find(role), 0
    if task:
        return table.choose(task)
    raise TableRefusal(
        "no role and no task text — nothing to resolve",
        key="role",
        remedy=f"name a role or figure, or pass the errand text ({DEFAULT_ROLE} is the fallback smith)",
    )

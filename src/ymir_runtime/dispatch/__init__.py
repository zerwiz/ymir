"""dispatch — the decision table as PYTHON READING DATA (plan 58, Part 1).

Plan 58's Part 1 puts the rule plainly: *"a decision table belongs in data, not
in a 1000-line script."* This package is the one Python reader of that data and
the one place an errand is resolved to a **role → figure → tools → model →
seat**:

    table.py      `.agents/roles.yaml` (shipped, canonical): role -> figure,
                  craft, tools, keywords, dispatch — the WIRING, declared in data
    registry.py   the hoard's model, read at runtime from `$YMIR_HOME/config/
                  agents.yaml` (schema-validated); a model REQUEST is resolved by
                  the fleet's own door `bin/model-resolve.sh`, never re-implemented
    resolve.py    one errand -> one `Resolution`

The module is a LAYER beside the four verbs, exactly as the config layer is; it
does not launch anything. `seat()` still owns the seat — this decides WHICH
figure, harness, model and seat type the errand is for.

Two refusals are loud, and both name the key (the config layer's voice):

  * an unknown role or figure — `TableRefusal`, listing the names the table knows;
  * an absent hoard config — `ModelUnavailable`, naming `agents.<figure>.model`
    and the exact path, never a silent default.
"""

from __future__ import annotations

from .registry import Configured, HoardModels, ModelRequest, ModelUnavailable
from .resolve import Resolution, resolve
from .table import DEFAULT_ROLE, Role, Table, TableRefusal, read

__all__ = [
    "Configured",
    "DEFAULT_ROLE",
    "HoardModels",
    "ModelRequest",
    "ModelUnavailable",
    "Resolution",
    "Role",
    "Table",
    "TableRefusal",
    "read",
    "resolve",
]

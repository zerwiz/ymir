"""ymir_runtime — THE ENGINE. One deep module, four verbs.

    seat(errand)    -> seat_id      worktree + harness + backend + meta, all hidden
    status(seat_id) -> state        working | blocked | done | idle
    send(seat_id, text)             the data plane
    stop(seat_id)                   reap cleanly, no orphans

Everything a door needs is behind those four calls. A door (`bin/eindri-start.sh`,
`bin/einherjar-spawn.sh`) is a thin adapter: it hands an errand to `seat()` when
the engine can own it, and keeps the old road when the engine refuses — the
strangler is reversible by design until parity is proven.

Beside the verbs sits the config layer: `load_config(path)` returns a validated
config or refuses loudly, naming the key and the file (plan 58, Phase 7). It is a
support module, not a fifth verb. The grants law (`src/ymir_runtime/grants.py`) is
registered with it as the kind `grants`: a cross-operator grant without each
Heimdall's signature is refused (plan 58, *Several Ymirs, one company*).

Plan 58, Phase 1. Read `docs/fixes/runtime/` for what each release changed.
"""

from __future__ import annotations

from .config import ConfigError, ConfigUnavailable, ConfigValidationError, load_config
from .errors import EngineError, EngineRefusal, SeatNotFound
from .harness import HarnessSelection
from .seat import Errand, seat
from .send import SendResult, send
from .status import SeatState, status
from .stop import StopResult, stop
from .worktree import Worktree

__version__ = "1.1.0"

__all__ = [
    "ConfigError",
    "ConfigUnavailable",
    "ConfigValidationError",
    "Errand",
    "EngineError",
    "EngineRefusal",
    "HarnessSelection",
    "SeatNotFound",
    "SeatState",
    "SendResult",
    "StopResult",
    "Worktree",
    "__version__",
    "load_config",
    "seat",
    "send",
    "status",
    "stop",
]

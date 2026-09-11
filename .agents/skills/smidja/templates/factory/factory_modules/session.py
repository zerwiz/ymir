"""Session lifecycle: pin-or-create an factory_id, build the Run object.

`ensure(cfg, factory_id)` joins the session if it exists or creates it under
exactly that id (pinned ids for repeatable runs); omitted, a fresh id is
minted and printed so the next factory can pick it up.
"""

from __future__ import annotations

import os
import signal
import sys
from pathlib import Path

from .data_types import factoryConfig
from .runner import Run
from .tracer import Tracer
from .utils import engineer_name, new_id


def _finalize_when_killed(run: Run) -> None:
    """A killed run still closes its own trace.

    Python's default SIGTERM handling exits without unwinding, so `just kill`
    (or any `kill <pid>`) would leave the session reading `running` forever and
    its process rows open — the trace would claim work is in flight that is
    already dead. Turning the signal into SystemExit both finalizes here and
    lets the phase context manager record the phase as failed on the way out.
    """
    def handler(signum, _frame):
        run.tracer.session_finish(run.factory_id, ok=False)   # also closes process rows
        raise SystemExit(128 + signum)

    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, handler)


def ensure(cfg: factoryConfig, factory_id: str | None = None) -> Run:
    factory_id = factory_id or new_id(8)
    tracer = Tracer(cfg.observability.db,
                    f"{cfg.defaults.data_dir}/sessions/{factory_id}/events.jsonl")
    run = Run(cfg=cfg, factory_id=factory_id, tracer=tracer, engineer=engineer_name())
    tracer.session_start(factory_id, run.engineer, factory_name=Path(sys.argv[0]).stem)
    # This process is the run. Record it before any phase opens, so a run that
    # hangs in its first agent call is still killable by factory_id.
    tracer.process_start(factory_id, "factory", "", os.getpid(),
                         " ".join([Path(sys.argv[0]).name, *sys.argv[1:]]))
    _finalize_when_killed(run)
    run.console.session_started(factory_id, run.engineer)
    return run

"""send(seat_id, text) — the data plane, durable first.

A message to a seat is written to disk BEFORE it is spoken into the pane:
`<state>/<seat-id>.inbox/NNN.msg`, the same numbered inbox the supervisor already
uses. The pane poke is best effort — a seat whose pane has gone still receives
the message when it next reads its inbox, and the caller is told which of the two
actually happened.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Mapping

from . import backend as backend_mod
from . import heartbeat, paths, proc

INBOX_SUFFIX = ".inbox"


@dataclass(frozen=True)
class SendResult:
    seat_id: str
    message: Path
    poked: bool
    detail: str


def next_message(state: str | Path, seat_id: str) -> Path:
    """The next numbered message file for a seat, in the supervisor's own shape."""
    inbox = Path(state) / f"{seat_id}{INBOX_SUFFIX}"
    inbox.mkdir(parents=True, exist_ok=True)
    numbers = []
    for entry in inbox.iterdir():
        stem = entry.name.split(".", 1)[0]
        if entry.suffix == ".msg" and stem.isdigit():
            numbers.append(int(stem))
    return inbox / f"{(max(numbers) + 1) if numbers else 1:03d}.msg"


def send(
    seat_id: str,
    text: str,
    *,
    env: Mapping[str, str] | None = None,
    runner: proc.Runner = proc.run,
    probe=proc.which,
    poke: bool = True,
) -> SendResult:
    """Deliver text to a seated worker; returns where it landed."""
    environ = dict(env) if env is not None else None
    roots = paths.resolve(environ)
    state = roots.state

    message = next_message(state, seat_id)
    message.write_text(text.rstrip("\n") + "\n", encoding="utf-8")

    meta = heartbeat.read_meta(state, seat_id)
    target = meta.get("window", "")
    name = meta.get("backend", "")
    if not poke or not target or not name:
        return SendResult(seat_id, message, False, f"filed at {message} (no live target recorded)")

    seat = backend_mod.Seat(name, target, meta.get("seat_workspace", ""))
    if backend_mod.send_text(seat, text, env=environ, runner=runner, probe=probe):
        return SendResult(seat_id, message, True, f"delivered to {name}:{target}")
    return SendResult(seat_id, message, False, f"filed at {message} ({name}:{target} did not accept it)")

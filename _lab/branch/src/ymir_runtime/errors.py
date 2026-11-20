"""The engine's own failures, so a caller can tell them apart.

Three classes only, because a caller needs to decide one thing: may I keep
going, or must I hand this back to the old road (`bin/agents/einherjar-spawn.sh`)?

  EngineError     — the engine tried and failed.
  EngineRefusal   — the engine will NOT own this errand. The adapter keeps the
                    old road and says so; this is the strangler's hinge.
  SeatNotFound    — no seat record exists for the id.
"""

from __future__ import annotations


class EngineError(Exception):
    """A failure inside the engine."""


class EngineRefusal(EngineError):
    """The engine cannot own this errand — the caller must keep the old road.

    `reason` is the plain why; `remedy` is what would make the engine able to
    own it. Both are printed verbatim by the door, never swallowed.
    """

    def __init__(self, reason: str, remedy: str = "") -> None:
        super().__init__(reason)
        self.reason = reason
        self.remedy = remedy

    def __str__(self) -> str:  # pragma: no cover - trivial
        if self.remedy:
            return f"{self.reason} (remedy: {self.remedy})"
        return self.reason


class SeatNotFound(EngineError):
    """No seat record for this id."""

    def __init__(self, seat_id: str, state_path: str) -> None:
        super().__init__(f"no seat record for '{seat_id}' at {state_path}")
        self.seat_id = seat_id
        self.state_path = state_path

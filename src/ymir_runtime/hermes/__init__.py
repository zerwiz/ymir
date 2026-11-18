"""Ymir in Hermes — the seat, the doctor, the session hook and the worker wake (plan 317 §4–§5).

Every Hermes surface Ymir owns is written here, as typed Python with tests, instead of in the shell
scripts that seated it before (`bin/seat/hermes-seat.sh`, `bin/seat/hermes-session-hook.sh`), which
are now one-line launchers into this package.

    python3 -m ymir_runtime.hermes seat [--check] [--dry-run]
    python3 -m ymir_runtime.hermes doctor
    python3 -m ymir_runtime.hermes wait-worker [--session ID] [--worker NAME] [--once] [--foreground]
    python3 -m ymir_runtime.hermes session-hook          (Hermes' shell-hook wire: JSON on stdin)
"""

from __future__ import annotations

VERSION = "1.0.0"

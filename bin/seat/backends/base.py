#!/usr/bin/env python3
"""The six verbs a backend answers, and the one resolver that picks a backend.

WHY (plan 303 §14, 2026-11-16): herdr is not a tool the doors call ad hoc — it is a BACKEND
with six verbs, and `eindri-send.sh`, `eindri-notify.sh` and `msg-origin.sh` speak through
them. Hermes becomes the second backend with the same six verbs, so every door that reaches a
pane can reach a Hermes session without learning a new tool:

    verb      herdr                       hermes
    list      `herdr agent list`          `hermes sessions list` + the runtime's admissions
    get       `herdr agent get`           the session's own state
    read      `herdr agent read`          the tail of the session's transcript
    prompt    `herdr agent prompt`        `hermes chat --resume <id> -q <text> -Q`
    wait      `herdr agent wait`          poll `get` to the requested state
    explain   `herdr agent explain`       why it is paused, and the exact recovery

A target is written `herdr:<pane>`, `hermes:<session-id-or-title>`, or bare — and a bare target
is herdr, so nothing that works today changes shape.
"""

VERBS = ("list", "get", "read", "prompt", "wait", "explain")

# The ready vocabulary every backend answers in (plan 303 §12.3 step 1, §14).
READY, WORKING, BLOCKED, DEAD = 0, 1, 2, 3
WORD = {READY: "ready", WORKING: "working", BLOCKED: "blocked", DEAD: "dead"}


def word(state, reason=""):
    return "%s: %s" % (WORD[state], reason) if state == BLOCKED and reason else WORD[state]


class Backend:
    """One backend. A subclass answers every verb in `VERBS`, and nothing else is assumed."""

    name = "?"

    def list(self):            # -> [{name, harness, pane/target, state, detail}]
        raise NotImplementedError

    def get(self, target):     # -> (state, reason, detail)
        raise NotImplementedError

    def read(self, target, lines=40):
        raise NotImplementedError

    def prompt(self, target, text):   # -> a verb string, or "" when the prompt was refused
        raise NotImplementedError

    def wait(self, target, until=("working",), timeout=60):
        raise NotImplementedError

    def explain(self, target):  # -> (reason, recovery, detail)
        raise NotImplementedError

    def resolve(self, name):    # -> the canonical target this backend knows, or ""
        raise NotImplementedError

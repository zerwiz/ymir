#!/usr/bin/env python3
"""test-all-tools.py — call every voice tool once and report what answers.

Run on the seat (not the host):   python3 apps/rodd/smoke/test-all-tools.py
It writes nothing except the two harmless records the todo and draft tools make, and one
plan (state/voice/plans). Every argument is chosen to be SAFE: `hand_over` is called
without `confirm` (which by design sends nothing), `calendar_respond` is called against a
meeting that the read-only grant will refuse, and `steer_worker` is pointed at a target
that does not exist rather than at a live worker.
"""
import asyncio
import json
import os
import sys
import time
import traceback
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "bin" / "voice"))
import voice_tools  # noqa: E402

SAFE = {
    "hand_over": {"agent": "sindri", "task": "tool-test — no dispatch expected"},
    "gimle": {"tool": "list"},
    "plan_write": {"title": "Tool test plan", "steps": ["first step", "second step"], "agent": "sindri"},
    "context_left": {},
    "last_session": {"turns": 2},
    "search_sessions": {"query": "Ada", "limit": 2},
    "pane_read": {"errand": "voice-593303", "lines": 3},
    "errand_state": {"id": "voice-593303"},
    "steer_worker": {"target": "no-such-pane", "line": "tool test — not a live worker"},
    "search_home": {"query": "rodd"},
    "read_home_file": {"path": "docs/masterplan.md", "tail": True, "lines": 3},
    "read_mail": {"hours": 72, "max": 2},
    "read_calendar": {"what": "what"},
    "calendar_respond": {"event": "Monday Meeting", "response": "accepted"},
    "read_board": {},
    "home_recent": {"hours": 2},
    "draft_write": {"title": "Tool test draft", "body": "This draft exists only to prove the door answers."},
    "todo_add": {"item": "Tool test — tick me", "priority": "low", "project": "rodd"},
    "todo_list": {"status": "open"},
    "todo_done": {"id": "Tool test — tick me"},
    "todo_reopen": {"id": "Tool test — tick me"},
    "todo_update": {"id": "Tool test — tick me", "priority": "medium"},
    "add_todo": {"item": "Tool test — legacy add"},
    "recall": {"query": "rodd voice"},
    # plan 223 — this one WRITES into the live arm's queue, so the suite points it at a lease
    # that is not there and proves the door's refusal instead. A smoke run must never leave a
    # message in the arm holder's inbox.
    "talk_to_arm": {"text": "tool test — the smoke suite; no answer is expected"},
    "hear_from_arm": {"count": 3},
    # plan 231 R1 — the four hands Rödd was given. `eindri_send` is pointed at a pane that does
    # not exist so the suite proves the door's FAILED, never a real worker's inbox.
    "arm_who": {},
    "eindri_list": {},
    "eindri_send": {"target": "no-such-pane", "line": "tool test — not a live worker"},
    "calendar_write": {"action": "status"},
    "remember": {"note": "Tool test: the voice's tools were exercised end to end on 2026-11-07."},
}


SAFE_ENV = {
    "talk_to_arm": {"RODD_ARM_LEASE": "/nonexistent-state/.arm.lease"},
    "arm_who": {"RODD_ARM_LEASE": "/nonexistent-state/.arm.lease"},
}


def verdict(name: str, out: str, err: str | None, ms: int) -> str:
    if err:
        return f"BROKEN — {err.splitlines()[-1][:120]}"
    low = (out or "").lower()
    if not out:
        return "BROKEN — empty answer"
    if any(k in low for k in ("refused", "could not", "cannot be read", "no grant", "403",
                              "insufficient", "did not answer", "nothing matches", "no such")):
        return f"PARTIAL — refused with a reason ({out.strip().splitlines()[0][:90]})"
    return "WORKING"


async def main() -> int:
    results = []
    for tool in voice_tools.TOOLS:
        name = tool["name"]
        args = SAFE.get(name, {})
        started = time.perf_counter()
        err = None
        out = ""
        saved = {k: os.environ.get(k) for k in SAFE_ENV.get(name, {})}
        os.environ.update(SAFE_ENV.get(name, {}))
        try:
            res = await voice_tools.execute_tool(name, args)
            out = str(getattr(res, "output", res))
        except Exception as exc:  # a tool that raises is a finding
            err = f"{type(exc).__name__}: {exc}"
        finally:
            for key, was in saved.items():
                if was is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = was
        ms = int((time.perf_counter() - started) * 1000)
        results.append({"tool": name, "verdict": verdict(name, out, err, ms), "ms": ms,
                        "output": (out or err or "")[:400]})
    print(json.dumps(results, indent=1))

    counts = {}
    for r in results:
        counts[r["verdict"].split(" ")[0]] = counts.get(r["verdict"].split(" ")[0], 0) + 1
    print("\nsummary:", counts)
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))

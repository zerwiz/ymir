#!/usr/bin/env python3
"""herdr-agents.py — list the agents standing in this herdr session, as TOON.

Kept as its own file rather than an inline -c: the JSON shape has nested quotes
that are painful to escape inside a shell heredoc, and a separate file can be
tested on its own.

Usage: herdr-agents.py [--json]
"""
import json
import subprocess
import sys

TOON = "--json" not in sys.argv


def main() -> int:
    try:
        raw = subprocess.run(
            ["herdr", "agent", "list"],
            capture_output=True, text=True, timeout=15,
        ).stdout
        data = json.loads(raw)
    except Exception as exc:  # noqa: BLE001
        print(f"herdr-agents[1]{{state}}:\n  \"cannot read herdr agents ({exc})\"")
        return 1

    agents = (data.get("result") or {}).get("agents") or []
    if not TOON:
        print(json.dumps(agents, indent=2))
        return 0

    print(f"herdr-agents[{len(agents)}]{{kind,state,pane,cwd}}:")
    for a in agents:
        kind = a.get("agent") or "?"
        state = a.get("agent_status") or "unknown"
        pane = a.get("pane_id") or "?"
        cwd = a.get("cwd") or "?"
        print(f'  "{kind}","{state}","{pane}","{cwd}"')
    return 0


if __name__ == "__main__":
    sys.exit(main())

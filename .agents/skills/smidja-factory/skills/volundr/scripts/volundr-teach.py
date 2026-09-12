#!/usr/bin/env python3
"""volundr-teach.py — bulk-teach a project into Völundr's memory (wraps smidja teach).

Usage:
    volundr-teach.py <project> [--recon] [--root $YMIR_ROOT]

Reads the project's key files (AGENTS.md, CHANGELOG.md, deploy/start/stop
scripts, scripts/*.sh) and observes each into the engram — no agent tokens.
`--recon` additionally sends the 9b scout to map the codebase and observes the
findings. Thin wrapper around `scripts/smidja teach` so it always uses the
current launcher logic.
"""
import argparse
import os
import subprocess
import sys
from pathlib import Path

# skill lives at <root>/.agents/skills/smidja/skills/volundr/scripts/volundr-teach.py
ROOT = Path(__file__).resolve().parents[4]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("project", help="project name or path (prefers ~/CodeP/<name>)")
    ap.add_argument("--recon", action="store_true",
                    help="also run the 9b scout to map the codebase")
    ap.add_argument("--root", default=str(ROOT), help="command repo root")
    args = ap.parse_args()

    smidja = Path(args.root) / "scripts" / "smidja"
    if not smidja.exists():
        print(f"[kaia] no launcher at {smidja}", file=sys.stderr)
        return 1

    cmd = [str(smidja), "teach", args.project]
    if args.recon:
        cmd.append("--recon")
    print(f"[kaia] running: {' '.join(cmd)}")
    rc = subprocess.call(cmd)
    if rc != 0:
        print(f"[kaia] teach exited {rc}", file=sys.stderr)
    return rc


if __name__ == "__main__":
    sys.exit(main())
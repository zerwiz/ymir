#!/usr/bin/env python3
"""plan-claims.py — which plan files does a piece of text claim to serve?

The judge reviews a change against the plans it claims (RULES/08; the Allfather, 2026-11-21: the
judge did not see the plan). A claim is written in plain words — "plan 339", "plans 275, 277 and
279", "plan 206 §10.3a", or a path like `plans/339-the-gate.md` — in the PR body, in the branch's
fix note, or in the errand's brief. This door finds the numbers and answers with the plan FILES
(paths, never pasted text) from the plan ledgers of the operator's home.

  plan-claims.py <file> [<file> …]        text files to scan (the PR body, a fix note, a brief)
  plan-claims.py --stdin                  scan standard input
  plan-claims.py --ledgers DIR[:DIR…]     ledger folders to search (default: every plan shelf in the home)

Output, one line per plan, then a final line when a number has no file:
  <path of the plan file>
  unresolved: plan 339 (no file in the ledgers searched)

Exit: 0 always answered (an empty answer means no plan is claimed) · 2 usage.
"""

from __future__ import annotations

import glob
import os
import re
import subprocess
import sys
from pathlib import Path

# "plan 339", "plan-339", "plans 275, 277 and 279", "plan 206 §10.3a", "plan #12"
_CLAIM = re.compile(r"\bplans?[\s-]*#?(\d{1,4}(?:\s*(?:,|and|&|/)\s*#?\d{1,4})*)", re.I)
_NUMBER = re.compile(r"\d{1,4}")
_PATH = re.compile(r"plans/(\d{1,4})-[A-Za-z0-9._-]+\.md")


def numbers_in(text: str) -> list[int]:
    found: list[int] = []
    for match in _CLAIM.finditer(text):
        for n in _NUMBER.findall(match.group(1)):
            found.append(int(n))
    for match in _PATH.finditer(text):
        found.append(int(match.group(1)))
    seen: set[int] = set()
    ordered = []
    for n in found:
        if n not in seen:
            seen.add(n)
            ordered.append(n)
    return ordered


def home_root() -> Path | None:
    explicit = os.environ.get("YMIR_HOME")
    if explicit and Path(explicit).is_dir():
        return Path(explicit)
    here = Path(__file__).resolve().parents[2] / "bin" / "vault" / "hoard-lib.sh"
    if here.is_file():
        out = subprocess.run(
            ["bash", "-c", f'. "{here}" && ymir_home_root R && printf %s "$R"'],
            capture_output=True, text=True, timeout=30,
        )
        if out.returncode == 0 and out.stdout.strip():
            return Path(out.stdout.strip())
    return None


def ledgers(explicit: str = "") -> list[Path]:
    if explicit:
        return [Path(p) for p in explicit.split(":") if p]
    env = os.environ.get("YMIR_PLAN_LEDGERS", "")
    if env:
        return [Path(p) for p in env.split(":") if p]
    root = home_root()
    if root is None:
        return []
    return [Path(p) for p in sorted(glob.glob(str(root / "svartalfaheim" / "*" / "*" / "*" / "plans")))] + [
        Path(p) for p in sorted(glob.glob(str(root / "svartalfaheim" / "*" / "projects" / "*" / "plans")))
    ]


def plan_file(number: int, shelves: list[Path]) -> Path | None:
    for shelf in shelves:
        for pattern in (f"{number:03d}-*.md", f"{number}-*.md"):
            hits = sorted(shelf.glob(pattern))
            if hits:
                return hits[0]
    return None


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print((__doc__ or "").strip())
        return 0 if argv else 2
    texts: list[str] = []
    explicit = ""
    args = list(argv)
    while args:
        a = args.pop(0)
        if a == "--stdin":
            texts.append(sys.stdin.read())
        elif a == "--ledgers" and args:
            explicit = args.pop(0)
        else:
            try:
                texts.append(Path(a).read_text(encoding="utf-8", errors="replace"))
            except OSError:
                pass
    shelves = ledgers(explicit)
    numbers: list[int] = []
    for text in texts:
        for n in numbers_in(text):
            if n not in numbers:
                numbers.append(n)
    unresolved = []
    printed: set[str] = set()
    for n in numbers:
        path = plan_file(n, shelves)
        if path is None:
            unresolved.append(n)
        elif str(path) not in printed:
            printed.add(str(path))
            print(path)
    for n in unresolved:
        print(f"unresolved: plan {n} (no file in the ledgers searched)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

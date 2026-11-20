#!/usr/bin/env python3
"""woven_tail.py — a WOVEN file carries a HAND SECTION through, unchanged (RULES/06).

WHY (2026-11-20): `.agents/backend/README.md` is rebuilt by `bin/gates/inventory.sh`, and the
pre-commit hook re-weaves every woven file and stages it on every commit. A `## CHANGE LOG` a hand
appended to that page (2026-11-18, #825; 2026-11-19, #831) was erased by the NEXT commit, whatever
that commit was about — an append-only record lost by a generator that only knew how to overwrite.
The same would happen to any hand section on any woven page, so the rule lives here, once, and every
weaver calls it instead of writing its body straight over the file.

The shape of a woven file after this door:

    <generated body>
    <!-- woven:hand … -->
    <the hand section, byte for byte>

Two rules, and the order matters:

  1. A sentinel already in the file wins: everything after the LAST sentinel is the hand's, carried
     as it stands — even if it holds tables or TOON rows, which a generated page also holds.
  2. A file written before the sentinel existed is read by the older test: the LAST `## CHANGE LOG`
     heading, kept only when what follows it is the hand's prose and not generated rows. That is how
     `bin/README.md` — whose generated header carries a change-log paragraph of its own, with rows
     underneath — is told apart from a page a person appended to.

Usage:
  woven_tail.py tail <existing>                 # print the hand section (nothing when there is none)
  woven_tail.py write <existing> <generated>    # generated body + hand section -> <existing>
  woven_tail.py compose <generated> <existing>  # the composed text, to stdout
"""
from __future__ import annotations

import os
import re
import sys

SENTINEL = "<!-- woven:hand · everything below is carried through unchanged by the weaver (RULES/06) -->"

# What a GENERATED page holds: TOON rows indented two spaces, markdown table rows, and a TOON
# block header (`folders[42]{folder,what,index}:`). A hand section that opens with one of these is
# a generated section, not the hand's.
GEN_ROW = re.compile(r'^(?:\s{2}"|\||[A-Za-z_][A-Za-z0-9_]*\[\d+\]\{[^}]*\}:?\s*$)')
CHANGE_LOG = re.compile(r'^##[ \t]+CHANGE LOG[ \t]*$')


def hand_section(existing: str | None) -> str:
    """The hand's part of a woven file, or '' when it carries none."""
    if not existing:
        return ""
    lines = existing.splitlines()
    sentinels = [i for i, line in enumerate(lines) if line.strip() == SENTINEL]
    if sentinels:
        return "\n".join(lines[sentinels[-1] + 1:]).strip("\n")
    starts = [i for i, line in enumerate(lines) if CHANGE_LOG.match(line.strip())]
    if not starts:
        return ""
    tail = lines[starts[-1]:]
    if any(GEN_ROW.match(line) for line in tail[1:]):
        return ""  # a generated change log (a register's own header), never the hand's
    return "\n".join(tail).strip("\n")


def compose(generated: str, existing: str | None) -> str:
    """The generated body, with the hand section carried through below the sentinel."""
    body = generated.rstrip("\n") + "\n"
    hand = hand_section(existing)
    if not hand:
        return body
    return f"{body}\n{SENTINEL}\n\n{hand}\n"


def _read(path: str) -> str:
    with open(path, encoding="utf-8", newline="") as fh:
        return fh.read()


def _write(path: str, text: str) -> None:
    tmp = f"{path}.woven-tail.tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
    os.replace(tmp, path)


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[0] == "tail":
        sys.stdout.write(hand_section(_read(argv[1])))
        return 0
    if len(argv) == 3 and argv[0] == "write":
        existing_path, generated_path = argv[1], argv[2]
        existing = _read(existing_path) if os.path.exists(existing_path) else ""
        _write(existing_path, compose(_read(generated_path), existing))
        return 0
    if len(argv) == 3 and argv[0] == "compose":
        existing = _read(argv[2]) if os.path.exists(argv[2]) else ""
        sys.stdout.write(compose(_read(argv[1]), existing))
        return 0
    print("usage: woven_tail.py tail <existing> | write <existing> <generated> | compose <generated> <existing>",
          file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

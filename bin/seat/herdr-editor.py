#!/usr/bin/env python3
"""herdr-editor.py — read the INPUT BOX of an agent's pane, and say what is in it.

WHY. `herdr agent prompt` APPENDS to whatever already stands in the box, and no herdr verb
clears it (`pane send-keys` refuses `C-u`). So a door that types a brief without looking can
push the operator's half-written sentence out with the worker's. That cost the hall a wrong
brief and a stop on 2026-11-14 (`hodd/docs/runbooks/fleet-to-fleet-communication.md`), and
plan 293 part 5 makes the look part of the door rather than part of the runbook.

ONE READER, ONE QUESTION. Two harnesses draw the box two ways and both were measured on a
live pane (measured 2026-11-14 on a live pane of this hall):

  claude — the box is bounded by two full-width rules and its prompt line is `❯`:
      ─────────────…
      ❯
      ─────────────…
    ⏵⏵ auto mode on (shift+tab to cycle)

  pi — the box is the region between the status separator and the rule beneath it:
      ── ⠼ Working ─────…
      (the typed line, or nothing)
      ─────────────…   ← the last full-width rule, then the footer (path, tokens, "mesh:")

  The parser is the same for both: the LAST full-width rule is the box's bottom edge, the
  last decorated-or-plain rule above it is the top edge, and anything in between is what the
  operator (or a previous door) has put there.

Usage:
  herdr-editor.py <pane> [--lines N]        ask herdr for the pane's tail and judge it
  herdr-editor.py --stdin [--lines N]       judge text already read (a remote pane's tail)

Prints one TOON row:
  editor[1]{pane,verdict,text}:
    "w39:pW","text","have you done all we have been talking about"

verdict is `empty`, `text` or `unknown`. `unknown` is said out loud rather than guessed: a
box that could not be found is not an empty box, and the door prints it.
Exit: 0 judged (whatever the verdict) · 2 usage · 3 the pane could not be read.
"""
import json
import re
import subprocess
import sys

# A full-width rule: the box edges. Two of the frame characters is a separator; twenty is a rule.
RULE = re.compile(r'^\s*[─━]{20,}\s*$')
# A decorated rule above the box — pi draws its live status there ("── ⠼ Working ───…").
SEPARATOR = re.compile(r'^\s*[─━]{2,}.*[─━]{2,}\s*$')
# A prompt marker inside the box (claude-family). Box borders may sit on either side.
MARKER = re.compile(r'^\s*[│┃|]?\s*([❯›»>])\s?(.*)$')
# Trailing box border, and the footer lines that are never the box.
BORDER_TAIL = re.compile(r'[\s│┃|]+$')
FOOTER = re.compile(r'^(?:~|/|\$|↑|↓|mesh:|MCP:|merged|rebased)\b', re.I)
# More lines than this in the "box" means the box was not found and a transcript was caught.
MAX_BOX_LINES = 8


def _clean(line: str) -> str:
    return BORDER_TAIL.sub('', line).strip()


def judge(text: str) -> tuple:
    """→ (verdict, snippet). verdict ∈ empty · text · unknown."""
    lines = text.splitlines()
    bottom = max((i for i, l in enumerate(lines) if RULE.match(l)), default=-1)
    if bottom < 0:
        return 'unknown', ''
    top = max((i for i in range(bottom) if SEPARATOR.match(lines[i])), default=-1)
    if top < 0:
        return 'unknown', ''
    box = lines[top + 1:bottom]
    if len(box) > MAX_BOX_LINES:
        return 'unknown', ''
    kept = []
    for line in box:
        m = MARKER.match(line)
        kept.append(_clean(m.group(2)) if m else _clean(line))
    while kept and not kept[0]:
        kept.pop(0)
    while kept and not kept[-1]:
        kept.pop()
    kept = [l for l in kept if l and not FOOTER.match(l)]
    if not kept:
        return 'empty', ''
    snippet = ' '.join(kept).strip()
    return ('text', snippet)


def read_pane(pane: str, lines: int) -> str:
    try:
        raw = subprocess.run(['herdr', 'pane', 'read', pane, '--lines', str(lines)],
                             capture_output=True, text=True, timeout=20)
    except Exception as exc:  # noqa: BLE001
        print(f'herdr-editor: cannot read {pane} ({exc})', file=sys.stderr)
        raise SystemExit(3)
    if raw.returncode != 0:
        print(f'herdr-editor: cannot read {pane} ({raw.stderr.strip() or raw.returncode})', file=sys.stderr)
        raise SystemExit(3)
    return raw.stdout


def toon(pane: str, verdict: str, snippet: str) -> str:
    snippet = snippet.replace('\\', '\\\\').replace('"', '\\"')
    if len(snippet) > 160:
        snippet = snippet[:157] + '...'
    return f'editor[1]{{pane,verdict,text}}:\n  "{pane}","{verdict}","{snippet}"'


def main(argv: list) -> int:
    pane, lines, from_stdin = '', 40, False
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == '--lines' and i + 1 < len(argv):
            lines = int(argv[i + 1]); i += 2; continue
        if a == '--stdin':
            from_stdin = True; i += 1; continue
        if a in ('-h', '--help'):
            print(__doc__); return 0
        if a == '--json':
            pane = '-'; i += 1; continue
        if not pane:
            pane = a; i += 1; continue
        i += 1
    text = sys.stdin.read() if from_stdin else read_pane(pane, lines)
    verdict, snippet = judge(text)
    print(toon(pane or '-', verdict, snippet))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

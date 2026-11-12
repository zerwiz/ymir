#!/usr/bin/env python3
"""snotra-layout — a meeting folder is a standard, and a stray is a fault.

WHY: one folder carried four generations of the same letter (`email.md`, `framework-email.md`,
`feedback-email.md`, the engine's `followup-email.md`) and a `TEST-REPORT.md` nobody meant to leave. The
Allfather's word: **"no strays"**. A folder that accepts a fifth hand-built letter has no standard — it has
a habit.

THE STANDARD (top level, nothing else)
    the source      record.json · harvest.json · letters.json · promotions.jsonl
    the rendered    minutes.md · decisions.md · actions.md · questions.md · dependency-map.md ·
                    agenda-next.md · followup-email.md · followup-email.html · record.pdf · cards.json
    the shelves     briefs/ · letters/ · evidence/
    the manifest    README.md · PROVENANCE.md
    the declared state (named, owned, allowed)
                    trello.json (the board projection state) · dispatch.json (mail drafts) ·
                    signoffs.json · planner.json · classification.yaml · timestamp/ · access.jsonl

    everything else is a STRAY — including a second copy of a document the engine already renders.

WHAT IT DOES
    check  <meeting-dir>   classify every file: standard · state · evidence · stray — exit 1 on a stray
    apply  <meeting-dir>   MOVE each stray into `evidence/hand-built/` (never delete, Rule 11), note it in
                           PROVENANCE.md, and re-check
    list   <meeting-dir>   the same as check, one line per file
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

STANDARD = {
    "record.json", "harvest.json", "letters.json", "promotions.jsonl",
    "minutes.md", "decisions.md", "actions.md", "questions.md", "dependency-map.md",
    "agenda-next.md", "followup-email.md", "followup-email.html", "record.pdf", "cards.json",
    "README.md", "PROVENANCE.md",
    "transcript.md",           # the engine's rendered source transcript
    "signoff.md",              # read by snotra-signoff.sh and snotra-render-pdf.sh — a real document
    "email.md", "email.html",  # written by snotra-render-email.sh — the door's own output, not a stray
}
SHELVES = {"briefs", "letters", "evidence"}
STATE = {"trello.json", "dispatch.json", "signoffs.json", "planner.json", "classification.yaml",
         "access.jsonl", "timestamp"}
EVIDENCE_TOP = {"segments.json", "candidates.json", "review.json", "provenance.json", "provenance.jsonl"}


def die(msg: str, code: int = 1):
    print(f"snotra-layout: {msg}", file=sys.stderr)
    raise SystemExit(code)


def say(msg: str):
    print(msg, flush=True)


def classify(d: Path) -> list[tuple[str, str, Path]]:
    out = []
    for p in sorted(d.iterdir()):
        name = p.name
        if p.is_dir():
            kind = "shelf" if name in SHELVES else ("state" if name in STATE else "stray")
        elif name in STANDARD:
            kind = "standard"
        elif name in STATE:
            kind = "state"
        elif name in EVIDENCE_TOP:
            kind = "evidence"
        else:
            kind = "stray"
        out.append((kind, name, p))
    return out


def show(d: Path, rows: list[tuple[str, str, Path]]) -> int:
    from collections import Counter
    c = Counter(k for k, _n, _p in rows)
    for kind, name, p in rows:
        if kind == "stray":
            size = p.stat().st_size if p.is_file() else 0
            say(f"stray{{file:{name},bytes:{size}}}")
    say(f"layout{{dir:{d.name},standard:{c.get('standard', 0)},shelves:{c.get('shelf', 0)},"
        f"state:{c.get('state', 0)},evidence:{c.get('evidence', 0)},strays:{c.get('stray', 0)}}}")
    return 1 if c.get("stray") else 0


def git_mv(repo_hint: Path, src: Path, dst: Path) -> bool:
    r = subprocess.run(["git", "-C", str(repo_hint), "mv", str(src), str(dst)],
                       capture_output=True, text=True)
    if r.returncode == 0:
        return True
    dst.parent.mkdir(parents=True, exist_ok=True)
    try:
        shutil.move(str(src), str(dst))
        return True
    except OSError as exc:
        say(f"move_failed{{from:{src.name},why:{exc}}}")
        return False


def apply(d: Path) -> int:
    rows = classify(d)
    strays = [p for k, _n, p in rows if k == "stray"]
    if not strays:
        say(f"layout{{dir:{d.name},strays:0,verdict:'nothing to move'}}")
        return 0
    dest_dir = d / "evidence" / "hand-built"
    dest_dir.mkdir(parents=True, exist_ok=True)
    moved = []
    for p in strays:
        dest = dest_dir / p.name
        if dest.exists():
            stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
            dest = dest_dir / f"{p.stem}.{stamp}{p.suffix}"
        if git_mv(d, p, dest):
            moved.append((p.name, dest.name))
            say(f"moved{{file:{p.name},to:evidence/hand-built/{dest.name}}}")
    if moved and (d / "PROVENANCE.md").exists():
        with open(d / "PROVENANCE.md", "a", encoding="utf-8") as f:
            f.write(f"\n## Strays moved to `evidence/hand-built/` — "
                    f"{datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}\n\n")
            f.write("Nothing was deleted (Rule 11). These sat beside the engine's rendered set — a second\n"
                    "and third copy of the same document, and a test artefact — so they moved to the\n"
                    "evidence shelf where improvising belongs.\n\n")
            for src_name, dst_name in moved:
                f.write(f"- `{src_name}` → `evidence/hand-built/{dst_name}`\n")
    say(f"layout{{dir:{d.name},moved:{len(moved)}}}")
    return 0 if len(moved) == len(strays) else 1


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    cmd = argv[1]
    d = Path(argv[2]).expanduser().resolve()
    if not d.is_dir():
        die(f"no meeting folder at {d}")
    if cmd == "check":
        return show(d, classify(d))
    if cmd == "list":
        return show(d, classify(d))
    if cmd == "apply":
        return apply(d)
    die(f"unknown command {cmd!r} — check | apply | list", 2)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))

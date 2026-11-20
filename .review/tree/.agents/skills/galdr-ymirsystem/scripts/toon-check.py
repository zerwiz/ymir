#!/usr/bin/env python3
"""toon-check — validate Token-Oriented Object Notation (TOON) blocks.

Galdr-style CLI: TOON output on stdout, structured errors, no prompts, --version
fast path, definitive empty states.

Usage:
  toon-check.py [paths...] [--quiet] [--json]
  toon-check.py --version | -v

For every TOON table block  TYPE[COUNT]{F1,F2,...}:  this checks that
  - exactly COUNT data rows follow (2-space or tab indented, before a blank line), and
  - every row has exactly len(F1,F2,...) comma-separated fields (quotes respected).

Exit: 0 = clean, 1 = violations, 2 = usage error.
"""
from __future__ import annotations

import json
import os
import re
import sys

VERSION = "1.0.0"
HEADER = re.compile(r"^(?P<indent>[ \t]*)(?P<name>[A-Za-z_][\w-]*)\[(?P<count>\d+)\]\{(?P<fields>[^}]*)\}:[ \t]*$")
ROW = re.compile(r"^(?P<indent>[ \t]+)(?P<body>\S.*?)[ \t]*$")


def split_fields(row: str) -> list[str]:
    """Split a TOON/CSV row on commas that are not inside double quotes."""
    fields: list[str] = []
    cur = ""
    in_quotes = False
    i = 0
    while i < len(row):
        ch = row[i]
        if ch == '"':
            if in_quotes and i + 1 < len(row) and row[i + 1] == '"':
                cur += '"'
                i += 2
                continue
            in_quotes = not in_quotes
            cur += ch
        elif ch == "," and not in_quotes:
            fields.append(cur.strip())
            cur = ""
        else:
            cur += ch
        i += 1
    fields.append(cur.strip())
    return fields


def scan_file(path: str) -> list[dict]:
    try:
        with open(path, "r", encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except OSError:
        return []

    blocks: list[dict] = []
    i = 0
    while i < len(lines):
        m = HEADER.match(lines[i])
        if not m:
            i += 1
            continue
        declared = int(m.group("count"))
        expected = [f.strip() for f in m.group("fields").split(",") if f.strip() != ""]
        rows: list[list[str]] = []
        elided = False
        j = i + 1
        while j < len(lines):
            raw = lines[j]
            if raw.strip() == "":
                break
            rm = ROW.match(raw)
            if not rm:
                break
            body = rm.group("body")
            if body.strip() == "...":
                elided = True
                j += 1
                continue
            rows.append(split_fields(body))
            j += 1
        blocks.append(
            {
                "file": path,
                "type": m.group("name"),
                "declared": declared,
                "actual": len(rows),
                "cols": len(expected),
                "row_cols": sorted({len(r) for r in rows}),
                "line": i + 1,
                "elided": elided,
            }
        )
        i = j
    return blocks


def status(block: dict) -> str:
    if block.get("elided"):
        return "ELIDED"
    if block["actual"] != block["declared"]:
        return "COUNT_MISMATCH"
    bad = [c for c in block["row_cols"] if c != block["cols"]]
    if bad:
        return "COLS_MISMATCH"
    return "PASS"


def emit(rows: list[dict], quiet: bool, as_json: bool) -> None:
    if as_json:
        print(json.dumps(rows, indent=2))
        return
    if not rows:
        print("toon_blocks: 0 TOON blocks found")
        return
    if not quiet:
        print(f"toon_blocks[{len(rows)}]{{file,type,line,declared,actual,cols,status}}:")
        for r in rows:
            print(
                f'  "{r["file"]}",{r["type"]},{r["line"]},{r["declared"]},'
                f'{r["actual"]},{r["cols"]},"{r["status"]}"'
            )


def main(argv: list[str]) -> int:
    if any(a in ("-v", "-V", "--version") for a in argv):
        print(VERSION)
        return 0
    if any(a in ("-h", "--help") for a in argv):
        print(__doc__.strip())
        return 0

    quiet = "--quiet" in argv
    as_json = "--json" in argv
    paths = [a for a in argv if not a.startswith("-")]
    if not paths:
        print("error: no paths given")
        print("help: toon-check.py <file-or-dir> [...] [--quiet] [--json]")
        return 2
    for p in paths:
        if not os.path.exists(p):
            print(f"error: path not found: {p}")
            print("help: pass a Markdown file or a directory to scan")
            return 2

    files: list[str] = []
    for p in paths:
        if os.path.isdir(p):
            for root, _dirs, names in os.walk(p):
                for n in names:
                    if n.endswith(".md"):
                        files.append(os.path.join(root, n))
        else:
            files.append(p)

    rows: list[dict] = []
    for f in sorted(files):
        rows.extend(scan_file(f))
    for r in rows:
        r["status"] = status(r)

    emit(rows, quiet, as_json)
    bad = [r for r in rows if r["status"] not in ("PASS", "ELIDED")]
    if bad:
        print("")
        for r in bad:
            if r["status"] == "COUNT_MISMATCH":
                print(
                    f'error: {r["file"]}:{r["line"]} {r["type"]}[{r["declared"]}] '
                    f'declares {r["declared"]} rows but has {r["actual"]}'
                )
            else:
                print(
                    f'error: {r["file"]}:{r["line"]} {r["type"]} rows have '
                    f'{r["row_cols"]} fields, header has {r["cols"]}'
                )
        print("help: fix the TOON block header count/fields to match the rows")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

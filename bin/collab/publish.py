#!/usr/bin/env python3
"""publish.py — the baton on the board: what is next and what is blocked become cards.

    collab.sh publish <repo> [--project ID] [--yes] [--dry-run]

It reads `handoff/CURRENT.md` — section 3 (what is next) and section 4 (what is blocked, and on whom) — and
creates one card per bullet on the project's board, **idempotently by title**: a card that is already there is
skipped, so running it twice adds nothing.

The board is reached through the **board contract** (plan 335, "the split"), never one engine's API. The
project's row in the home's registry (`$YMIR_HOME/hodd/identity/projects.yaml`) names its board in a `board:`
block — the same block `plan-sync.sh` reads — and the adapter it names answers the verbs. Today that is the
`mcp` adapter (bin/boards/board_adapter_mcp.py): any board that speaks the contract over MCP, given a URL and a
token reference. Ymir carries no engine here; the board behind the URL decides what a place and a state are.

Cards are labelled `baton` and open in the contract's `unstarted` group. Each carries its source
(`handoff/CURRENT.md#s3-<n>`), so a board that asks where an agent's card came from is told.

It never creates a project or a place: a board place is a decision, not a side effect. A project with no
`board:` block is refused by name.

Exit: 0 published or clean dry run · 1 refused or failed · 2 usage.
"""
import argparse
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "bin", "boards"))
from board_adapter_mcp import BoardRefusal  # noqa: E402
import plan_sync  # noqa: E402  (the registry reader and the board builder, one copy of each)

LABEL = "baton"


def die(message, code=1):
    print("publish: %s" % message, file=sys.stderr)
    sys.exit(code)


def home():
    h = os.environ.get("YMIR_HOME", "")
    if not h:
        door = os.path.join(ROOT, "bin", "vault", "hodd.sh")
        try:
            hoard = subprocess.run(["bash", door, "path"], capture_output=True, text=True, timeout=15).stdout.strip()
        except Exception:
            hoard = ""
        h = os.path.dirname(hoard) if hoard else ""
    if not h:
        die("no home — set YMIR_HOME, or make bin/vault/hodd.sh path answer")
    return h


def section(text, number):
    """The bullets of `## <number> · ...`, stopping at the next `## `."""
    match = re.search(r"^## %d · .*$" % number, text, re.MULTILINE)
    if not match:
        return []
    rest = text[match.end():]
    following = re.search(r"^## ", rest, re.MULTILINE)
    body = rest[: following.start()] if following else rest
    bullets = []
    for line in body.splitlines():
        line = line.strip()
        if line.startswith(("- ", "* ")):
            bullets.append(line[2:].strip())
        elif re.match(r"^\d+\.\s", line):
            bullets.append(re.sub(r"^\d+\.\s+", "", line).strip())
    return bullets


def title_of(bullet, limit=120):
    text = re.sub(r"\s+", " ", bullet).strip()
    return text if len(text) <= limit else text[: limit - 1].rstrip() + "…"


def main():
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("repo")
    parser.add_argument("--project", default="", help="the registry id (default: the repository's folder name)")
    parser.add_argument("--yes", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    baton = os.path.join(os.path.abspath(args.repo), "handoff", "CURRENT.md")
    if not os.path.isfile(baton):
        die("no baton at %s — write one with handoff/check.sh --new" % baton)
    with open(baton, encoding="utf-8") as handle:
        text = handle.read()

    date = re.search(r"\*\*Date:\*\*\s*(\d{4}-\d{2}-\d{2})", text)
    date = date.group(1) if date else "unknown"

    wanted = [("next", 3, i, b) for i, b in enumerate(section(text, 3), 1)] + \
             [("blocked", 4, i, b) for i, b in enumerate(section(text, 4), 1)]
    if not wanted:
        die("the baton's sections 3 and 4 carry no bullets — nothing to publish")

    write = args.yes and not args.dry_run
    name = args.project or os.path.basename(os.path.abspath(args.repo))
    try:
        row = plan_sync.load_project(home(), name)
        place, board = plan_sync.build_board(home(), row)
        if write:
            board.ensure_label(LABEL)
        created, skipped = [], []
        for kind, sec, n, bullet in wanted:
            title = title_of(bullet)
            # by title, labelled or not: a card published before the label existed still counts as there
            if any(c["title"] == title for c in board.find_cards(None, title[:60])):
                skipped.append(title)
                continue
            if write:
                board.create_card(title,
                                  "From handoff/CURRENT.md §%d, baton of %s." % (sec, date),
                                  "unstarted", [LABEL], source="handoff/CURRENT.md#s%d-%d" % (sec, n))
            created.append(title)
    except BoardRefusal as exc:
        die(str(exc))

    verb = "created" if write else "would create"
    print("publish[5]{field,value}:")
    print('  "repo","%s"' % os.path.abspath(args.repo))
    print('  "board","%s (%s adapter)"' % (place, (row.get("board") or {}).get("adapter", "?")))
    print('  "baton","%s"' % date)
    print('  "cards","%s %d, skipped %d (already there)"' % (verb, len(created), len(skipped)))
    print('  "mode","%s"' % ("written through the board contract" if write else "dry run"))
    for title in created:
        print('  "card","%s"' % title)
    if not (args.dry_run or args.yes):
        print("publish: nothing was written — pass --yes to write")
    return 0


if __name__ == "__main__":
    sys.exit(main())

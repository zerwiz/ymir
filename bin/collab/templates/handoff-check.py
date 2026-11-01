#!/usr/bin/env python3
"""handoff/check.sh — the baton: is it there, complete, fresh, and honest about the paths it names?

This file is COPIED INTO THE PROJECT IT GUARDS by `bin/collab/collab.sh init`, so it must run with
nothing but python3 in the repository it sits in. It has no dependency on Ymir being installed.

    handoff/check.sh                      check the baton (default)
    handoff/check.sh --check [--max-age-days N]
    handoff/check.sh --new --from <name> [--to <name>] [--note "one line"]

It fails when the baton is missing, a section is missing, the date is absent or older than the limit,
the branch or the deployment is unnamed, a backticked path it names does not exist, or handoff/log/ is
empty. The seven sections are fixed by handoff/TEMPLATE.md; the check reads the headings.

Exit: 0 clean · 1 a problem · 2 usage.
"""
import argparse
import datetime
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CURRENT = os.path.join(HERE, "CURRENT.md")
TEMPLATE = os.path.join(HERE, "TEMPLATE.md")
LOG_DIR = os.path.join(HERE, "log")

SECTIONS = [
    "## 1 · Where we are",
    "## 2 · What is done",
    "## 3 · What is next",
    "## 4 · What is blocked, and on whom",
    "## 5 · How to verify the current state",
    "## 6 · Read first",
    "## 7 · Traps",
]

# A backticked path is checked only when it names a file under a known shelf. `tickets/047` is a
# number, not a path, and must never fail the gate.
SHELVES = ["apps", "bench", "bin", "config", "docs", "handoff", "infra", "lib", "priv", "rel",
           "scripts", "src", "tests", "tickets"]
PATH_RE = re.compile(r"`((?:%s)/[A-Za-z0-9._/-]+\.[a-z]+)`" % "|".join(SHELVES))
DATE_RE = re.compile(r"\*\*Date:\*\*\s*(\d{4}-\d{2}-\d{2})")


def check(max_age_days):
    problems = []
    if not os.path.isfile(CURRENT):
        return ["handoff/CURRENT.md does not exist — write one with `handoff/check.sh --new --from <name>`"]

    with open(CURRENT, encoding="utf-8") as handle:
        text = handle.read()

    for section in SECTIONS:
        if section not in text:
            problems.append("handoff/CURRENT.md: missing section `%s`" % section)

    match = DATE_RE.search(text)
    if not match:
        problems.append("handoff/CURRENT.md: no `**Date:**` line — a baton without a date cannot be known to be current")
    else:
        try:
            written = datetime.date.fromisoformat(match.group(1))
            age = (datetime.date.today() - written).days
            if age > max_age_days:
                problems.append("handoff/CURRENT.md: the baton is %d days old (limit %d) — write a new one"
                                % (age, max_age_days))
        except ValueError:
            problems.append("handoff/CURRENT.md: `**Date:** %s` is not a date" % match.group(1))

    for field in ("Branch", "Deployed"):
        if "**%s:**" % field not in text:
            problems.append("handoff/CURRENT.md: no `**%s:**` line — the baton says where the work is, "
                            "not what it was like" % field)

    named = sorted(set(PATH_RE.findall(text)))
    for path in named:
        if not os.path.exists(os.path.join(ROOT, path)):
            problems.append("handoff/CURRENT.md: names `%s`, which does not exist" % path)

    if not os.path.isdir(LOG_DIR) or not [f for f in os.listdir(LOG_DIR) if f.endswith(".md")]:
        problems.append("handoff/log/ is empty — the baton has no history")

    return problems


def git(args):
    try:
        out = subprocess.run(["git"] + args, cwd=ROOT, capture_output=True, text=True, check=True)
        return out.stdout.strip()
    except Exception:
        return "unknown"


def write_new(origin, to, note):
    if not os.path.isfile(TEMPLATE):
        sys.exit("handoff/TEMPLATE.md does not exist — the baton has no shape to be written into")
    with open(TEMPLATE, encoding="utf-8") as handle:
        body = handle.read()
    stamp = datetime.datetime.now(datetime.timezone.utc).isoformat()
    body = (body.replace("<from> → <to>", "%s → %s" % (origin, to))
                .replace("<ISO date>", stamp)
                .replace("<branch>", git(["rev-parse", "--abbrev-ref", "HEAD"]))
                .replace("<sha>", git(["rev-parse", "--short", "HEAD"])))
    if note:
        body += "\n> %s\n" % note

    os.makedirs(LOG_DIR, exist_ok=True)
    slug = re.sub(r"[^a-z0-9-]", "-", origin.lower())
    record = os.path.join(LOG_DIR, "%s-%s.md" % (datetime.date.today().isoformat(), slug))
    for path in (record, CURRENT):
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(body)
    print("handoff: wrote %s and refreshed handoff/CURRENT.md" % os.path.relpath(record, ROOT))
    print("handoff: fill in the seven sections before you stop — the check refuses an empty one")


def main():
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--new", action="store_true")
    parser.add_argument("--from", dest="origin", default="the previous hand")
    parser.add_argument("--to", dest="to", default="whoever continues")
    parser.add_argument("--note", default="")
    parser.add_argument("--max-age-days", type=int,
                        default=int(os.environ.get("HANDOFF_MAX_AGE_DAYS", "14")))
    args = parser.parse_args()

    if args.new:
        write_new(args.origin, args.to, args.note)
        return 0

    problems = check(args.max_age_days)
    for problem in problems:
        print("handoff: %s" % problem, file=sys.stderr)
    if problems:
        print("handoff: %d problem(s)" % len(problems), file=sys.stderr)
        return 1
    print("handoff: complete, dated, fresh, and every path it names exists")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env bash
# changelog-assemble.sh — fold CHANGELOG.d/ fragments into CHANGELOG.md.
#
# WHY THIS EXISTS
#   CHANGELOG.md is one file, and every branch appends at the same position — the
#   top. Git sees two branches inserting different lines at the same spot and
#   calls it a conflict, so every merge re-conflicts every open branch. With N
#   branches that is O(N^2) conflicts, all of them meaningless.
#
#   A fragment directory removes the collision at the root: each change adds ONE
#   file with a UNIQUE name, so two branches never touch the same file and can
#   never conflict. This script folds the fragments into the ledger.
#
# THE LAW (RULES/06-append-only.md)
#   Append, never rewrite. Never truncate. Never lose one in a move.
#   A fragment is a new file; the ledger only ever grows. Folding is an append.
#   CHANGELOG.d/ joins the append-only set, so a move must carry it.
#
# FRAGMENT FORMAT
#   CHANGELOG.d/<YYYY-MM-DD>-<slug>.md — the entry exactly as it should appear in
#   CHANGELOG.md, starting with its `## YYYY-MM-DD — title` heading.
#
# USAGE
#   bin/changelog-assemble.sh              # fold every fragment, newest first
#   bin/changelog-assemble.sh --dry-run    # report what would fold
#   bin/changelog-assemble.sh --check      # exit 1 if fragments are unfolded
#
# Exit: 0 ok, 1 error (or --check with fragments present), 2 usage.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRAG_DIR="$ROOT/CHANGELOG.d"
LEDGER="$ROOT/CHANGELOG.md"

DRY=0; CHECK=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --check)   CHECK=1 ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/changelog-assemble.sh [--dry-run|--check]\n' "$a" >&2; exit 2 ;;
  esac
done

[ -f "$LEDGER" ] || { printf 'error: no ledger at %s\n' "$LEDGER" >&2; exit 1; }

# One python block owns the whole fold: regex, ordering, and the ledger's
# structure are all easier to get right in one language than split across awk,
# sed and shell — and an awk interval regex silently matched nothing, which
# duplicated the entire ledger.
ROOT="$ROOT" FRAG_DIR="$FRAG_DIR" LEDGER="$LEDGER" DRY="$DRY" CHECK="$CHECK" python3 - <<'PY'
import os, re, sys, glob

root = os.environ["ROOT"]
frag_dir = os.environ["FRAG_DIR"]
ledger = os.environ["LEDGER"]
dry = os.environ["DRY"] == "1"
check = os.environ["CHECK"] == "1"

HEADING = re.compile(r"^## (\d{4}-\d{2}-\d{2}) ")

# --- fragments -------------------------------------------------------------
frags = []
if os.path.isdir(frag_dir):
    for p in sorted(glob.glob(os.path.join(frag_dir, "*.md"))):
        if os.path.basename(p) == "README.md":
            continue
        frags.append(p)

if not frags:
    if check:
        sys.exit(0)
    print('changelog-assemble[1]{fragments,folded,state}:')
    print('  "0","0","none pending"')
    sys.exit(0)

# A fragment must begin with its dated heading, or folding it would corrupt the
# ledger's structure.
bad = []
for p in frags:
    first = open(p, encoding="utf-8").readline()
    if not HEADING.match(first):
        bad.append(os.path.relpath(p, root))
if bad:
    for b in bad:
        print(f'error: fragment has no dated heading: {b}', file=sys.stderr)
    print('help: first line must be "## YYYY-MM-DD — title"', file=sys.stderr)
    sys.exit(1)

def frag_date(p):
    m = re.match(r"^(\d{4}-\d{2}-\d{2})", os.path.basename(p))
    return m.group(1) if m else "0000-00-00"

# newest first; ties broken by name for determinism
frags.sort(key=lambda p: (frag_date(p), os.path.basename(p)), reverse=True)

if check:
    print(f'changelog-assemble[{len(frags)}]{{fragment,state}}:')
    for p in frags:
        print(f'  "{os.path.relpath(p, root)}","unfolded"')
    print(f'error: {len(frags)} changelog fragment(s) not folded into CHANGELOG.md', file=sys.stderr)
    print('help: run bin/changelog-assemble.sh', file=sys.stderr)
    sys.exit(1)

if dry:
    print(f'changelog-assemble[{len(frags)}]{{fragment,date}}:')
    for p in frags:
        print(f'  "{os.path.relpath(p, root)}","{frag_date(p)}"')
    print('changelog-assemble: dry run — nothing written')
    sys.exit(0)

# --- the ledger ------------------------------------------------------------
text = open(ledger, encoding="utf-8").read()
lines = text.split("\n")

# preamble = everything before the first dated entry (the `# CHANGELOG` head)
split = None
for i, ln in enumerate(lines):
    if HEADING.match(ln):
        split = i
        break
if split is None:
    preamble = lines[:]          # no dated entry yet: the whole file is preamble
    existing = []
else:
    preamble = lines[:split]
    existing = lines[split:]

# trim trailing blanks from the preamble, then one blank separator
while preamble and preamble[-1].strip() == "":
    preamble.pop()

# --- assemble: fragments first (newest at top), then the existing ledger ----
out = list(preamble)
out.append("")
for p in frags:
    body = open(p, encoding="utf-8").read().rstrip("\n").split("\n")
    out.extend(body)
    out.append("")
    out.append("")
out.extend(existing)

# collapse runs of 3+ blank lines to two (entry separation only — never content)
t = "\n".join(out)
t = re.sub(r"\n{3,}", "\n\n", t).rstrip("\n") + "\n"

open(ledger, "w", encoding="utf-8").write(t)
for p in frags:
    os.remove(p)

print('changelog-assemble[1]{fragments,folded,ledger}:')
print(f'  "{len(frags)}","{len(frags)}","CHANGELOG.md"')
PY

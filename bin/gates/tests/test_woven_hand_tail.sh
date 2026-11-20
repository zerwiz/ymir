#!/usr/bin/env bash
# test_woven_hand_tail.sh — a WOVEN page carries a hand section through (RULES/06).
#
# Why this test exists: `.agents/backend/README.md` is rebuilt by bin/gates/inventory.sh and
# re-woven by the pre-commit hook on EVERY commit, so a `## CHANGE LOG` a person appended (2026-11-18,
# #825; 2026-11-19, #831) was erased by the next commit, whatever that commit was about. Measured on
# this branch: commit 30a65576 — an unrelated gates fix — deleted the 2026-11-19 entry.
#
# The rule is one door (bin/records/woven_tail.py) and this asserts every case it must tell apart:
# a page with no hand section, a legacy hand section with no sentinel, a sentinel already written
# (whose hand part may hold tables and TOON rows), and a register whose GENERATED header carries a
# `## CHANGE LOG` of its own with rows underneath — that one must not be mistaken for the hand's.
#
#   bin/gates/tests/test_woven_hand_tail.sh
#
# Exit: 0 every case holds · 1 a case failed (each printed by name).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DOOR="$ROOT/bin/records/woven_tail.py"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
rc=0
ok()  { printf '  ok   %s\n' "$*"; }
bad() { printf '  FAIL %s\n' "$*"; rc=1; }

command -v python3 >/dev/null || { echo "python3 is required"; exit 1; }
[ -f "$DOOR" ] || { echo "missing $DOOR"; exit 1; }

SENTINEL="$(python3 "$DOOR" tail /dev/null >/dev/null 2>&1; python3 -c "
import sys; sys.path.insert(0, '$ROOT/bin/records'); import woven_tail; print(woven_tail.SENTINEL)")"

# compose <generated> <existing> -> stdout
compose() {
  printf '%s' "$1" > "$TMP/gen.md"
  printf '%s' "$2" > "$TMP/existing.md"
  python3 "$DOOR" compose "$TMP/gen.md" "$TMP/existing.md"
}

printf 'a page with nothing appended is the generated body\n'
gen='# page

row[1]{a,b}:
  "1","2"'
out="$(compose "$gen" "$gen")"
if [ "$out" = "$gen" ]; then ok 'no hand section: the body is written as it is'
else bad "no hand section changed the body:
$out"; fi

printf 'a legacy hand section (written before the sentinel existed) is carried\n'
existing="$gen
## CHANGE LOG

- 2026-11-18 — a hand appended this
- 2026-11-19 — and this
"
out="$(compose "$gen" "$existing")"
case "$out" in
  *"$SENTINEL"*) ok 'the sentinel marks where the hand section begins' ;;
  *) bad "no sentinel in the written page: $out" ;;
esac
case "$out" in
  *"2026-11-18 — a hand appended this"*) ok 'the first hand entry survives' ;;
  *) bad "the 2026-11-18 entry was lost" ;;
esac
case "$out" in
  *"2026-11-19 — and this"*) ok 'the second hand entry survives' ;;
  *) bad "the 2026-11-19 entry was lost" ;;
esac
out2="$(compose "$gen" "$out")"
if [ "$out2" = "$out" ]; then ok 'a second weave changes nothing (the tail is stable)'
else bad "the tail is not stable across two weaves:
--- first
$out
--- second
$out2"; fi

printf 'a sentinel already written carries ANY hand content, tables included\n'
hand="$SENTINEL

## CHANGE LOG

| date | what |
|---|---|
| 2026-11-20 | a table in the hand section |

- and a TOON-looking line
  \"quoted\",\"row\"
"
existing="$gen
$hand"
out="$(compose "$gen" "$existing")"
case "$out" in
  *"| 2026-11-20 | a table in the hand section |"*) ok 'a table in the hand section survives' ;;
  *) bad 'the hand table was dropped' ;;
esac
case "$out" in
  *'"quoted","row"'*) ok 'a row-shaped hand line survives (the sentinel wins)' ;;
  *) bad 'a row-shaped hand line was mistaken for generated content' ;;
esac

printf 'a register whose GENERATED header owns a CHANGE LOG is not the hand\n'
# bin/README.md's shape: the header explains its own change log, then generated rows follow.
existing='# bin/ — front door

## CHANGE LOG

Every run rewrites this file from the tree; there is no hand-kept content here.

folders[2]{folder,what,index}:
  "forge","the doors of this folder","bin/forge/INDEX.md"'
out="$(compose "$gen" "$existing")"
if [ "$out" = "$gen" ]; then ok 'a generated change-log header is not carried'
else bad "a generated change-log header was carried as the hand's:
$out"; fi

printf 'the door writes the file, and a later weave keeps the hand\n'
# end to end: write <existing> <generated>, then read the page back
printf '%s' "$gen" > "$TMP/gen.md"
printf '%s' "$gen
## CHANGE LOG

- 2026-11-20 — the entry the hook used to erase
" > "$TMP/page.md"
python3 "$DOOR" write "$TMP/page.md" "$TMP/gen.md"
python3 "$DOOR" write "$TMP/page.md" "$TMP/gen.md"
if grep -qF '2026-11-20 — the entry the hook used to erase' "$TMP/page.md"; then
  ok 'the entry survives two writes, byte for byte'
else
  bad "the entry was lost by a second write: $(cat "$TMP/page.md")"
fi

[ "$rc" = 0 ] && printf 'all cases hold\n'
exit "$rc"

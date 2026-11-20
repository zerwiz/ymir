#!/usr/bin/env bash
# subsystem-docs-guard.sh — the books a subsystem names must exist, and every governed path must name books.
#
# Written 2026-10-23, at the Allfather's word: "this can never happend that we are missing this for the
# smidja ever again." A rule that says "read the books" is decoration if the map of books can rot.
#
# It refuses two things:
#   1. a map row naming a book that does not exist (a dead pointer is worse than no pointer);
#   2. a governed path in AGENTS.md with no row in the map (the gap that cost the night).
#
#   subsystem-docs-guard.sh check   # the ward
#   subsystem-docs-guard.sh         # alias
#
# Exit: 0 clean · 1 findings · 2 usage.
set -u
VERSION="1.0.0"
_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
}
ROOT="$(_root)"
MAP="$ROOT/.agents/assets/agents/subsystem-docs.md"
WHERE="$ROOT/bin/records/where.sh"

case "${1-}" in
  -v|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  check|"") ;;
  *) printf 'error: unknown action %s\nhelp: subsystem-docs-guard.sh [check]\n' "${1-}" >&2; exit 2 ;;
esac

fail=0
if [ ! -r "$MAP" ]; then
  printf 'subsystem-docs-guard[1]{finding,detail}:\n  "no map","%s is missing — nothing routes a hand to a subsystem book"\n' "${MAP#"$ROOT"/}"
  exit 1
fi
if [ ! -x "$WHERE" ]; then
  printf 'subsystem-docs-guard[1]{finding,detail}:\n  "no door","bin/records/where.sh is missing — the map cannot be asked"\n'
  exit 1
fi

# 1 · the map's own promises
if ! out="$("$WHERE" --check 2>&1)"; then
  printf 'subsystem-docs-guard[1]{finding,detail}:\n  "the map names a book that does not exist","%s"\n' \
    "$(printf '%s' "$out" | grep -E '^  "' | head -1 | cut -c1-160)"
  fail=1
fi

# 2 · every governed path in AGENTS.md has a row.
#     Scoped to the ONE block (`governed[N]{path,load_first}:` … ```), because a scan of every quoted
#     row in AGENTS.md also catches the voice bounds, the laws and the outputs table — measured: it
#     reported 30 "governed paths" that are prose.
missing=""
while IFS= read -r gov; do
  [ -n "$gov" ] || continue
  printf '%s' "$gov" | tr '|' '\n' | while IFS= read -r probe; do
    probe="$(printf '%s' "$probe" | sed -E 's/^ +| +$//g; s/\*.*$//')"
    [ -n "$probe" ] || continue
    case "$probe" in *,*) continue ;; esac
    "$WHERE" "$probe" >/dev/null 2>&1 || printf '%s\n' "$probe"
  done
done < <(awk '/^governed\[[0-9]+\]\{/{f=1;next} f&&/^```/{f=0} f' "$ROOT/AGENTS.md" \
         | grep -E '^  "' | sed -E 's/^  "([^"]+)".*/\1/') > /tmp/subsys-missing.$$
missing="$(tr '\n' ' ' < /tmp/subsys-missing.$$ | sed -E 's/ +$//')"
rm -f /tmp/subsys-missing.$$

if [ -n "$missing" ]; then
  printf 'subsystem-docs-guard[1]{finding,detail}:\n  "a governed path names no books","%s"\n' "$(printf '%s' "$missing" | cut -c1-160)"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  printf 'subsystem-docs-guard[1]{finding,detail}:\n  "none","every mapped path names books that exist, and every governed path is mapped"\n'
  exit 0
fi
printf 'help: add or fix the row in .agents/assets/agents/subsystem-docs.md — a path with no book is how a night gets lost\n' >&2
exit 1

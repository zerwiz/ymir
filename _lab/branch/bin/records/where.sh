#!/usr/bin/env bash
# where.sh — "which book do I read before touching this path?"
#
# Written 2026-10-23 after a night of missed critical information: the authoritative docs for several
# subsystems live INSIDE an app (apps/*/SKILL.md, AGENTS.md, cookbooks/, skills/, docs/, references/), so
# no inventory of bin/ ever surfaces them and nothing in the contract sent a hand to them. Twice in one
# night a claim was made from the tree that the subsystem's own book contradicted.
#
#   where.sh apps/smidja            the entry skill, the canonical doc, the books, the doors, what is missing
#   where.sh "the smithy"           the same, by topic
#   where.sh --check                every row's entry + canonical doc exists (or is marked —)
#   where.sh --list                 every mapped subsystem, one line each
#
# The map is ONE file: .agents/assets/agents/subsystem-docs.md. A path with no row is a GAP, and the
# door says so — the ward (`bin/gates/guards/subsystem-docs-guard.sh`) checks the map itself.
#
# Exit: 0 found/clean · 1 no row / a stale map · 2 usage.
set -uo pipefail
VERSION="1.0.0"
_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
}
ROOT="$(_root)"
MAP="$ROOT/.agents/assets/agents/subsystem-docs.md"

case "${1-}" in
  -v|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; [ -n "${1-}" ] && exit 0 || exit 2 ;;
esac
[ -r "$MAP" ] || { printf 'where: the map is missing: %s\n' "${MAP#"$ROOT"/}" >&2; exit 1; }

rows() { grep -E '^  "' "$MAP"; }

# One row's six fields, split on the TOON separator. A sed chain on a quoted row truncated one field
# into all of them (measured); the row is data, so it is split as data.
split_row() {
  python3 -c 'import sys; print("\x1f".join(p.strip().strip(chr(34)) for p in sys.argv[1].split(chr(34)+","+chr(34))))' "$1"
}

if [ "${1-}" = "--list" ]; then
  printf 'subsystems[%s]{path,entry}:\n' "$(rows | wc -l)"
  while IFS= read -r line; do
    IFS=$'\x1f' read -r paths entry _rest < <(split_row "$line")
    printf '  "%s","%s"\n' "$paths" "$entry"
  done < <(rows)
  exit 0
fi

if [ "${1-}" = "--check" ]; then
  bad=0; findings=""
  while IFS= read -r line; do
    IFS=$'\x1f' read -r paths entry canon _books _doors _miss < <(split_row "$line")
    for f in "$entry" "$canon"; do
      case "$f" in ""|"—") continue ;; esac
      [ -e "$ROOT/$f" ] || { findings="${findings}  \"a book the map names does not exist\",\"${paths}\",\"${f}\""$'\n'; bad=$((bad+1)); }
    done
  done < <(rows)
  if [ "$bad" -eq 0 ]; then
    printf 'subsystem-docs: clean — every mapped path names books that exist (%s rows)\n' "$(rows | wc -l)"
    exit 0
  fi
  printf 'subsystem-docs[%d]{finding,path,detail}:\n' "$bad"
  printf '%s' "$findings"
  exit 1
fi

# Match by PREFIX, not only by substring: the map's path field is a set of globs (`bin/engine/**`), and a
# query for one door (`bin/engine/ymir-engine.sh`) is not a substring of its own row.
match_row() {
  python3 -c '
import sys
q = sys.argv[1].strip().lower()
for line in sys.stdin.read().splitlines():
    if not line.startswith("  \""):
        continue
    path = line.split("\",\"")[0].strip().lstrip("\"")
    for pat in path.split("|"):
        p = pat.strip().rstrip("*").rstrip("/").lower()
        if p and (q.startswith(p) or p.startswith(q.rstrip("/")) or q in line.lower()):
            print(line)
            raise SystemExit
' "$1"
}

q="$*"
hit=$(rows | match_row "$q")
if [ -z "$hit" ]; then
  printf 'where[1]{asked,result,help}:\n  "%s","no row in .agents/assets/agents/subsystem-docs.md","add the row — the subsystem, its entry skill, its canonical doc, its books, its doors, and what is missing — or ask with a path that is mapped"\n' "$q"
  exit 1
fi

IFS=$'\x1f' read -r paths entry canon books doors miss < <(split_row "$hit")
printf 'where[1]{matches,entry,canonical,books,doors,missing}:\n'
printf '  "%s","%s","%s","%s","%s","%s"\n' "$paths" "$entry" "$canon" "$books" "$doors" "${miss:--}"
printf '\nRead the entry skill FIRST, then the canonical doc, then the cookbook the task matches (RULES/36).\n'

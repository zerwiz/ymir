#!/usr/bin/env bash
# rules-number-guard.sh — the house law is NUMBERED, so no two rules may share a number,
# and the index must agree with the disk.
#
# The fault this answers (2026-10-18): two branches each wrote `RULES/22-…`. The second
# landed as a duplicate 22 and only a human eye noticed. A rule that is numbered twice is
# not a rule; it is two documents arguing about the same number.
#
# It also refuses a rules INDEX that has drifted: a file on disk with no row, a row with
# no file, or a count that does not match. The index is how an agent finds the law.
#
# Usage: rules-number-guard.sh check [root]
#        rules-number-guard.sh --list
#        rules-number-guard.sh --version
# Exit: 0 clean · 1 a finding · 2 usage.  Root override for a test: YMIR_GUARD_ROOT.
set -u

VERSION="1.0.0"

_root() {
  local d; d="$(cd "${1:-$(dirname "${BASH_SOURCE[0]}")}" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/RULES" ] && [ -d "$d/bin" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$d"
}

CHECK="check"; ROOTARG=""
case "${1:-check}" in
  --version) printf 'rules-number-guard %s\n' "$VERSION"; exit 0 ;;
  --list)    CHECK="list" ;;
  check)     ;;
  *)         ROOTARG="${1:-}"; ;;
esac
[ "${2:-}" = "" ] || ROOTARG="$2"

ROOT="${YMIR_GUARD_ROOT:-$(_root "$ROOTARG")}"
RULES="$ROOT/RULES"
[ -d "$RULES" ] || { printf 'rules-number-guard[1]{finding,detail}:\n  "no RULES directory","%s"\n' "$RULES" >&2; exit 2; }

mapfile -t FILES < <(find "$RULES" -maxdepth 1 -type f -name '[0-9][0-9]-*.md' -printf '%f\n' | sort)
[ "${CHECK}" = "list" ] && { printf '%s\n' "${FILES[@]}"; exit 0; }

findings=0
say() { printf 'rules-number-guard[1]{finding,rule,detail}:\n  "%s","%s","%s"\n' "$1" "$2" "$3"; findings=$((findings+1)); }

# 1 · no number used twice
declare -A SEEN=()
for f in "${FILES[@]}"; do
  n="${f%%-*}"
  if [ -n "${SEEN[$n]:-}" ]; then
    say "a rule number used twice" "$n" "$f and ${SEEN[$n]}"
  else
    SEEN[$n]="$f"
  fi
done

# 2 · the index must name every file, and only files that exist
INDEX="$RULES/README.md"
if [ -r "$INDEX" ]; then
  for f in "${FILES[@]}"; do
    grep -q "$f" "$INDEX" || say "a rule with no index row" "$f" "the index is how an agent finds the law — add it to RULES/README.md"
  done
  # every numbered file named in the index must exist on disk
  while IFS= read -r named; do
    [ -n "$named" ] || continue
    [ -f "$RULES/$named" ] || say "an index row with no file" "$named" "the index names a rule that does not exist"
  done < <(grep -oE '[0-9]{2}-[a-z0-9-]+\.md' "$INDEX" 2>/dev/null | sort -u)
  # the toon count, when present, must match the disk
  declared="$(sed -nE 's/^rules_index\[([0-9]+)\].*/\1/p' "$INDEX" | head -1)"
  if [ -n "$declared" ] && [ "$declared" != "${#FILES[@]}" ]; then
    say "the index count is stale" "rules_index[$declared]" "the disk holds ${#FILES[@]} rules"
  fi
fi

if [ "$findings" -eq 0 ]; then
  printf 'rules-number-guard: clean — %s numbered rules, no duplicates, index agrees\n' "${#FILES[@]}"
  exit 0
fi
printf 'rules-number-guard: %s finding(s)\nhelp: a rule number is claimed once; pick the next free number and add its README row in the same change\n' "$findings" >&2
exit 1

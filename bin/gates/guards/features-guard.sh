#!/usr/bin/env bash
# features-guard.sh — every feature page is catalogued (Rule 14).
#
# The user's front door is FEATURES.md (the master catalogue) + docs/features/
# (the how-tos). A page that is not listed in the catalogue is a page no user will
# find — so this ward refuses a `docs/features/*.md` that FEATURES.md does not
# name. It does not require a feature to HAVE a page (that is a debt Rule 14 names);
# it requires that any page which exists be reachable.
#
#   features-guard.sh            # check
#   features-guard.sh --all      # same
#
# Exit: 0 every page is catalogued · 1 one is not · 2 usage.
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

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  check|--all|"") ;;
  *) printf 'error: unknown action %s\nhelp: features-guard.sh [check|--all]\n' "${1-}" >&2; exit 2 ;;
esac

CATALOGUE="$ROOT/FEATURES.md"
printf 'features-guard[3]{finding,page,catalogue}:\n'
if [ ! -f "$CATALOGUE" ]; then
  printf '  "the catalogue is missing","FEATURES.md","%s"\n' "$CATALOGUE"
  printf 'features-guard: FEATURES.md does not exist\nhelp: the master catalogue is required (Rule 14)\n' >&2
  exit 1
fi

missing=0
for f in "$ROOT"/docs/features/*.md; do
  [ -e "$f" ] || continue
  base="$(basename "$f")"
  [ "$base" = "README.md" ] && continue
  if ! grep -q "docs/features/$base" "$CATALOGUE"; then
    printf '  "a feature page is not in the catalogue","docs/features/%s","FEATURES.md"\n' "$base"
    missing=$((missing + 1))
  fi
done
if [ "$missing" -eq 0 ]; then
  printf '  "none","","every feature page is catalogued"\n'
  exit 0
fi
printf 'features-guard: %s feature page(s) are not listed in FEATURES.md\nhelp: add a row to FEATURES.md pointing at the page (Rule 14)\n' "$missing" >&2
exit 1

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
  # `check` is the DEFAULT: a bare invocation must judge, never print help and pass
  # vacuously (measured 2026-11-04: no argument matched this branch first and exited 0).
  -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  check|--all|"") ;;
  *) printf 'error: unknown action %s\nhelp: features-guard.sh [check|--all]\n' "${1-}" >&2; exit 2 ;;
esac

# BUILT, NOT VERSIONED (plan 243 part A, 2026-11-11). FEATURES.md left git: it is WOVEN from
# docs/features/_catalogue/entries/ by bin/records/weave-features.sh wherever it is read, so a
# branch never conflicts on it and a stale copy on main never refuses a push. The ward judges
# the SOURCE: every feature page must be named by a catalogue fragment, and the fragments must
# weave. The merge driver for FEATURES.md is retired with the tracked copy.
FRAGS="$ROOT/docs/features/_catalogue/entries"
printf 'features-guard[3]{finding,page,catalogue}:\n'
if [ ! -d "$FRAGS" ]; then
  printf '  "the catalogue fragments are missing","docs/features/_catalogue/entries","%s"\n' "$FRAGS"
  printf 'features-guard: no catalogue fragments\nhelp: the master catalogue is woven from them (Rule 14)\n' >&2
  exit 1
fi

missing=0
for f in "$ROOT"/docs/features/*.md; do
  [ -e "$f" ] || continue
  base="$(basename "$f")"
  [ "$base" = "README.md" ] && continue
  if ! grep -qs "docs/features/$base" "$FRAGS"/*.md; then
    printf '  "a feature page is not in the catalogue","docs/features/%s","docs/features/_catalogue/entries/"\n' "$base"
    missing=$((missing + 1))
  fi
done

stale=0
_wt="$(mktemp -d)"
if ! YMIR_WEAVE_OUT="$_wt/FEATURES.md" bash "$ROOT/bin/records/weave-features.sh" >/dev/null 2>&1; then
  printf '  "the catalogue does not weave","docs/features/_catalogue/","bin/records/weave-features.sh failed on the fragments"\n'
  stale=$((stale + 1))
fi
rm -rf "$_wt"
if [ "$missing" -eq 0 ] && [ "$stale" -eq 0 ]; then
  printf '  "none","","every feature page is catalogued, and the woven catalogue is current"\n'
  exit 0
fi
printf 'features-guard: %s finding(s) — %s page(s) uncatalogued, %s stale/driver fault(s)\nhelp: add the row to its section fragment in docs/features/_catalogue/, then run bin/records/weave-features.sh (Rule 14 · Þættir)\n' "$((missing + stale))" "$missing" "$stale" >&2
exit 1

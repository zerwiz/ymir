#!/usr/bin/env bash
# ymir-update-check.sh — does a newer Ymir stand on npm? One answer, cached daily.
#
# The CLI tells the USER when a newer package is on the shelf (bin/ymir.js). The
# RUNTIME had no such sense: a session could run for days on an old tree and
# never know a fix had shipped — so Brokk could not offer to update, and the
# Allfather had to remember to look. This is the runtime's own sense of drift.
#
#   bin/ymir-update-check.sh            # report; exit 3 when newer stands
#   bin/ymir-update-check.sh --force    # ignore the day's cache
#
# The answer is cached one day (state/update-check) so a session start is not a
# network call every time. Never fatal: no network, no npm, no answer — silence,
# at exit 0.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
hoard_state_dir _HS 2>/dev/null
# Resolve-or-refuse. The code tree's state/ is never a fallback (Rule 04; the
# plan's purity row is exactly this drift). The home resolves first, always.
STATE="${BROKK_STATE_OVERRIDE:-${_HS:-}}"
if [ -z "$STATE" ]; then
  printf 'error: the state dir did not resolve\nhelp: source bin/hoard-lib.sh (it resolves the home), or set BROKK_STATE_OVERRIDE\n' >&2
  exit 1
fi

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
FORCE=0
[ "${1-}" = "--force" ] && FORCE=1

# This tree's version — the package.json that owns this script.
have="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$ROOT/package.json" 2>/dev/null)"
[ -n "$have" ] || exit 0

stamp="$STATE/update-check"
today="$(date -u +%Y-%m-%d)"
if [ "$FORCE" != "1" ] && [ -r "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null | head -n1 | tr -d '[:space:]')" = "$today" ]; then
  exit 0
fi

latest=""
if command -v curl >/dev/null 2>&1; then
  latest="$(curl -s -m 3 https://registry.npmjs.org/@zerwiz/ymir/latest 2>/dev/null \
    | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("version",""))
except Exception: pass' 2>/dev/null)"
fi
[ -n "$latest" ] || exit 0   # no network, no npm: silence, never an error

mkdir -p "$STATE" 2>/dev/null && printf '%s %s\n' "$today" "$latest" >"$stamp" 2>/dev/null || true

if [ "$latest" = "$have" ]; then
  printf 'ymir-update-check[1]{you,latest,state}:\n  "%s","%s","current"\n' "$have" "$latest"
  exit 0
fi

printf 'ymir-update-check[1]{you,latest,state,how}:\n  "%s","%s","newer stands","npm i -g @zerwiz/ymir  (then: ymir groa)"\n' "$have" "$latest"
exit 3

#!/usr/bin/env bash
# lower.sh — the whole house in one word: the windows first, then the web.
#
# The shells are lowered BEFORE the services, so no window is left watching a
# port that has just gone away. That order is the whole point of owning both
# lifecycles in one place.
#
#   scripts/lower.sh              # every shell + the services
#   scripts/lower.sh --desktop    # the shells only
#   scripts/lower.sh --web        # the services only
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WHAT="all"
case "${1-}" in
  --web) WHAT=web ;;
  --desktop) WHAT=desktop ;;
  -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

if [ "$WHAT" != "web" ]; then
  printf '\n— the windows —\n'
  if [ -x "$ROOT/bin/sessrumnir.sh" ]; then
    "$ROOT/bin/sessrumnir.sh" stop || printf 'lower: sessrumnir did not stop cleanly\n' >&2
  fi
  "$ROOT/scripts/electron.sh" stop || printf 'lower: electron.sh stop reported errors\n' >&2
fi

if [ "$WHAT" != "desktop" ]; then
  printf '\n— the web —\n'
  "$ROOT/scripts/stop.sh" || printf 'lower: stop.sh reported errors\n' >&2
fi

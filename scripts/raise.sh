#!/usr/bin/env bash
# raise.sh — the whole house in one word: the web AND the windows.
#
# scripts/start.sh raises the services; scripts/electron.sh raises the desktop
# shells. Two lifecycles that never met — which is why "the electrons are not
# running" was true while 28 processes stood, and why a web restart left the
# shells pointing at a dead port. This is the pair of hands.
#
#   scripts/raise.sh              # services + every desktop shell
#   scripts/raise.sh --web        # the services only
#   scripts/raise.sh --desktop    # the shells only
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WHAT="all"
case "${1-}" in
  --web) WHAT=web ;;
  --desktop) WHAT=desktop ;;
  -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

if [ "$WHAT" != "desktop" ]; then
  printf '\n— the web —\n'
  "$ROOT/scripts/start.sh" || printf 'raise: start.sh reported errors\n' >&2
fi

if [ "$WHAT" != "web" ]; then
  printf '\n— the windows —\n'
  # Every shell, by name: hlidskjalf is the default view; smidja and odrerir need
  # their own start; sessrumnir is its own app.
  "$ROOT/scripts/electron.sh" start || printf 'raise: hlidskjalf failed\n' >&2
  for v in smidja odrerir; do
    "$ROOT/scripts/electron.sh" start --view "$v" || printf 'raise: %s failed\n' "$v" >&2
  done
  if [ -x "$ROOT/bin/sessrumnir.sh" ]; then
    "$ROOT/bin/sessrumnir.sh" start || printf 'raise: sessrumnir failed\n' >&2
  fi
  printf '\n'
  "$ROOT/scripts/electron.sh" status
fi

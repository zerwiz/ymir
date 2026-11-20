#!/usr/bin/env bash
# fleet-version-guard.sh — the three labels and the two trees must agree, or say so.
#
# Rule: RULES/05 (one portable core) and RULES/34 §4 (a check that runs nowhere is absent).
#
# Measured 2026-10-23, and the reason this ward exists: the tree, the global install and npm
# ALL said `0.1.53`, so `bin/fleet/fleet-version.sh` said "in sync" — while the installed copy
# was 24 days old and missing 155 doors, 22 rules and every one of the 69 feature pages. A
# label-agreement check cannot see a content drift; `fleet-version.sh` now measures content,
# and this ward calls it on every push.
#
# A machine with NO global copy (every CI runner) is a clean SKIP — probe, never assume
# (RULES/25). A skip is not a pass, and the row says so in words.
#
#   fleet-version-guard.sh check   # the ward
#   fleet-version-guard.sh         # alias for check
#
# Exit: 0 agree/skip · 1 drift · 2 usage.
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
FV="$ROOT/bin/fleet/fleet-version.sh"

case "${1-}" in
  -v|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  check|"") ;;
  *) printf 'error: unknown action %s\nhelp: fleet-version-guard.sh [check]\n' "${1-}" >&2; exit 2 ;;
esac

if [ ! -r "$FV" ]; then
  printf 'fleet-version-guard[1]{finding,detail}:\n  "no door","bin/fleet/fleet-version.sh is missing — the versions cannot be judged"\n'
  exit 1
fi

if out="$(bash "$FV" check 2>&1)"; then
  case "$(printf '%s' "$out" | sed -n 's/.*"verdict","\([^"]*\)".*/\1/p' | head -1)" in
    "in sync")
      printf 'fleet-version-guard[1]{finding,detail}:\n  "none","tree, install and publish agree — labels AND content"\n' ;;
    "ahead")
      printf 'fleet-version-guard[1]{finding,detail}:\n  "none","the tree is ahead of npm — a RELEASE is owed, not a repair: %s"\n' \
        "$(printf '%s' "$out" | sed -n 's/.*"content","\([^"]*\)","\([^"]*\)".*/\1: \2/p' | head -1 | cut -c1-120)" ;;
    *)
      printf 'fleet-version-guard[1]{finding,detail}:\n  "none","no global copy to compare — a clean skip, not a pass"\n' ;;
  esac
  exit 0
fi

# Drift: carry up the door's own line rather than inventing a message.
printf 'fleet-version-guard[1]{finding,detail}:\n  "the installed house is not the tree","%s"\n' \
  "$(printf '%s' "$out" | grep -E '"(verdict|content)"' | tail -1 | cut -c1-180)"
printf 'help: npm i -g @zerwiz/ymir@latest (or remove the global copy if this checkout is the canon); then bump and publish, because a republished number freezes the channel\n' >&2
exit 1

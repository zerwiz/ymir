#!/usr/bin/env bash
# launchd-layer.sh — both macOS service-layer tests, in one door (plan 293).
#
#   bin/gates/checks/launchd-layer.sh            # quiet: prints nothing when both hold
#   bin/gates/checks/launchd-layer.sh --verbose  # every case, as the tests print them
#
# The two suites, and why each exists:
#   bin/engine/tests/test_launchd_user.py       the renderer and the verbs, against a fake HOME and a
#                                              fake launchctl — a register entry in, a launchd plist out
#   bin/engine/tests/test_launchd_step_skips.sh the install step: a named clean skip on Linux, and the
#                                              seat on a Mac, run from a copy of the real function
#
# Exit: 0 both suites held · 1 one failed (its own tail is printed).
set -u
_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
}
ROOT="$(_root)"
VERBOSE=0
case "${1-}" in
  -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --verbose) VERBOSE=1 ;;
  "") ;;
  *) printf 'error: unknown flag %s\nhelp: launchd-layer.sh [--verbose]\n' "${1-}" >&2; exit 2 ;;
esac

fail=0
run() {  # <label> <command…>
  local label="$1"; shift
  local out rc
  out="$("$@" 2>&1)" && rc=0 || rc=$?
  if [ "$rc" -eq 0 ]; then
    [ "$VERBOSE" = 1 ] && printf '  ok   %s\n' "$label"
    [ "$VERBOSE" = 1 ] && printf '%s\n' "$out" | sed 's/^/       /'
    return 0
  fi
  printf 'FAIL %s\n' "$label"
  printf '%s\n' "$out" | grep -vE '^[[:space:]]*$' | tail -15 | sed 's/^/       /'
  fail=1
}

run "launchd-user.py renders the register and answers the verbs" \
    python3 "$ROOT/bin/engine/tests/test_launchd_user.py"
run "step_launchd skips cleanly off a Mac and seats on one" \
    bash "$ROOT/bin/engine/tests/test_launchd_step_skips.sh"

[ "$fail" -eq 0 ] && { [ "$VERBOSE" = 1 ] && printf '  every launchd-layer case held\n'; exit 0; }
exit 1

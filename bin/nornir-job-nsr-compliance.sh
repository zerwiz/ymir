#!/usr/bin/env bash
# nornir-job-nsr-compliance.sh — the NorthStar compliance round, nightly.
#
# Runs the deterministic NSR gates (.compliance/gates/check_*.sh — danger,
# env, paths, platform, wiring) and carves one Rune with the verdict. A FAIL
# is reported loudly in the Rune message — the morning briefing reads the
# ledger, so a broken door is seen at sunrise, not found by accident.
#
# Stateless: run gates → write nothing but state/last + the Rune → exit.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
STATE="${BROKK_STATE_OVERRIDE:-$ROOT/state}"

GATES_DIR="$ROOT/.compliance/gates"
[ -d "$GATES_DIR" ] || { printf 'error: no NSR gates at %s\n' "$GATES_DIR"; exit 1; }

passed=0; failed=0; failed_names=""
for g in "$GATES_DIR"/check_*.sh; do
  name=$(basename "$g" .sh)
  if bash "$g" >/dev/null 2>&1; then
    passed=$((passed+1))
  else
    failed=$((failed+1)); failed_names="$failed_names $name"
  fi
done

printf 'nsr-compliance: gates=%d passed=%d failed=%d%s\n' \
  "$((passed+failed))" "$passed" "$failed" "$failed_names"

# shellcheck source=bin/runes-append.sh
. "$ROOT/bin/runes-append.sh"
if [ "$failed" = 0 ]; then
  runes_append "nornir" "nsr.compliance" --message "NSR compliance: $passed/$passed gates passed" >/dev/null \
    || printf 'nsr-compliance: rune append failed (non-fatal)\n'
  exit 0
else
  runes_append "nornir" "nsr.compliance.failed" --message "NSR compliance FAIL: gates $failed_names FAILED — mend at sunrise" >/dev/null \
    || printf 'nsr-compliance: rune append failed (non-fatal)\n'
  exit 1
fi
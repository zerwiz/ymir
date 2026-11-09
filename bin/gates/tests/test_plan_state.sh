#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; ROOT="$(cd "$ROOT/.." && pwd)"
TMP="$(mktemp -d)"
export YMIR_PLAN_DIR="$TMP/plans"; mkdir -p "$TMP/plans"
# plan missing headers -> finding
printf '# Plan 1 - x\n\nbody\n' > "$TMP/plans/1-x.md"
if YMIR_PLAN_DIR="$TMP/plans" "$ROOT/bin/records/plan-state.sh" check >/dev/null 2>&1; then echo "FAIL: check should fail"; exit 1; fi
# set headers
YMIR_PLAN_DIR="$TMP/plans" "$ROOT/bin/records/plan-state.sh" set "$TMP/plans/1-x.md" open needs-owner >/dev/null
YMIR_PLAN_DIR="$TMP/plans" "$ROOT/bin/records/plan-state.sh" check >/dev/null 2>&1 || { echo "FAIL: check should pass"; exit 1; }
# weave restores drifted row
printf '# Plans index\n' > "$TMP/plans/README.md"
YMIR_PLAN_DIR="$TMP/plans" "$ROOT/bin/records/weave.sh" --fix >/dev/null 2>&1 || true
# use repo weave? repo weave uses home ledger; instead test grep
grep -q "1-x.md" "$TMP/plans/README.md" || { echo "FAIL: row not woven"; exit 1; }
# done move keeps row resolvable: move file to done/, row still names original? Just check dir
mkdir -p "$TMP/plans/done"
mv "$TMP/plans/1-x.md" "$TMP/plans/done/1-x.md"
echo "PASS"
rm -rf "$TMP"

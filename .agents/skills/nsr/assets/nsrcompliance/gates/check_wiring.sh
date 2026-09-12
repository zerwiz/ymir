#!/usr/bin/env bash
# check_wiring: does the compliance actually touch the project, or is it still stubs?
#
# A script is WIRED when the shipped STUB marker is gone from its body. A freshly
# scaffolded repo is 100% stubs — that is fine during bootstrap. Before you trust
# the compliance (run agents against it, deploy for real) run --strict: it must pass.
#
# Usage:
#   check_wiring.sh             # report wired vs stub; exit 0 unless required scripts missing
#   check_wiring.sh --strict    # exit 1 if any required script is missing or still a stub
set -e

find_root() {
  local d; d="$(cd "$(dirname "$0")" && pwd)"
  while [ "$d" != "/" ]; do
    if [ -d "$d/.agents" ]; then echo "$d"; return 0; fi
    d="$(dirname "$d")"
  done
  return 1
}

ROOT="$(find_root)" || { echo "[check_wiring] FAIL: no repo root (.agents/ not found upward)"; exit 1; }
STRICT=0
[ "${1:-}" = "--strict" ] && STRICT=1

fail=0

echo "[check_wiring] scanning for real-world wiring under $ROOT"

is_stub() {
  grep -qiE '\bSTUB\b|# stub[: ]' "$1" 2>/dev/null
}

check_script() {
  local f="$1"
  [ -f "$f" ] || { [ "$STRICT" -eq 1 ] && { echo "  FAIL [MISSING] $f"; fail=1; }; return 0; }
  if is_stub "$f"; then
    if [ "$STRICT" -eq 1 ]; then
      echo "  FAIL [STUB  ] $f"
      fail=1
    else
      echo "  warn [STUB  ] $f (not wired — see docs/BEST_PRACTICES/compliance-wiring.md)"
    fi
  else
    echo "  ok   [WIRED ] $f"
  fi
}

# lifecycle is mandatory for a project to be operable
for f in start stop status smoke_test; do
  check_script "$ROOT/.agents/skills/lifecycle/$f.sh"
done

# every feature dir must have its five script domains wired
for d in "$ROOT"/.agents/skills/features/*/; do
  [ -d "$d" ] || continue
  for f in setup test smoke_test rollback; do
    check_script "$d/$f.sh"
  done
done

if [ "$fail" -ne 0 ]; then
  echo "[check_wiring] STRICT FAIL — compliance scripts are stubs/missing, not wired to the project."
  echo "[check_wiring] Wire them per docs/BEST_PRACTICES/compliance-wiring.md, then re-run."
  exit 1
fi
[ "$STRICT" -eq 1 ] && echo "[check_wiring] PASS (strict) — every required script is wired"
[ "$STRICT" -eq 0 ] && echo "[check_wiring] PASS (report) — nothing missing for a bootstrap repo"
exit 0
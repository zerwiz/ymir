#!/usr/bin/env bash
# check_danger: validate that scripts may be run by the compliance, or are explicitly gated.
#
# Any script containing a dangerous primitive (data loss, force ops, shell
# injection, destructive commands) MUST declare its blast radius in a comment:
#
#   # gate: dev    - safe for agents/automation in dev; human confirm in prod
#   # gate: guard  - must not run until a required guard script passes
#   # gate: human  - irreversible; agents must never run this alone
#
# A script with dangerous primitives and no # gate: annotation FAILS this check.
#
# Usage:
#   check_danger.sh            # scan .agents/skills/{lifecycle,git_ops,features,compliance}
#   check_danger.sh --path <f> # evaluate a single script in isolation
set -e

find_root() {
  local d; d="$(cd "$(dirname "$0")" && pwd)"
  while [ "$d" != "/" ]; do
    if [ -d "$d/.agents" ]; then echo "$d"; return 0; fi
    d="$(dirname "$d")"
  done
  return 1
}

ROOT="$(find_root)" || { echo "[check_danger] FAIL: no repo root (.agents/ not found upward)"; exit 1; }
SINGLE_PATH=""

DANGER_PRIMS=(
  'rm[[:space:]]+-rf'
  'rm[[:space:]]+-fr'
  ':\(\)[[:space:]]*\{'
  'kill[[:space:]]+-9'
  'pkill'
  'taskkill'
  'git[[:space:]]+push[[:space:]]+--force'
  'git[[:space:]]+reset[[:space:]]+--hard'
  'DROP[[:space:]]+(TABLE|DATABASE)'
  'TRUNCATE[[:space:]]+TABLE'
  'dd[[:space:]]+if='
  'mkfs'
  'chmod[[:space:]]+-R[[:space:]]+777'
  'curl[[:space:]].*\|[[:space:]]*sh'
  'wget[[:space:]].*\|[[:space:]]*sh'
)

GATE_RE='^[[:space:]]*# gate:[[:space:]]*(dev|guard|human)([[:space:]]+.*|:|$)'

has_danger() {
  local f="$1" prim
  for prim in "${DANGER_PRIMS[@]}"; do
    grep -qiE "$prim" "$f" 2>/dev/null && return 0
  done
  return 1
}

has_gate() { grep -qiE "$GATE_RE" "$1" 2>/dev/null; }

check_file() {
  local f="$1" g
  has_danger "$f" || return 0
  if has_gate "$f"; then
    g="$(grep -iE "$GATE_RE" "$f" | head -1 | sed -E 's/^[[:space:]]*//')"
    echo "  OK   [gated] $g"
    echo "        $f"
  else
    echo "  FAIL [ungated danger] $f"
    echo "        contains a dangerous primitive but no '# gate:' annotation"
    return 1
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --path) SINGLE_PATH="$2"; shift 2 ;;
    -h|--help) echo "usage: check_danger.sh [--path FILE]"; exit 0 ;;
    -*) echo "unknown option: $1"; exit 1 ;;
    *) SINGLE_PATH="$1"; shift ;;
  esac
done

fail=0

if [ -n "$SINGLE_PATH" ]; then
  check_file "$SINGLE_PATH" || fail=1
else
  echo "[check_danger] scanning $ROOT/.agents/skills for dangerous primitives"
  for f in "$ROOT"/.agents/skills/lifecycle/*.sh \
           "$ROOT"/.agents/skills/git_ops/*.sh \
           "$ROOT"/.agents/skills/features/*/*.sh; do
    [ -f "$f" ] || continue
    check_file "$f" || fail=1
  done
fi

if [ "$fail" -ne 0 ]; then
  echo "[check_danger] FAIL: dangerous scripts without a # gate: annotation"
  exit 1
fi
echo "[check_danger] PASS: no undeclared dangerous scripts"
exit 0
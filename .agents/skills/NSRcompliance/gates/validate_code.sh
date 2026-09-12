#!/usr/bin/env bash
# Deterministic gate: run test + lint checks. Exit 0 = pass, non-zero = fail.
set -e

echo "[gate] validate_code: running lint + test gates"

gates_passed=0

for gate in .compliance/gates/*.sh; do
  if [ -x "$gate" ]; then
    echo "[gate] running $gate"
    "$gate" || gates_passed=1
  fi
done

for script in .agents/skills/features/*/test.sh; do
  if [ -f "$script" ]; then
    echo "[gate] running $script"
    bash "$script" || gates_passed=1
  fi
done

if [ "$gates_passed" -eq 0 ]; then
  echo "[gate] PASS ($? == 0)"
  exit 0
fi

echo "[gate] FAIL"
exit 1

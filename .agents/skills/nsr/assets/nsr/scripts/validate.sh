#!/usr/bin/env bash
# NSR validate: audit a repo against NSR compliance gates.
#
# Usage: validate.sh [project-dir]   (defaults to current dir)
#
# Runs: verify_docs (structure) -> check_env -> check_paths -> check_platform.
# Any non-zero exit fails validation.
set -e

PROJECT_DIR="${1:-$(pwd)}"
cd "$PROJECT_DIR"
ROOT="$(pwd)"

echo "[nsr/validate] validating $ROOT"

fail=0

echo "[nsr/validate] 1/4 structure + docs (verify_docs.py)"
if python3 "$ROOT/.agents/skills/NSRcompliance/gates/verify_docs.py"; then
  echo "[nsr/validate] structure OK"
else
  echo "[nsr/validate] STRUCTURE FAIL"; fail=1
fi

echo "[nsr/validate] 2/4 env (check_env.sh)"
if bash "$ROOT/.compliance/gates/check_env.sh"; then
  echo "[nsr/validate] env OK"
else
  echo "[nsr/validate] ENV FAIL"; fail=1
fi

echo "[nsr/validate] 3/4 paths (check_paths.sh)"
if bash "$ROOT/.compliance/gates/check_paths.sh"; then
  echo "[nsr/validate] paths OK"
else
  echo "[nsr/validate] PATHS FAIL"; fail=1
fi

echo "[nsr/validate] 4/4 platform (check_platform.sh)"
if bash "$ROOT/.compliance/gates/check_platform.sh"; then
  echo "[nsr/validate] platform OK"
else
  echo "[nsr/validate] PLATFORM FAIL"; fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "[nsr/validate] FAILED"
  exit 1
fi

echo "[nsr/validate] PASS — repo is NSR-compliant"
exit 0
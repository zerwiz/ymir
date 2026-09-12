#!/usr/bin/env bash
# STUB: safe commit — pre-commit gates + formatted message.
set -e
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
echo "[git_ops/safe_commit] stub: running pre-commit gates"
bash "$ROOT/.compliance/gates/check_paths.sh"
bash "$ROOT/.compliance/gates/check_platform.sh"
echo "[git_ops/safe_commit] stub: git add + commit (conventional style)"
exit 0
#!/usr/bin/env bash
# Gate: verify required env vars are present (env-driven config).
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if [ -f "$ROOT/.env" ]; then
  set -a; . "$ROOT/.env"; set +a
fi

REQUIRED=()
[ -n "${REQUIRED_ENV:-}" ] && IFS=',' read -ra REQUIRED <<< "$REQUIRED_ENV" || true

missing=0
for var in "${REQUIRED[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "[check_env] MISSING: $var"
    missing=1
  fi
done

[ "$missing" -ne 0 ] && { echo "[check_env] FAIL"; exit 1; }
echo "[check_env] PASS"
exit 0
#!/usr/bin/env bash
# Env-driven deploy runner. Inputs: environment tier + deployment target (client|tenant).
# All paths relative to repo root. POSIX-portable (Mac/Linux/Windows via Git Bash/WSL).
set -e

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
DEPLOY_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  echo "Usage: deploy.sh --env <env> --target <client|tenant>"
  echo "  --env     environment tier: development|staging|production"
  echo "  --target  deployment target: 'client:<name>' or 'tenant:<name>'"
  exit 1
}

ENV=""
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --env) ENV="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[ -n "$ENV" ] && [ -n "$TARGET" ] || usage

BASE="$DEPLOY_DIR/envs/$ENV.env.example"
[ -f "$BASE" ] || { echo "Missing env template: $BASE"; exit 1; }

TYPE="${TARGET%%:*}"
NAME="${TARGET#*:}"
case "$TYPE" in
  client) OVERRIDE="$DEPLOY_DIR/clients/$NAME/$ENV.env.example" ;;
  tenant) OVERRIDE="$DEPLOY_DIR/tenants/$NAME.env.example" ;;
  *) echo "Unknown target type: $TYPE"; exit 1 ;;
esac

echo "[deploy] env=$ENV target=$TARGET"
echo "  base:   $BASE"
[ -f "$OVERRIDE" ] && echo "  over:   $OVERRIDE" || echo "  over:   (none)"

# Deterministic pre-deploy gates
echo "[deploy] running pre-deploy gates"
bash "$ROOT/.compliance/gates/check_env.sh"
bash "$ROOT/.compliance/gates/check_paths.sh"
bash "$ROOT/.compliance/gates/check_platform.sh"

echo "[deploy] OK: ready to deploy (stub — actual rollout via .agents/skills/features/*)"
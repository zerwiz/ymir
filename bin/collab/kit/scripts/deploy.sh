#!/usr/bin/env bash
# deploy.sh — build, label, ship and verify a release; keep the current and the previous tag (RULES/23).
#
#   bash scripts/deploy.sh --release 1.4 --dry-run    # the plan, the storage driver, the rollback — nothing changes
#   bash scripts/deploy.sh --release 1.4
#   bash scripts/deploy.sh --rollback                 # the project's own rollback, to the previous release
set -euo pipefail
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kit.py" deploy "$@"

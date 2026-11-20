#!/usr/bin/env bash
# prune.sh — every leftover a development task makes, each class declared in project.yaml (RULES/24).
#
#   bash scripts/prune.sh                         # a report: what would go, and why
#   bash scripts/prune.sh --apply                 # do it
#   bash scripts/prune.sh --class worktrees,branches --apply
#
# Classes: worktrees branches remote_refs caches scratch test_databases images volumes stopped_containers.
set -euo pipefail
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kit.py" prune "$@"

#!/usr/bin/env bash
# stack.sh — turn an app's development stack on and off; production pieces are never stopped.
#
#   bash scripts/stack.sh status [app]
#   bash scripts/stack.sh on <app>|--all-dev
#   bash scripts/stack.sh off <app>|--all-dev [--piece NAME]
#
# Reads the machine's manifest, ~/.config/collab-kit/stacks.yaml (never a repository file).
set -euo pipefail
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kit.py" stack "$@"

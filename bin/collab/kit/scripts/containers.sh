#!/usr/bin/env bash
# containers.sh — the container door (RULES/23): builds here, never removes on a product host.
#
#   bash scripts/containers.sh build --tag repo:1.2 --purpose product --release 1.2 [context] [-- engine args]
#   bash scripts/containers.sh retain [--apply]     # keep the current and the previous tag; clear leftovers
#   bash scripts/containers.sh <engine args…>       # passed through; a change on a product host is refused
set -euo pipefail
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kit.py" containers "$@"

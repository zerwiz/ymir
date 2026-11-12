#!/usr/bin/env bash
# handoff/check.sh — the stable door for the baton, in any project.
#
# The rules live in check.py beside this file; this wrapper exists so a project can call one path from
# its build regardless of stack. Installed by `bin/collab/collab.sh init`.
#
#   handoff/check.sh --check [--max-age-days N]
#   handoff/check.sh --new --from <name> [--to <name>] [--note "one line"]
set -euo pipefail
_d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$_d/check.py" "$@"

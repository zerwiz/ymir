#!/usr/bin/env bash
# check-host.sh — a read-only report on this machine: disk, worktrees per repository, containers, images.
#
#   bash scripts/check-host.sh [--repo <path>]… [--sizes] [--strict] [--json]
#
# With no --repo it reads the repositories listed in ~/.config/collab-kit/machine.yaml (repos:), else this
# one. --strict exits 1 when any line is over its limit. It changes nothing.
set -euo pipefail
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kit.py" check-host "$@"

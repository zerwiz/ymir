#!/usr/bin/env bash
# activate.sh — seat what must name the LIVE release; Ymir's apps.sh runs it after every flip and rollback.
#   `smidja` and `smidja-mcp` on PATH, and the Smíðja MCP in pi's set and (with Ymir) every harness.
# Seated through the apps home's `current` link, so an update never leaves a door on an old release.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
link="${YMIR_APPS_HOME:+$YMIR_APPS_HOME/${YMIR_APP_NAME:-smidja}/current}"
if [ -n "$link" ] && [ -L "$link" ]; then export SMIDJA_FACTORY_LINK="$link"; fi
exec python3 "$HERE/scripts/install-doors.py" "$@"

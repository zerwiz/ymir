#!/usr/bin/env bash
# activate.sh — seat what names the LIVE release; Ymir's apps.sh runs it after every flip and rollback.
# setup.sh again (current, so it changes only what is stale) WITH the launcher entry, which runs the hall through
# Ymir's `ymir-app bilskirnir`, or through the apps home's `current/start.sh` when Ymir is not here.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec env BILSKIRNIR_DESKTOP="${BILSKIRNIR_DESKTOP:-1}" bash "$HERE/setup.sh"

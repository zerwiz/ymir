#!/usr/bin/env bash
# 0011-snotra-meetings — give an existing home the meeting skeleton.
#
# The installer's snotra step installs the ear; this migration installs the lifecycle:
# meetings shelf, operator template (only if absent), confidential register template,
# framework + templates, and the Snotra cron block. It never invents a company, a
# participant or an NDA hash.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INIT="$ROOT/systems/snotra/services/record/snotra-init.sh"
[ -x "$INIT" ] || { echo "0011: snotra-init missing — nothing touched"; exit 0; }
"$INIT" apply

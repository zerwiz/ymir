#!/usr/bin/env bash
# mimir-log.sh — move memory between the engram and the append log (a thin door).
#
# The logic lives in `bin/records/mimir-log.py`; the interpreter is the bridge's
# own resolver (`bin/bridge/mimir-bridge.sh --python`), so the log tool and the
# bridge never disagree about which python owns the store. Galdr-style TOON out.
#
#   mimir-log.sh export   engram -> log    (append what the log lacks)
#   mimir-log.sh reseed   log -> engram    (observe what the engram lacks)
#   mimir-log.sh verify   the gap that must be zero
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRIDGE_SH="$HERE/../bridge/mimir-bridge.sh"
[ -x "$BRIDGE_SH" ] || { printf 'mimir-log: bridge door missing at %s\n' "$BRIDGE_SH" >&2; exit 127; }
PY="$("$BRIDGE_SH" --python 2>/dev/null)"
[ -n "$PY" ] || { printf 'mimir-log: cannot resolve the engram interpreter\nhelp: bin/bridge/mimir-bridge.sh --python\n' >&2; exit 1; }
exec "$PY" "$HERE/mimir-log.py" "$@"

#!/usr/bin/env bash
# brokk-update.sh — back-compat alias.
#
# The updater shaman is Gróa; see bin/groa-update.sh. This thin alias keeps old
# callers working (and the `groa-update` skill now names her).
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
printf 'note: brokk-update.sh is an alias; the updater is Gróa (bin/groa-update.sh)\n' >&2
exec "$SCRIPT_DIR/groa-update.sh" "$@"

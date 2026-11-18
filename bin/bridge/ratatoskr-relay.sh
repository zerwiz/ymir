#!/usr/bin/env bash
# ratatoskr-relay.sh — the loop that WAKES a ready target and carries the answer back.
#
#   bin/bridge/ratatoskr-relay.sh --once            one pass (what a test or a person runs)
#   bin/bridge/ratatoskr-relay.sh run               the loop (what the user unit runs)
#   bin/bridge/ratatoskr-relay.sh status            what it last did
#
# WHY (plan 303 §5, §12.3 step 4): a task on a shelf is not a conversation. This door
# wakes the receiver — by `herdr agent prompt` where that verb exists, and by
# `herdr agent send` + Enter where it does not — confirms the agent moved, retries once,
# and carries the answer back into the asker's pane under
# `[ratatoskr · from <claimer> · re <id>]`. A wake that changed nothing is recorded as a
# miss naming the pane and the reason; it is never silent.
#
# Flags: --queue DIR · --machine NAME · --confirm SECS · --dry
# Exit: 0 one clean pass · 1 the pass ended with misses · 2 usage.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$here/ratatoskr-relay.py"

case "${1-}" in
  -v|-V|--version) printf '1.0.0\n'; exit 0 ;;
  -h|--help|"") sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit $([ -n "${1-}" ] && echo 0 || echo 2) ;;
esac

# `--once` is one pass; the parser below expects the verb, so normalise the flag form.
if [ "${1-}" = "--once" ]; then set -- once "${@:2}"; fi

[ -r "$PY" ] || { printf 'error: the relay body is missing: %s\n' "$PY" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { printf 'error: python3 is required\n' >&2; exit 2; }
exec python3 "$PY" "$@"

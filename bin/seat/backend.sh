#!/usr/bin/env bash
# backend.sh — the six verbs, for whichever backend a target names.
#
#   bin/seat/backend.sh list                        every agent and session on this machine
#   bin/seat/backend.sh get <target>                ready · working · blocked: <why> · dead
#   bin/seat/backend.sh read <target> [--lines N]   the tail of its output / transcript
#   bin/seat/backend.sh prompt <target> "<text>"    wake it, by that backend's own road
#   bin/seat/backend.sh wait <target> [--timeout N] [--until working]
#   bin/seat/backend.sh explain <target>            why it is not ready, and the exact recovery
#
# WHY (plan 303 §14): herdr is a BACKEND with six verbs, and Hermes is the second one. Every
# door that reaches an agent speaks these verbs, so no caller learns a new tool when a new
# harness arrives. A target is `herdr:<pane>`, `hermes:<session-id-or-title>`, or bare — and a
# bare target is herdr, so nothing that works today changes shape.
#
# Exit: 0 ready/proved · 1 working · 2 blocked · 3 dead · 64 usage.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$here/backends/door.py"

case "${1-}" in
  -v|-V|--version) printf '1.0.0\n'; exit 0 ;;
  -h|--help|"") sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit $([ -n "${1-}" ] && echo 0 || echo 64) ;;
esac
[ -r "$PY" ] || { printf 'error: the backend body is missing: %s\n' "$PY" >&2; exit 64; }
exec python3 "$PY" "$@"

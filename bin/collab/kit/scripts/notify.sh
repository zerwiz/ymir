#!/usr/bin/env bash
# notify.sh — hand a gate's refusal to whoever should hear it, not only to the terminal that typed the command.
#
# A refusal printed at the person who typed `git commit` may never reach the agent or the team that owns the
# work. This door passes it on to one command the project declares, and stays silent when none is declared.
#
#   the command   project.yaml `notify: {command: "…"}`, or $KIT_NOTIFY_CMD (wins). It is run with two
#                 arguments: the gate's name and the first lines of its message.
#
# Laws it holds:
#   1 · It never breaks a git operation: it always exits 0 (KIT_NOTIFY_STRICT=1 makes a failed delivery exit 1).
#   2 · No address leaks: the message names the repository and the gate, never a host, a port or a path.
#   3 · No command declared, no notice — and `notify.sh --who` says so.
#
# Usage: notify.sh <gate> <message>…   ·   notify.sh --who
set -uo pipefail
STRICT="${KIT_NOTIFY_STRICT:-0}"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root" || exit 0

cmd="${KIT_NOTIFY_CMD:-}"
if [ -z "$cmd" ] && [ -f scripts/kit.py ] && [ -f project.yaml ]; then
  cmd="$(python3 scripts/kit.py config get notify.command 2>/dev/null || true)"
fi

if [ "${1:-}" = "--who" ]; then
  if [ -n "$cmd" ]; then printf 'notices go to: %s\n' "$cmd"; else printf 'notices go nowhere: no notify.command in project.yaml and no KIT_NOTIFY_CMD\n'; fi
  exit 0
fi

gate="${1:-gate}"; shift || true
msg="$(printf '%s' "$*" | head -5 | cut -c1-300)"
[ -n "$cmd" ] || exit 0
if ! bash -c "$cmd \"\$@\"" notify "[$(basename "$root")] $gate" "$msg" >/dev/null 2>&1; then
  [ "$STRICT" = 1 ] && exit 1
fi
exit 0

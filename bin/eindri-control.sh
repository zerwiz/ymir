#!/usr/bin/env bash
# eindri-control.sh — the CONTROL plane: allowlisted lifecycle verbs for a
# seated Eindri, addressed by agent name or pane. No arbitrary text, no raw keys.
#
#   bin/eindri-control.sh interrupt <agent-or-pane>   # cancel the running turn
#   bin/eindri-control.sh exit <agent-or-pane>        # stop the agent, keep the pane
#   bin/eindri-control.sh read <agent-or-pane>        # read its current output
set -u
VERB="${1:-}"; TARGET="${2:-}"
[ -n "$VERB" ] && [ -n "$TARGET" ] || { printf 'error: usage: bin/eindri-control.sh <interrupt|exit|read> <agent-or-pane>\n' >&2; exit 2; }
command -v herdr >/dev/null 2>&1 || { printf 'error: herdr not on PATH\n' >&2; exit 1; }

case "$VERB" in
  interrupt)
    # Deliver the interrupt key sequence; the agent keeps running.
    herdr agent send-keys "$TARGET" ctrl+c >/dev/null 2>&1 \
      && printf 'eindri-control[1]{verb,target,state}:\n  "interrupt","%s","delivered"\n' "$TARGET" \
      || { printf 'eindri-control[1]{verb,target,state}:\n  "interrupt","%s","failed"\n' "$TARGET" >&2; exit 1; } ;;
  exit)
    # Stop the agent; keep the pane/worktree. herdr clears the agent on exit.
    herdr pane close "$TARGET" >/dev/null 2>&1
    herdr agent release-agent "$TARGET" >/dev/null 2>&1 || true
    printf 'eindri-control[1]{verb,target,state}:\n  "exit","%s","stopped"\n' "$TARGET" ;;
  read)
    herdr agent read "$TARGET" 2>/dev/null || true ;;
  *)
    printf 'error: verb %s not allowlisted (interrupt|exit|read)\n' "$VERB" >&2; exit 2 ;;
esac

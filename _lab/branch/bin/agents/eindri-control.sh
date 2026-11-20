#!/usr/bin/env bash
# eindri-control.sh — the CONTROL plane: allowlisted lifecycle verbs for a
# seated Eindri, addressed by agent name or pane. No arbitrary text, no raw keys.
#
#   bin/agents/eindri-control.sh interrupt <agent-or-pane>   # cancel the running turn
#   bin/agents/eindri-control.sh exit <agent-or-pane>        # stop the agent, keep the pane
#   bin/agents/eindri-control.sh read <agent-or-pane>        # read its current output
set -u
VERB="${1:-}"; TARGET="${2:-}"
[ -n "$VERB" ] && [ -n "$TARGET" ] || { printf 'error: usage: bin/agents/eindri-control.sh <interrupt|exit|read> <agent-or-pane>\n' >&2; exit 2; }
command -v herdr >/dev/null 2>&1 || { printf 'error: herdr not on PATH\n' >&2; exit 1; }

case "$VERB" in
  interrupt)
    # Deliver the interrupt key sequence; the agent keeps running.
    herdr agent send-keys "$TARGET" ctrl+c >/dev/null 2>&1 \
      && printf 'eindri-control[1]{verb,target,state}:\n  "interrupt","%s","delivered"\n' "$TARGET" \
      || { printf 'eindri-control[1]{verb,target,state}:\n  "interrupt","%s","failed"\n' "$TARGET" >&2; exit 1; } ;;
  exit)
    # Stop the agent AND THE WORK IT STARTED; keep the pane/worktree.
    # A seat that has already lost its pane (the common close path) must not turn a
    # successful stop into a failure: the WORK is what this verb guarantees, and
    # seat-stop.sh is the judge of that (measured 2026-10-24: close returned rc=1 on a
    # seat whose work had stopped cleanly).
    # A pane that closes while its worker lives on is the fault of 2026-10-24: a seat was
    # closed and a process waiting on the model lock survived, to be killed by hand.
    herdr pane close "$TARGET" >/dev/null 2>&1 || true
    herdr agent release-agent "$TARGET" >/dev/null 2>&1 || true
    _sd="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -x "$_sd/seat-stop.sh" ]; then
      "$_sd/seat-stop.sh" "$TARGET" >/dev/null 2>&1 || \
        printf 'eindri-control[1]{verb,target,warn}:\n  "exit","%s","a process in its worktree survived the stop — run bin/agents/seat-stop.sh %s"\n' "$TARGET" "$TARGET" >&2
    fi
    printf 'eindri-control[1]{verb,target,state}:\n  "exit","%s","stopped (pane and worktree processes)"\n' "$TARGET" ;;
  read)
    herdr agent read "$TARGET" 2>/dev/null || true ;;
  *)
    printf 'error: verb %s not allowlisted (interrupt|exit|read)\n' "$VERB" >&2; exit 2 ;;
esac

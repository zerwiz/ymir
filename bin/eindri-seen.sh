#!/usr/bin/env bash
# eindri-seen.sh — condition half of the Eindri→Brokk wake bridge.
#
# Exit 0 (true) when a seated Eindri has REPORTED: a report file exists
# (state/eindri-reports/<agent>.md, or a REPORT.md at the given worktree root)
# OR herdr shows the agent left `working` (done / blocked / idle). Exit 1 while
# the smith still works. Any other exit is an error — per the when-adapter
# contract, 0 is the only true and never a mutation.
#
# Pure check: deterministic per the poll, mutates nothing.
#
# Usage: bin/eindri-seen.sh <agent> [<worktree-root>]
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# The roots that live OUTSIDE the code tree: this machine's records and the
# runtime state belong to the home the operator chose at installation, never in
# the tree — a packaged install replaces its tree on upgrade (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$(dirname "$_yr")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_state_dir YMIR_STATE_DIR
hoard_data_dir YMIR_DATA_DIR
STATE="${BROKK_STATE_OVERRIDE:-$YMIR_STATE_DIR}"
AGENT="${1:-}"
WORKTREE="${2:-}"
[ -n "$AGENT" ] || { echo "usage: eindri-seen.sh <agent> [<worktree-root>]" >&2; exit 2; }

# 1. A report file is the strongest signal the smith is done.
[ -f "$STATE/eindri-reports/$AGENT.md" ] && exit 0
[ -n "$WORKTREE" ] && [ -f "$WORKTREE/REPORT.md" ] && exit 0

# 2. herdr state: only a TERMINAL state counts as reported. A pi agent reads
#    'idle' between its own tool-thoughts while the errand still burns — idle is
#    still working; done/blocked mean the smith finished or is stuck.
if command -v herdr >/dev/null 2>&1; then
  state=$(herdr agent list 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    for a in d['result']['agents']:
        if (a.get('name')==sys.argv[1]):
            print(a.get('agent_status','unknown'))
except Exception:
    pass
" "$AGENT")
  case "$state" in done|blocked) exit 0 ;; esac
fi
exit 1
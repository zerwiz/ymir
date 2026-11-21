#!/usr/bin/env bash
# arm-holder-pane.sh — which herdr pane holds this machine's arm? Answered by the machine itself,
# so a caller on another machine (bin/fleet/fleet-tell.sh, over ssh) never carries a pane id.
#
#   bin/fleet/arm-holder-pane.sh        prints the pane id and exits 0, or prints `not-found` and exits 1
#
# It asks the arm-holder inbox (bin/agents/eindri-notify.sh --status: the lock owner, the lease's session,
# the pane the holder named) and then PROVES the answer: the pane must be listed by `herdr agent list` as an
# AGENT pane. A pane that is a plain shell, a dead pane or a remembered ghost is never returned, so nothing
# is ever typed into one. Inner limits (20s + 10s) sit under the caller's outer limit (fleet-tell.sh PANE_LIMIT).
set -u
ROOT="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NOTIFY="${ARM_HOLDER_NOTIFY:-$ROOT/bin/agents/eindri-notify.sh}"
# a login shell over ssh has no herdr socket and a short PATH: find both before asking
export PATH="$HOME/.local/bin:$PATH"
[ -n "${HERDR_SOCKET_PATH:-}" ] || { hs="${XDG_CONFIG_HOME:-$HOME/.config}/herdr/herdr.sock"; [ -S "$hs" ] && export HERDR_SOCKET_PATH="$hs"; }
command -v herdr >/dev/null 2>&1 || { echo not-found; exit 1; }
row="$(timeout "${ARM_HOLDER_NOTIFY_TIMEOUT:-20}" bash "$NOTIFY" --status 2>/dev/null | sed -n '2p')"
pane="$(printf '%s' "$row" | awk -F'","' '{print $3}')"
[ -n "$pane" ] && [ "$pane" != "NOT FOUND" ] || { echo not-found; exit 1; }
if timeout "${ARM_HOLDER_HERDR_TIMEOUT:-10}" herdr agent list 2>/dev/null | python3 -c '
import json, sys
want = sys.argv[1]
try: d = json.load(sys.stdin)
except Exception: sys.exit(1)
for a in (d.get("result") or {}).get("agents") or []:
    if a.get("pane_id") == want and a.get("agent"): sys.exit(0)
sys.exit(1)' "$pane"; then printf '%s\n' "$pane"; exit 0; fi
echo not-found; exit 1

#!/usr/bin/env bash
# syn-watch.sh — Sýn as a SERVICE: one supervision watcher per home, seated
# once and standing until it is stopped.
#
# The arm used to live and die with the harness session. When the session's lock
# owner went away the watcher exited `0` in silence ("retired"), so a live
# supervision read as dead and the Pi extension flapped through a day of blind
# turn ends and hand re-arms (2026-09-27). The watcher is now a service (plan 58,
# Phase 2): it outlives every session, keeps its own LEASE, IDLES when no session
# is seated instead of retiring, and is restarted by systemd (or by the thin
# client) when it dies.
#
#   syn-watch.sh status   # the truth: lease, heartbeat, session, mode; exit 1 on a gap
#   syn-watch.sh start    # seat the arm service (the systemd unit, else a detached daemon)
#   syn-watch.sh stop     # bring it down (both shapes)
#   syn-watch.sh run      # the daemon loop in the foreground (the unit's ExecStart)
#   syn-watch.sh run --emit  # the loop that PRINTS the raised line and ends (the
#                          # pre-service shape, for a probe: BROKK_WATCH_INLINE=1)
#   syn-watch.sh restart  # stop, then start
#
# The BEHAVIOUR — the lease, the heartbeat, the up/idle/stale/down verdict, the
# raise grammar, the wake-queue flood brake — is owned ONCE by the engine
# (`src/ymir_runtime/watch.py`, plan 58 Phase 5), so the vendored watcher's seam
# is folded rather than mirrored. This file is now only the door: the interpreter,
# the argv, and nothing that could drift.
#
# The state, all under the resolved state dir (the same dir the harness readers,
# the turn-end guard, and bin/pi/syn-watch-arm.sh use):
#
#   .watch.heartbeat    epoch seconds, touched every cycle (the liveness door)
#   .supervision-armed  the armed marker the turn-end guard reads (inert without it)
#   .arm.lease          pid=<pid> starttime=<st> gen=<n> mode=<systemd|daemon>
#                       session=<pid|none> heartbeat=<epoch> state=<dir>
#   .arm.event          the raised-but-undelivered actionable line (one line)
#   .arm.wake           append-only journal of every line this arm has raised
#
# The grammar is the contract: the arm raises `signal:` / `stale:` / `check:` /
# `heartbeat:` lines and nothing else; bin/pi/syn-watch-arm.sh relays them to the
# harness unchanged. This file writes no line to stdout except those.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

# The engine door owns the interpreter, PYTHONPATH, and the venv choice. This
# door hands the verb over and keeps none of the judgement.
exec "$SCRIPT_DIR/../engine/ymir-engine.sh" watch "$@"

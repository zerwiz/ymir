#!/usr/bin/env bash
# veil.sh — the Veil's road to the arm: every report and finding carries an id, and the arm holder
# says it RECEIVED it (plan 350, part B, the section appended 2026-11-22).
#
# The Allfather's word: "An arm holder must always reassure that he will get the work done —
# received — so he can know what's going on and if it was a correct build. We have had problems
# with the queue building up and the arm holder never receiving the incoming."
#
#   veil.sh send [--from <who>] [--kind report|finding|steer] [--reply-to <tell target>] [--queued] "<text>"
#                                   hand a report to the arm holder with a fresh id (printed)
#   veil.sh steer --to <agent> [--from <who>] "<line>"
#                                   the holder steers an agent (a pane, an errand, hermes:<session>); the
#                                   line carries an id the agent answers with `veil.sh received <id>`
#   veil.sh received <id> [--by <who>] ["<note>"]     the holder: I have it (within 2 minutes)
#   veil.sh accepted <id> [--by <who>] ["<note>"]     the holder: the build is right
#   veil.sh rework   <id> [--by <who>] "<why>"        the holder: the build goes back
#   veil.sh status <id>              one row: the item and where it stands
#   veil.sh wait <id> [--timeout S]  block until RECEIVED (exit 0) or the timeout (exit 4)
#   veil.sh pending [--json]         every item not yet RECEIVED, oldest first, with its age
#   veil.sh sweep [--dry-run]        resend unreceived items into the holder's pane after VEIL_RECEIPT_S,
#                                    and mark the ones past VEIL_RED_S red (the trouble panel's `receipts`)
#   veil.sh --self-test              prove the contract against temporary doors
#
# THE ROADS. `send` hands the line to the arm (bin/voice/rodd-arm.sh tell, class report). When the arm
# refuses (no arm is held) the line goes at once to the holder's herdr pane (bin/agents/eindri-notify.sh,
# the house's pane road to the lock owner). `--queued` records the id only: the caller has already
# queued its own wake (the acclaim does), so the queue is not written twice. An answer (received,
# accepted, rework) is carried back to the sender when the item names --reply-to, through
# bin/agents/tell.sh (a pane, an errand, `arm`, or `hermes:<session>`), so a Hermes agent hears its
# RECEIVED on the same road a pane does. A Hermes session whose gateway is not listening is reached
# through its own command line (`hermes --resume <session> -z`; VEIL_HERMES_CLI names the binary).
#
# THE LEDGER is <state>/veil/ledger.jsonl, one JSON event per line, appended under a lock and never
# rewritten (RULES/06). An item's state is the fold of its events.
#
# Env: VEIL_RECEIPT_S (120) · VEIL_RED_S (600) · VEIL_STATE (default <state>/veil) ·
#      VEIL_TELL_DOOR · VEIL_PANE_DOOR · VEIL_REPLY_DOOR (the three roads; tests point them elsewhere).
# Exit: 0 ok · 1 the road failed · 2 usage · 3 no such item · 4 wait timed out.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
case "${1:-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|'') sed -n '2,39p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --self-test|self-test) exec bash "$ROOT/bin/agents/tests/test_veil.sh" ;;
esac
if [ -z "${VEIL_STATE:-}" ]; then
  _st="${BROKK_STATE_OVERRIDE:-${YMIR_STATE_DIR:-}}"
  if [ -z "$_st" ]; then
    # shellcheck disable=SC1091
    . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null && hoard_state_dir _st 2>/dev/null
  fi
  [ -n "${_st:-}" ] || { printf 'veil: the state dir did not resolve\nhelp: set YMIR_STATE_DIR or VEIL_STATE\n' >&2; exit 1; }
  VEIL_STATE="$_st/veil"
fi
export VEIL_STATE
export VEIL_TELL_DOOR="${VEIL_TELL_DOOR:-$ROOT/bin/voice/rodd-arm.sh}"
export VEIL_PANE_DOOR="${VEIL_PANE_DOOR:-$ROOT/bin/agents/eindri-notify.sh}"
export VEIL_REPLY_DOOR="${VEIL_REPLY_DOOR:-$ROOT/bin/agents/tell.sh}"
exec python3 "$SCRIPT_DIR/veil.py" "$@"

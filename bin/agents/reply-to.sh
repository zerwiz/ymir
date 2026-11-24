#!/usr/bin/env bash
# reply-to.sh — every ask carries its return address (plan 365 R1).
#
#   reply-to.sh resolve [--reply-to <kind>:<address>]   print the address, or refuse (exit 2) when none can be found
#   reply-to.sh record <errand> <address>               keep it with the errand (state/<errand>.replyto)
#   reply-to.sh get <errand>                            print the recorded address
#
# Kinds: hermes:<session> · herdr:<agent|pane> · seat:<machine>/<agent> · telegram:<chat> · issue:<owner/repo>#<n>
# The address comes from, in order: --reply-to, $YMIR_REPLY_TO, the caller's own identity ($HERMES_SESSION_ID,
# $HERDR_PANE_ID). With none of them the ask is refused: a worker that cannot say who to answer ends in silence.
# Works solo: the sender and the worker are on one machine and `herdr:` or `issue:` answer there.
set -u
STATE="${YMIR_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir}"
KINDS='hermes|herdr|seat|telegram|issue'
valid() { printf '%s' "$1" | grep -Eq "^($KINDS):.+"; }

case "${1-}" in
  resolve)
    shift; want=""
    while [ $# -gt 0 ]; do case "$1" in --reply-to) want="${2-}"; shift ;; --reply-to=*) want=${1#--reply-to=} ;; esac; shift; done
    [ -n "$want" ] || want="${YMIR_REPLY_TO:-}"
    [ -n "$want" ] || { [ -n "${HERMES_SESSION_ID:-}" ] && want="hermes:$HERMES_SESSION_ID"; }
    [ -n "$want" ] || { [ -n "${HERDR_PANE_ID:-}" ] && want="herdr:$HERDR_PANE_ID"; }
    if [ -z "$want" ]; then
      echo "refused: this ask carries no return address — pass --reply-to <kind>:<address> (hermes:<session> · herdr:<agent> · seat:<machine>/<agent> · telegram:<chat> · issue:<repo>#<n>)" >&2
      exit 2
    fi
    valid "$want" || { echo "refused: '$want' is not a return address (kinds: hermes · herdr · seat · telegram · issue)" >&2; exit 2; }
    printf '%s\n' "$want" ;;
  record)
    [ $# -eq 3 ] || { echo "usage: reply-to.sh record <errand> <address>" >&2; exit 2; }
    valid "$3" || { echo "refused: '$3' is not a return address" >&2; exit 2; }
    mkdir -p "$STATE"; printf '%s\n' "$3" >"$STATE/$2.replyto" ;;
  get) [ -r "$STATE/${2-}.replyto" ] && cat "$STATE/$2.replyto" || exit 1 ;;
  *) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac

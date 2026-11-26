#!/usr/bin/env bash
# reply.sh — the road back: an answer goes to whoever sent the message, never only into your own transcript.
#
#   reply.sh "<text>"                      answer the last stamped message that reached this pane
#   reply.sh --to <stamp|pane|machine:pane> "<text>"   answer a named sender
#   reply.sh --turn-end                    harness hook: {"session","answer","messages":[{"id","text","since"}]} on stdin
#   reply.sh --claude-stop                 Claude Code Stop hook: its own JSON on stdin
#   reply.sh --parse "<line>"              print the road a stamp names; send nothing
#
# Roads back, read from the stamp (bin/agents/msg-origin.sh): a herdr pane (this machine: eindri-send.sh; another:
# fleet-tell.sh machine:pane) · Rödd (rodd-room.sh, or relayed by the arm holder) · a terminal · Telegram · a Hermes
# session. A script, or a person with no stamped road, has nothing to answer: it is said in words, nothing is sent.
# A pane that cannot take the line is never silent: the arm holder of that machine gets it in the wake queue.
# Every answer is stamped "[reply from …]", and a reply is never answered automatically.
# Env: YMIR_REPLY_AUTO=0 stops the automatic answers · YMIR_REPLY_STATE moves the ledger.
# Exit: 0 delivered, or nothing to do for a hook · 1 not delivered · 2 usage · 3 no way back.
set -u
HERE="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1-}" in -h|--help|"") sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;; esac
if [ "${1-}" != --parse ]; then
  # shellcheck source=bin/agents/msg-origin.sh
  . "$HERE/msg-origin.sh"
  # Who is answering, proved the same way every stamp is. A replier is always an agent.
  YMIR_REPLY_PANE="${YMIR_REPLY_PANE-$(_pane_of_self)}"
  if [ -z "${YMIR_REPLY_ORIGIN:-}" ]; then
    YMIR_REPLY_ORIGIN="$(msg_origin </dev/null)"
    case "$YMIR_REPLY_ORIGIN" in
      "agent "*) ;;
      *) YMIR_REPLY_ORIGIN="agent ${YMIR_SEAT_NAME:-in a session}${YMIR_REPLY_PANE:+ · herdr pane $YMIR_REPLY_PANE} · $(hostname -s 2>/dev/null || uname -n)" ;;
    esac
  fi
  export YMIR_REPLY_PANE YMIR_REPLY_ORIGIN
fi
exec python3 -I "$HERE/reply.py" "$@"

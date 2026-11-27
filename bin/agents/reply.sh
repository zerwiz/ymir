#!/usr/bin/env bash
# reply.sh — the road back: an answer goes to whoever sent the message, never only into your own transcript.
#
#   reply.sh "<text>"                      answer the last stamped message that reached this pane
#   reply.sh --to <stamp|pane|machine:pane> "<text>"   answer a named sender
#   reply.sh --errand <id> "<text>"        send to whoever sent that errand (recorded by sender.sh at dispatch)
#   reply.sh --ask [--errand <id>] "<q>"   file the question under eindri-questions AND send it to that sender
#   reply.sh --turn-end                    harness hook: {"session","answer","messages":[{"id","text","since"}]} on stdin
#   reply.sh --claude-stop                 Claude Code Stop hook: its own JSON on stdin
#   reply.sh --owe                         the wake drain: queue lines on stdin whose senders the holder owes an answer
#   reply.sh --parse "<line>"              print the road a stamp names; send nothing
#   reply.sh --sent <machine> <pane>       eindri-send.sh: this agent sent that pane a line by hand
#
# A message stamped from an agent or a script means the operator is NOT there: the answer goes to the sender and
# nothing is written to him, spoken to him or notified. Only a stamp of his own (the Allfather, Rödd, a person at a
# terminal) opens the roads that reach him.
# A bare reply with no waiting message goes to the sender of this worker's errand ($YMIR_ERRAND_ID, $YMIR_SMITH or
# the eindri/<id> branch).
# Roads back, read from the stamp (bin/agents/msg-origin.sh): an arm holder ("arm <machine>": its wake queue) · a herdr pane (this machine: eindri-send.sh; another:
# fleet-tell.sh machine:pane) · Rödd (rodd-room.sh, or relayed by the arm holder) · a terminal · Telegram · a Hermes
# session. A script, or a person with no stamped road, has nothing to answer: it is said in words, nothing is sent.
# A pane that cannot take the line is never silent: the arm holder of that machine gets it in the wake queue.
# A turn the operator is in (a line of his, typed or stamped) answers HIM: the agents heard in it, steered lines and
# drained wakes alike, get a short receipt and never that answer.
# An agent that already sent the sender a line by hand in the turn (reply.sh or eindri-send.sh) is not copied.
# Every answer is stamped "[reply from …]", and a reply is never answered automatically.
# Env: YMIR_REPLY_AUTO=0 stops the automatic answers · YMIR_REPLY_STATE moves the ledger.
# Exit: 0 delivered, or nothing to do for a hook · 1 not delivered · 2 usage · 3 no way back.
set -u
HERE="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1-}" in -h|--help|"") sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;; esac
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

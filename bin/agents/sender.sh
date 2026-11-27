#!/usr/bin/env bash
# sender.sh — who sent a worker out, kept with the errand, and what the worker is told about answering them.
#
#   sender.sh origin [--sender "<origin>"] [--request "<text>"]     print the sender's origin; record nothing
#   sender.sh record <errand> [--sender "<origin>"] [--request "<text>"] [--shelf <dir>] [--meta <file>]
#   sender.sh get <errand>                                          print the recorded origin
#   sender.sh block <errand> [--sender "<origin>"]                  the brief section: answer your sender directly
#   sender.sh --marker                                              the line a brief is tested against
#
# The sender is, first match wins: --sender · $YMIR_SENDER (a dispatch carried in from another machine) · a stamp
# already leading the request that names a road back (a relayed ask) · the dispatching session itself
# (bin/agents/msg-origin.sh). An origin with no road back (a script, a session with no pane) is given the arm holder
# of this machine, so a result always reaches somebody.
# `record` writes three things: the reply record bin/agents/reply.sh reads (<replies>/errands/<errand>), the
# errand's own record (<shelf>/<errand>.sender), and sender= sender_road= sender_address= sender_machine= in the
# errand's meta when --meta names a file that exists. <shelf> is where the errand's question is filed.
# Exit: 0 ok · 1 nothing recorded · 2 usage.
set -u
HERE="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER='<!-- eindri-sender:v1 -->'
usage() { sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; }

VERB="${1-}"; shift || true
case "$VERB" in
  --marker) printf '%s\n' "$MARKER"; exit 0 ;;
  origin|record|get|block) ;;
  *) usage; exit 2 ;;
esac
ID=""
if [ "$VERB" != origin ]; then
  ID="${1-}"; shift || true
  case "$ID" in ''|-*|.*|*[!A-Za-z0-9._-]*) printf 'sender: not an errand id: "%s"\n' "$ID" >&2; exit 2 ;; esac
fi
SENDER=""; REQUEST=""; SHELF=""; META=""
while [ $# -gt 0 ]; do
  case "$1" in
    --sender)  SENDER="${2-}"; shift 2 || shift ;;
    --request) REQUEST="${2-}"; shift 2 || shift ;;
    --shelf)   SHELF="${2-}"; shift 2 || shift ;;
    --meta)    META="${2-}"; shift 2 || shift ;;
    *) printf 'sender: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done
REPLIES="${YMIR_REPLY_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir/replies}"
ME="${YMIR_REPLY_HOST:-$(hostname -s 2>/dev/null || uname -n)}"
recorded() { sed -n 's/^origin=//p' "$REPLIES/errands/$1" 2>/dev/null | head -1; }

road_of() {  # <origin> → "<road>\t<machine>\t<address>"
  bash "$HERE/reply.sh" --parse "[from $1] x" 2>/dev/null | sed -n '2p' | awk -F'"' '{printf "%s\t%s\t%s", $4, $6, $8}'
}

resolve() {
  local o="${SENDER:-${YMIR_SENDER:-}}" held road last
  if [ -z "$o" ] && [ -n "$REQUEST" ]; then
    held="$(printf '%s\n' "$REQUEST" | sed -n '1s/^[[:space:]]*\[from \([^]]*\)\].*/\1/p')"
    if [ -n "$held" ]; then
      road="$(road_of "$held")"
      case "${road%%$'\t'*}" in ''|none) ;; *) o="$held" ;; esac
    fi
  fi
  if [ -z "$o" ]; then
    # shellcheck source=bin/agents/msg-origin.sh
    o="$( . "$HERE/msg-origin.sh" && msg_origin </dev/null )"
  fi
  o="$(printf '%s' "${o:-script dispatcher · $ME}" | tr '\n\r\t]' '    ')"
  road="$(road_of "$o")"
  case "${road%%$'\t'*}" in
    none)
      last="${o##* · }"
      case "$o" in
        *" · "*) case "$last" in *[!A-Za-z0-9._-]*) last="$ME" ;; *) o="${o% · *}" ;; esac ;;
        *) last="$ME" ;;
      esac
      o="$o · arm $last · $last" ;;
  esac
  printf '%s' "$o"
}

case "$VERB" in
  origin) resolve; printf '\n' ;;
  get) o="$(recorded "$ID")"; [ -n "$o" ] || exit 1; printf '%s\n' "$o" ;;
  record)
    o="$(resolve)"
    if [ -z "$SHELF" ]; then
      # the shelf the arm watches, so a question filed there wakes it
      SHELF="$( . "$HERE/../vault/hoard-lib.sh" >/dev/null 2>&1 && hoard_state_dir _s >/dev/null 2>&1 && printf '%s' "$_s" )"
      SHELF="${SHELF:-$REPLIES}"
    fi
    mkdir -p "$REPLIES/errands" "$SHELF" 2>/dev/null
    printf 'origin=%s\nshelf=%s\nrecorded=%s\n' "$o" "$SHELF" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$REPLIES/errands/$ID" \
      || { printf 'sender: could not write the reply record for %s\n' "$ID" >&2; exit 1; }
    IFS=$'\t' read -r road machine address <<<"$(road_of "$o")"
    block="$(printf 'sender=%s\nsender_road=%s\nsender_address=%s\nsender_machine=%s\n' "$o" "$road" "$address" "$machine")"
    printf '%s\n' "$block" >"$SHELF/$ID.sender" 2>/dev/null || printf 'sender: could not write %s/%s.sender\n' "$SHELF" "$ID" >&2
    if [ -n "$META" ] && [ -f "$META" ]; then
      kept="$(grep -vE '^sender(_road|_address|_machine)?=' "$META")"
      printf '%s\n%s\n' "$kept" "$block" >"$META.sender.$$" && mv "$META.sender.$$" "$META"
    fi
    printf '%s\n' "$o" ;;
  block)
    o="${SENDER:-$(recorded "$ID")}"; [ -n "$o" ] || o="$(resolve)"
    cat <<EOF
$MARKER
## Your sender — answer them directly

You were sent by \`$o\`. They are waiting for a message from you, not for a file.

- **When you finish**, done or failed, send them the result as a message, with the verdict first and the key
  findings in the message itself:
  \`bash $HERE/reply.sh --errand $ID "<done|failed>: <verdict> — <key findings> — <commit or PR>"\`
  The terminal act (\`eindri-acclaim.sh $ID --terminal …\`) sends its own line to them, and in Claude Code and pi
  the turn-end hook sends your final answer. The OpenCode and Hermes hooks are built, not yet proven live.
- **When you need a decision**, ask them directly, then stop and wait for the answer:
  \`bash $HERE/reply.sh --ask --errand $ID "<one question, plain in its first line>"\`
  That one act files the question under \`eindri-questions/$ID.md\` and sends it to your sender.
- The report file is the full record. It is never the only channel.
EOF
    ;;
esac

#!/usr/bin/env bash
# eindri-stall.sh — the arm's stall test: is a WORKING errand still MOVING?
#
# The fault this door exists for (measured 2026-11-20, the Allfather's word that night:
# *"1 yes, this should rodd take care of and the arm"*): two errands sat for hours and
# the sweep judged both ALIVE.
#
#   gimle-catch-up   8h45m on one ssh command — a background process held the session open
#   retired-paths    1h50m on `bash test_dispatch.py` — a python file run by bash, waiting on input
#
# `bin/agents/eindri-liveness.sh` asked the right question for its own fault — is an AGENT
# standing in the pane? — and both panes answered yes, because both held a live agent that
# had handed one command to the shell and was waiting for it. A pane can be alive and
# frozen at once. This is the second question, and it is a different one:
#
#   has the WORK moved in the last N minutes?   (20 by default)
#   has ONE command run past its own limit?     (30 minutes, bin/agents/cmd-limit-lib.sh)
#
# What it does, and only once per stall (keyed by errand and stall start):
#
#   1. a durable wake for the helm, carrying the errand id, the pane and its last 15 lines;
#   2. one line typed into the worker through the existing send door
#      (`bin/agents/eindri-send.sh`): "STALL CHECK from the arm: … check it, or stop it and say why";
#   3. ten minutes later, if the pane still has not moved, ONE message to the operator through
#      the house's notify door (`bin/notify/send.sh`, the Telegram road), with three buttons:
#      look at the pane · stop it · let it run.
#
# A clean fleet is SILENT. That is the whole discipline of this door: it speaks only when a
# worker has stopped moving, and it says nothing twice.
#
# Usage:
#   eindri-stall.sh check [<id> …]   judge and print; change nothing
#   eindri-stall.sh sweep [<id> …]   judge, keep the record, wake · steer · escalate
#   eindri-stall.sh reset <id>       forget one errand's stall (the operator's "let it run")
#   eindri-stall.sh show  [<id> …]   the stall records as they stand
#
# Environment (Rule 07 — env → one documented default):
#   YMIR_STALL_FROZEN_MIN     minutes of no change before a working errand is STUCK (20)
#   YMIR_STALL_ESCALATE_MIN   minutes after the first wake before Rödd tells the operator (10)
#   YMIR_STALL_PANE_LINES     how many last lines the wake and the message carry (15)
#   YMIR_STALL_SEND           0 = record the steer but type nothing into the pane (1)
#   YMIR_STALL_NOTIFY         0 = never message the operator (1)
#   YMIR_STALL_CLOCK          epoch seconds to use as "now" — a test's simulated clock
#   YMIR_STALL_PANE_DIR       a directory of fake panes, `<dir>/<id>.log`, instead of herdr/tmux
#   YMIR_STALL_STATE_DIR      where the per-errand records live (default <state>/eindri-stall)
#   YMIR_STALL_SEND_CMD       override the send door (a test records the line instead of typing)
#   YMIR_STALL_NOTIFY_CMD     override the notify door (a test records the message instead)
#   YMIR_CMD_LIMIT_S          a shell call's default limit in seconds (1800) — see cmd-limit-lib.sh
#
# Exit: 0 nothing is stuck · 3 at least one errand is STUCK · 1 error · 2 usage.
#
# What it will NOT do: judge an errand whose status is not `working` (a closed claim is not a
# claim of movement), act when the pane cannot be read at all (that is UNKNOWN — printed with
# its reason, never a false alarm, RULES/25), or speak twice about one stall.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/hoard-lib.sh" "$SCRIPT_DIR/../../bin/vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
hoard_state_dir YMIR_STATE_DIR
# The seat RECORDS are the HOUSE's, so they resolve from the hoard and never from a
# worker's own harness state (the same reason eindri-liveness.sh resolves it this way:
# a worker inherits BROKK_STATE_OVERRIDE pointing at its pi continuity dir).
STATE="$YMIR_STATE_DIR"

. "$SCRIPT_DIR/eindri-wake-lib.sh"
EINDRI_STATE="$STATE"
. "$SCRIPT_DIR/cmd-limit-lib.sh"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,50p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="${1:-check}"; shift || true

FROZEN_MIN="$( { case "${YMIR_STALL_FROZEN_MIN:-}" in ''|*[!0-9]*) echo 20 ;; *) echo "$YMIR_STALL_FROZEN_MIN" ;; esac; } )"
ESCALATE_MIN="$( { case "${YMIR_STALL_ESCALATE_MIN:-}" in ''|*[!0-9]*) echo 10 ;; *) echo "$YMIR_STALL_ESCALATE_MIN" ;; esac; } )"
PANE_LINES="$( { case "${YMIR_STALL_PANE_LINES:-}" in ''|*[!0-9]*) echo 15 ;; *) echo "$YMIR_STALL_PANE_LINES" ;; esac; } )"
CMD_LIMIT_MIN="$(cmd_limit_minutes)"
RECORDS="${YMIR_STALL_STATE_DIR:-$STATE/eindri-stall}"
AGENTS_READER="$SCRIPT_DIR/../seat/herdr-agents.py"

# --- the clock, and the one way to move it -----------------------------------
# A stall is a claim about elapsed time, so the clock is an INPUT (a test freezes a pane
# and moves the clock instead of waiting 20 real minutes). Everything reads `now`.
now() {
  case "${YMIR_STALL_CLOCK:-}" in
    ''|*[!0-9]*) date +%s ;;
    *) printf '%s' "$YMIR_STALL_CLOCK" ;;
  esac
}

iso() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ; }
mins() { printf '%s' $(( ($1 + 59) / 60 )); }

meta_field() {  # <file> <key>
  sed -n "s/^$2=//p" "$1" 2>/dev/null | head -1
}
last_status() { tail -n1 "$STATE/$1.status" 2>/dev/null || true; }

seats() {  # every id with a meta record, or the ones the caller named
  local f
  if [ $# -gt 0 ]; then printf '%s\n' "$@"; return 0; fi
  for f in "$STATE"/*.meta; do
    [ -f "$f" ] || continue
    basename "$f" .meta
  done
}

# --- the pane, read through the ONE door -------------------------------------
pane_read() {  # <id> <pane> — the pane's visible text; 1 when it cannot be read
  if [ -n "${YMIR_STALL_PANE_DIR:-}" ]; then
    [ -r "$YMIR_STALL_PANE_DIR/$1.log" ] || return 1
    cat "$YMIR_STALL_PANE_DIR/$1.log"
    return 0
  fi
  local backend="$3"
  if [ "$backend" = tmux ]; then
    command -v tmux >/dev/null 2>&1 || return 1
    tmux capture-pane -p -t "$2" 2>/dev/null || return 1
    return 0
  fi
  command -v herdr >/dev/null 2>&1 || return 1
  # `herdr agent read` is the door the helm itself reads a worker through.
  herdr agent read "$2" 2>/dev/null || return 1
}

# A pane that redraws a spinner and a ticking counter is NOT moving — the harness's
# own decoration must never look like progress, or the frozen pane is the one case
# this door would miss. Glyphs, durations and clock faces are normalized away; the
# text a worker actually produced is what is hashed.
normalize() {
  sed -E \
    -e 's/[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏⣾⣽⣻⢿⡿⣟⣯⣷|]/ /g' \
    -e 's/[0-9]+([.][0-9]+)?(s|ms|m[0-9]+s)\b/<dur>/g' \
    -e 's/[0-9]+:[0-9][0-9](:[0-9][0-9])?/<clock>/g' \
    -e 's/[[:space:]]+$//' \
    -e 's/^[[:space:]]+//' \
  | grep -v '^$'
}

tail_lines() {  # <text> <n>
  printf '%s\n' "$1" | tail -n "$2"
}

# The harness footer's token counter when it prints one (`↑438k ↓68k …`). It is a second,
# independent witness of movement: a turn that advances shows up here even when the last
# screenful of text stands still.
token_counter() {  # <text>
  # The pair, both halves on one line: `↑438k ↓68k`. A single number is somebody's
  # prose ("Done in 36m"), not the counter, and must never be read as movement.
  printf '%s\n' "$1" | grep -o '↑[0-9][0-9.]*[km]\?[[:space:]]*↓[0-9][0-9.]*[km]\?' | tail -1
}

# One command's own count, when the pane prints `Elapsed 42m` / `Elapsed: 1h05m`.
elapsed_minutes() {  # <text> — minutes on the LAST `Elapsed` line; empty when absent
  local line h m s re
  line="$(printf '%s\n' "$1" | grep -i 'elapsed' | tail -1)"
  [ -n "$line" ] || return 0
  re='[Ee]lapsed:?[[:space:]]+(([0-9]+)h)?[[:space:]]*(([0-9]+)m)?[[:space:]]*(([0-9]+)s)?'
  if [[ $line =~ $re ]]; then
    h=${BASH_REMATCH[2]:-0}; m=${BASH_REMATCH[4]:-0}; s=${BASH_REMATCH[6]:-0}
    case "$h$m$s" in ''|*[!0-9]*) return 0 ;; esac
    printf '%s' $(( 10#$h * 60 + 10#$m + (10#$s >= 30 ? 1 : 0) ))
  fi
}

# The internal row separator is the unit separator, never a TAB: `read` treats TAB as
# IFS whitespace, and an empty field (a pane with no token counter) would collapse into
# its neighbour and shift every field after it.
US=$'\x1f'
jrow() { local IFS="$US"; printf '%s\n' "$*"; }

# The pane's last lines, for the wake and the operator's message. Read through the same
# door the judgement read it: a fake pane in a test, herdr or tmux in the fleet.
pane_tail() {  # <id> <pane> <backend>
  local backend=$3 text
  if text="$(pane_read "$1" "$2" "$backend")"; then
    printf '%s\n' "$text" | tail -n "$PANE_LINES"
  fi
}

# --- the per-errand record ----------------------------------------------------
record_path() { printf '%s/%s.state' "$RECORDS" "$1"; }
rec_get() {  # <id> <key>
  sed -n "s/^$2=//p" "$(record_path "$1")" 2>/dev/null | head -1
}
rec_set() {  # <id> <key=value> …
  local id=$1 f; shift; f="$(record_path "$id")"
  mkdir -p "$RECORDS" 2>/dev/null || true
  local k v line tmp
  for line in "$@"; do
    k=${line%%=*}; v=${line#*=}
    tmp="$(mktemp "${f}.XXXXXX")" || return 1
    if [ -f "$f" ]; then grep -v "^${k}=" "$f" >"$tmp" 2>/dev/null || true; fi
    printf '%s=%s\n' "$k" "$v" >>"$tmp"
    mv "$tmp" "$f"
  done
}
rec_clear() { rm -f "$(record_path "$1")" 2>/dev/null || true; }

# --- the arms of the door -----------------------------------------------------
steer() {  # <id> <pane> <minutes> — ONE line into the worker, through the existing send door
  local id=$1 pane=$2 m=$3 text
  text="STALL CHECK from the arm: you have been on one command for ${m} minutes. Check it, or stop it and say why."
  if [ -n "${YMIR_STALL_SEND_CMD:-}" ]; then
    printf '%s\t%s\t%s\n' "$id" "$pane" "$text" >>"$YMIR_STALL_SEND_CMD"
    return 0
  fi
  [ "${YMIR_STALL_SEND:-1}" = 0 ] && return 0
  command -v "$SCRIPT_DIR/eindri-send.sh" >/dev/null 2>&1 || return 1
  timeout 60 "$SCRIPT_DIR/eindri-send.sh" --from "the arm" --once "$pane" "$text" >/dev/null 2>&1
}

tell_operator() {  # <id> <pane> <minutes> <lastline> <stall_start>
  local id=$1 pane=$2 m=$3 last=$4 key=$5 msg
  msg="errand ${id} has not moved for ${m} minutes in pane ${pane} — last line: ${last}"
  if [ -n "${YMIR_STALL_NOTIFY_CMD:-}" ]; then
    printf '%s\t%s\n' "$id" "$msg" >>"$YMIR_STALL_NOTIFY_CMD"
    return 0
  fi
  [ "${YMIR_STALL_NOTIFY:-1}" = 0 ] && return 0
  [ -x "$SCRIPT_DIR/../notify/send.sh" ] || return 1
  timeout 90 "$SCRIPT_DIR/../notify/send.sh" \
    --source errand --severity HIGH --key "stall-${id}-${key}" --record "$id" \
    --message "${msg} — look, stop it, or let it run" \
    --button "👀 Look at the pane|Read the pane ${pane} of errand ${id} and tell me what it is waiting on. Then say whether to stop it or let it run." \
    --button "⛔ Stop it|Stop errand ${id} in pane ${pane}: close the command it is stuck on, note why in its status, and leave the branch as it stands." \
    --button "▶️ Let it run|Let errand ${id} carry on: reset its stall record with bin/agents/eindri-stall.sh reset ${id} and say why the wait is expected." \
    >/dev/null 2>&1
}

queue_wake() {  # <id> <pane> <minutes> <reason> <tail>
  local id=$1 pane=$2 m=$3 why=$4 tail=$5 joined line
  joined="$(printf '%s\n' "$tail" | sed '/^$/d' | paste -sd '|' - | cut -c1-1200)"
  line="stall: errand ${id} has not moved for ${m} minutes in pane ${pane} (${why}) — last ${PANE_LINES} lines: ${joined}"
  eindri_queue_wake "$line"
}

# --- the judgement ------------------------------------------------------------
# judge <id> -> unit-separated fields (\x1f, never TAB: TAB is IFS whitespace and an
# empty field would silently collapse into its neighbour — measured while testing this
# door on 2026-11-20, where the empty token counter ate the changed-at clock):
#   verdict · minutes quiet · reason · digest · tokens · changed_at
judge() {
  local id=$1 claim backend pane wt text tail digest tokens changed_at last_digest last_tokens
  local frozen_for elapsed reason lastline
  claim="$(last_status "$id")"
  case "$claim" in
    working*) ;;
    '') jrow IDLE "" "no status line — nothing claims work"; return 0 ;;
    *)  jrow IDLE "" "status is not working: ${claim:0:60}"; return 0 ;;
  esac
  backend="$(meta_field "$STATE/$id.meta" backend)"
  pane="$(meta_field "$STATE/$id.meta" window)"
  wt="$(meta_field "$STATE/$id.meta" worktree)"
  [ -n "$pane" ] || { jrow IDLE "" "no pane recorded in its meta — a seat that was never seated cannot be watched"; return 0; }

  if ! text="$(pane_read "$id" "$pane" "$backend")"; then
    jrow UNKNOWN "" "the pane ${pane} cannot be read on this machine (backend ${backend:-none})"; return 0
  fi
  tail="$(printf '%s\n' "$text" | tail -n "$PANE_LINES")"
  digest="$(printf '%s\n' "$text" | normalize | tail -n "$(( PANE_LINES * 4 ))" | sha1sum | cut -d' ' -f1)"
  tokens="$(token_counter "$(printf '%s\n' "$text" | tail -n 3)")"

  last_digest="$(rec_get "$id" last_hash)"
  last_tokens="$(rec_get "$id" last_tokens)"
  changed_at="$(rec_get "$id" changed_at)"
  case "$changed_at" in ''|*[!0-9]*) changed_at=$(now) ;; esac

  # MOVEMENT: any difference in the text or in the footer's counter. The clock only
  # starts when neither has moved.
  if [ "$digest" != "$last_digest" ] || [ "$tokens" != "$last_tokens" ]; then
    changed_at="$(now)"
  fi

  frozen_for=$(( $(now) - changed_at ))
  elapsed="$(elapsed_minutes "$tail")"
  reason=""; lastline="$(printf '%s\n' "$tail" | sed '/^[[:space:]]*$/d' | tail -1 | cut -c1-200)"

  if [ -n "$elapsed" ] && [ "$elapsed" -ge "$CMD_LIMIT_MIN" ]; then
    reason="one command has run ${elapsed} min, past its ${CMD_LIMIT_MIN} min limit"
  elif [ "$frozen_for" -ge $(( FROZEN_MIN * 60 )) ]; then
    reason="the pane has not moved for $(mins "$frozen_for") min"
  fi

  if [ -n "$reason" ]; then
    jrow "STUCK" "$(mins "$frozen_for")" "$reason" "$digest" "$tokens" "$changed_at"
  elif [ "$frozen_for" -gt 0 ]; then
    jrow "SETTLING" "$(mins "$frozen_for")" "quiet for $(mins "$frozen_for") min, under the ${FROZEN_MIN} min mark" "$digest" "$tokens" "$changed_at"
  else
    jrow "MOVING" 0 "it moved at this poll" "$digest" "$tokens" "$changed_at"
  fi
}

# sweep_one <id> — the record, and the three acts, each exactly once per stall.
sweep_one() {
  local id=$1 row verdict m reason digest tokens changed_at tail pane now_s backend
  local stall_start woke_at escalated lastline act=""
  now_s="$(now)"
  pane="$(meta_field "$STATE/$id.meta" window)"
  backend="$(meta_field "$STATE/$id.meta" backend)"
  row="$(judge "$id")"
  IFS="$US" read -r verdict m reason digest tokens changed_at <<<"$row"

  case "$verdict" in
    IDLE)
      # A closed or absent claim clears the watch: a new stall must be able to fire again.
      rec_clear "$id"
      printf '  "%s","IDLE","%s","%s"\n' "$id" "$pane" "$reason"
      return 0 ;;
    UNKNOWN)
      printf '  "%s","UNKNOWN","%s","%s"\n' "$id" "$pane" "$reason"
      return 0 ;;
    MOVING)
      rec_set "$id" "last_hash=$digest" "last_tokens=$tokens" "changed_at=$changed_at" "polled_at=$now_s"
      rec_unstall "$id"
      printf '  "%s","MOVING","%s","the pane moved at this poll"\n' "$id" "$pane"
      return 0 ;;
    SETTLING)
      rec_set "$id" "last_hash=$digest" "last_tokens=$tokens" "changed_at=$changed_at" "polled_at=$now_s" "verdict=SETTLING"
      printf '  "%s","SETTLING","%s","%s"\n' "$id" "$pane" "$reason"
      return 0 ;;
  esac

  # STUCK — first detection, then the escalation, then silence.
  rec_set "$id" "last_hash=$digest" "last_tokens=$tokens" "changed_at=$changed_at" "polled_at=$now_s" "verdict=STUCK" "reason=$reason"
  tail="$(pane_tail "$id" "$pane" "$backend")"
  lastline="$(printf '%s\n' "$tail" | sed '/^[[:space:]]*$/d' | tail -1 | cut -c1-200)"
  stall_start="$(rec_get "$id" stall_start)"
  if [ -z "$stall_start" ]; then
    rec_set "$id" "stall_start=$now_s" "woke_at=$now_s" "stall_pane=$pane"
    queue_wake "$id" "$pane" "$m" "$reason" "$tail"
    if steer "$id" "$pane" "$m"; then rec_set "$id" "steered=$now_s"; act="woke+steered"; else rec_set "$id" "steer_failed=$now_s"; act="woke, steer FAILED"; fi
  else
    woke_at="$(rec_get "$id" woke_at)"
    escalated="$(rec_get "$id" escalated_at)"
    if [ -z "$escalated" ] && [ $(( now_s - ${woke_at:-$now_s} )) -ge $(( ESCALATE_MIN * 60 )) ]; then
      if tell_operator "$id" "$pane" "$m" "$lastline" "$stall_start"; then
        rec_set "$id" "escalated_at=$now_s"
        act="told the operator"
      else
        rec_set "$id" "tell_failed=$now_s"
        act="the operator could not be reached"
      fi
    else
      act="already woken — nothing new"
    fi
  fi
  printf '  "%s","STUCK","%s","%s — %s"\n' "$id" "$pane" "$reason" "$act"
}

# A worker that moved again returns to a clean watch — but the record of the movement
# (the hash and the clock) must survive, or every poll would look like a fresh start.
rec_unstall() {  # <id>
  local f tmp
  f="$(record_path "$1")"
  [ -f "$f" ] || return 0
  tmp="$(mktemp "${f}.XXXXXX")" || return 0
  grep -vE '^(stall_start|woke_at|stall_pane|steered|steer_failed|escalated_at|tell_failed|verdict|reason)=' "$f" >"$tmp" 2>/dev/null || true
  mv "$tmp" "$f"
}

printf 'stall[%s]{seat,verdict,pane,evidence}:\n' "$(seats "$@" | grep -c . || true)"
STUCK_FOUND=0
for id in $(seats "$@"); do
  [ -n "$id" ] || continue
  case "$ACTION" in
    check)
      IFS="$US" read -r verdict m reason _ <<<"$(judge "$id")"
      printf '  "%s","%s","%s","%s"\n' "$id" "$verdict" "$(meta_field "$STATE/$id.meta" window)" "${reason:-$m}"
      [ "$verdict" = STUCK ] && STUCK_FOUND=$((STUCK_FOUND + 1)) ;;
    sweep)
      sweep_one "$id"
      case "$(rec_get "$id" verdict)" in STUCK) STUCK_FOUND=$((STUCK_FOUND + 1)) ;; esac ;;
    show)
      f="$(record_path "$id")"
      if [ -f "$f" ]; then printf '  "%s","%s","%s","%s"\n' "$id" "$(rec_get "$id" verdict)" "$(rec_get "$id" stall_pane)" "$(rec_get "$id" reason)"; fi ;;
    reset)
      rec_clear "$id"
      printf '  "%s","reset","","the next stall will be judged afresh"\n' "$id" ;;
    *)
      printf 'error: unknown action %s\nhelp: eindri-stall.sh check|sweep|show|reset\n' "$ACTION" >&2; exit 2 ;;
  esac
done
[ "$STUCK_FOUND" -gt 0 ] && exit 3
exit 0

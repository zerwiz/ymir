#!/usr/bin/env bash
# fleet-tell.sh — ONE road for talking to, and steering, any agent on any machine of the fleet.
#
#   fleet-tell.sh [--to <target>]... [--all] [--from <seat>] [--pane-only|--arm-only] [--dry-run] "<line>"
#   fleet-tell.sh --steer  --to <errand>|<machine>:<errand>|<machine>:<pane> "<one line>"
#   fleet-tell.sh --answer --to <errand>|<machine>:<errand> [--record-only] "<the answer>"
#   fleet-tell.sh --stop   --to <errand>|<machine>:<errand>|<machine>:<pane> ["<why>"]
#
# TARGETS (the same for every verb):
#   <machine>                 the arm holder of that machine (a name in the fleet registry)
#   --all                     every arm holder in the fleet registry
#   <errand>                  an errand id on THIS machine
#   <machine>:<errand>        an errand id on that machine
#   <pane>                    a herdr pane id on this machine (wXX:pY)
#   <machine>:<pane>          a pane on that machine (host-a:wBA:p1)
#
# VERBS: tell (default) hands one line · --steer hands a steering line to a worker · --answer answers a
# worker's open question (speak and record, or --record-only) · --stop asks a worker to stop at a safe point.
#
# THE ROADS, in order. On the target machine the tool reuses THAT machine's own door:
#   bin/agents/tell.sh (plan 340.4: arm, herdr panes, Hermes, windows), over ssh when the machine is not this one.
#   An arm holder is also typed into directly, unless --arm-only: a wake in the queue is read at the holder's
#   next turn; a line typed into its pane is read now. When the wire refuses or the arm is not held, the line
#   is typed into the agent's herdr pane (bin/agents/eindri-send.sh, which refuses a pane that is not an agent
#   pane). --pane-only skips the wire. The sender is always named: "<seat> (<machine>)".
#
# THE REPORT: one TOON row per target:
#   fleet-tell[N]{machine,target,verb,holder,arm,pane,typed,why}:
#     arm   = handed | refused | no-answer | -        (the wire; "-" when it was not tried)
#     pane  = <id> | not-found | -
#     typed = yes | sent-unconfirmed | no   (sent-unconfirmed: the line was typed, but the wait for proof
#             that the agent started working ran out — exit 124 or 5 after a send)
#   When the arm was refused and the pane was typed, a wake is raised on the SENDER's own queue:
#   "<machine>'s arm is not held — re-arm needed"; the row says wake=raised, or wake=not-raised(why) when the
#   sender's own arm refused it too and the durable queue could not take it either.
#   A door missing on a far runtime (exit 127) is reported as "door missing on <machine>'s runtime".
#
# Nothing hangs: every ssh and every remote command runs under `timeout`. A tell is HANDED, not done,
# until the agent answers (RULES/49). Exit: 0 every target reached (handed or typed) or a dry run · 1 one or more not · 2 usage.
set -u
ROOT="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
HOME_DIR=""; declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root HOME_DIR 2>/dev/null
REG="${FLEET_TELL_REGISTRY:-$HOME_DIR/hodd/data/fleet.json}"
ME="${FLEET_TELL_ME:-$(hostname -s)}"
LIMIT="${FLEET_TELL_TIMEOUT:-25}"            # a probe (who, tell.sh, ssh reach): short
# A send waits for the line to land: eindri-send.sh sleeps EINDRI_SEND_WAIT after typing and again on a re-send,
# so its limit is twice that wait plus a margin, never the probe limit.
SEND_WAIT="${EINDRI_SEND_WAIT:-20}"
SEND_LIMIT="${FLEET_TELL_SEND_TIMEOUT:-$((2 * SEND_WAIT + 30))}"
PANE_LIMIT="${FLEET_TELL_PANE_TIMEOUT:-$((LIMIT + 25))}"   # arm-holder-pane.sh holds its own inner limits (20 + 10)
seat="$(sed -n 's/^primary=//p' "$HOME/.pi/agent/extensions/.ymir-seat" 2>/dev/null | head -1)"
SEAT="${YMIR_SEAT_NAME:-${seat:-$ME}}"
SIGN=""

usage() { sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'; }
die() { printf 'fleet-tell: %s\n' "$*" >&2; exit 2; }

VERB=tell; ALL=0; DRY=0; MODE=both; RECORD=0; TARGETS=(); LINE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --to) [ -n "${2:-}" ] || die "--to needs a target"; TARGETS+=("$2"); shift 2 ;;
    --all) ALL=1; shift ;;
    --from) [ -n "${2:-}" ] || die "--from needs a seat name"; SEAT="$2"; shift 2 ;;
    --pane-only) MODE=pane; shift ;;
    --arm-only) MODE=arm; shift ;;
    --dry-run) DRY=1; shift ;;
    --steer) VERB=steer; shift ;;
    --answer) VERB=answer; shift ;;
    --stop) VERB=stop; shift ;;
    --record-only) RECORD=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; LINE="$*"; break ;;
    -*) die "unknown flag $1 (see --help)" ;;
    *) LINE="${LINE:+$LINE }$1"; shift ;;
  esac
done
SIGN="$SEAT ($ME)"
[ "$VERB" = stop ] && [ -z "$LINE" ] && LINE="stop at the next safe point: commit what stands, write your report, then stop"
[ "$VERB" = stop ] && case "$LINE" in "stop at the next safe point"*) ;; *) LINE="stop at the next safe point ($LINE): commit what stands, write your report, then stop" ;; esac
[ -n "$LINE" ] || die 'give the line to send (fleet-tell.sh --help)'
case "$LINE" in *$'\n'*) die "one line only — a long message goes in a letter file and the line names it" ;; esac
case "$LINE" in *$'\e'*) die "refusing a line carrying an escape sequence" ;; esac
[ "$ALL" = 1 ] || [ ${#TARGETS[@]} -gt 0 ] || die "name a target: --to <machine|errand|machine:errand|pane> or --all"
[ "$VERB" = answer ] && [ "$ALL" = 1 ] && die "--answer answers one worker's question; name an errand with --to"
[ -r "$REG" ] || die "no fleet registry at $REG — the machines are read from it, never guessed"

reg() {  # reg machines | reg road <machine>
  python3 - "$REG" "$1" "${2:-}" <<'PY'
import json, sys
h = (json.load(open(sys.argv[1])).get("hosts") or {})
if sys.argv[2] == "machines":
    print("\n".join(h))
elif sys.argv[2] == "reach":
    print("\n".join(k for k, v in h.items() if v.get("user") and v.get("tailnet")))
else:
    v = h.get(sys.argv[3]) or {}
    if v.get("user") and v.get("tailnet"): print(f"{v['user']}@{v['tailnet']}")
PY
}
is_machine() { reg machines | grep -qx -- "$1"; }
sq() { printf "'%s'" "${1//\'/\'\\\'\'}"; }

# the far side's runtime: the pin when it has this door's elders, else the checkout
# A non-interactive login shell on the far side has neither herdr's socket nor ~/.local/bin on PATH, so both are
# set here before any door runs; a missing door exits 127 and is named as such (never as "no agent pane").
PRE='export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"; [ -n "${HERDR_SOCKET_PATH:-}" ] || { hs="${XDG_CONFIG_HOME:-$HOME/.config}/herdr/herdr.sock"; [ -S "$hs" ] && export HERDR_SOCKET_PATH="$hs"; }; d=${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}; [ -f "$d/bin/agents/tell.sh" ] || d=$HOME/ymir; cd "$d" || exit 126; '

# rexec <machine> <command…> — run an argv on that machine's runtime. Output on stdout, rc is the command's;
# 255 = ssh could not reach it, 124 = the limit ran out.
rexec() {
  local m="$1"; shift
  local cmd="" a; for a in "$@"; do cmd="$cmd $(sq "$a")"; done
  if [ "$m" = "$ME" ]; then
    timeout "${RLIMIT:-$LIMIT}" bash -c "$PRE$cmd" 2>&1
  else
    local r; r="$(reg road "$m")"
    [ -n "$r" ] || { printf 'no road to %s in the fleet registry\n' "$m"; return 255; }
    timeout "${RLIMIT:-$LIMIT}" ssh -o BatchMode=yes -o ConnectTimeout=6 "$r" "bash -lc $(sq "$PRE$cmd")" 2>&1
  fi
}

ROWS=(); FAILED=0
row() {  # machine target holder arm pane typed why
  local why="${7//\"/\'}"
  ROWS+=("$(printf '  "%s","%s","%s","%s","%s","%s","%s","%s"' "$1" "$2" "$VERB" "$3" "$4" "$5" "$6" "$why")")
  case "$6/$4" in yes/*|sent-unconfirmed/*|*/handed|*/dry-run) ;; *) FAILED=1 ;; esac
}
wake_self() {  # a refused arm that was typed past: tell the sender's own arm; else the durable queue. Sets WAKE_STATE.
  local text="$1" q rc
  WAKE_STATE="not-raised"
  if [ -n "${FLEET_TELL_WAKE_CMD:-}" ]; then
    bash -c "$FLEET_TELL_WAKE_CMD" _ "$text" >/dev/null 2>&1; rc=$?
  else
    timeout 20 bash "$ROOT/bin/voice/rodd-arm.sh" tell --from "fleet-tell" "$text" >/dev/null 2>&1; rc=$?
  fi
  if [ "$rc" -eq 0 ]; then WAKE_STATE="raised"; return 0; fi
  # the sender's own arm refused (it is not held here either): the durable wake queue is read by the next holder
  q="${FLEET_TELL_QUEUE:-$HOME_DIR/state/.wake-queue}"
  if [ -n "$HOME_DIR" ] || [ -n "${FLEET_TELL_QUEUE:-}" ]; then
    if mkdir -p "$(dirname "$q")" 2>/dev/null && printf 'from=fleet-tell to=helm at=%s msg=%s\n' "$(date +%s)" "$text" >>"$q" 2>/dev/null; then
      WAKE_STATE="raised"; return 0
    fi
  fi
  WAKE_STATE="not-raised(the sender's arm refused rc=$rc and the wake queue could not be written)"; return 1
}

wire_state() {  # <rc> → handed | refused | no-answer
  case "$1" in 0) echo handed ;; 255|124) echo no-answer ;; *) echo refused ;; esac
}

# type_pane <machine> <pane-or-errand> <line> → 0 typed · 2 sent-unconfirmed (the line went in; the wait was
# cut short or eindri-send could not see it work) · 3 the door is missing · 1 refused.  Sets TYPED_WHY.
type_pane() {
  local m="$1" p="$2" l="$3" out rc
  out="$(RLIMIT="$SEND_LIMIT" rexec "$m" bash bin/agents/eindri-send.sh --from "$SIGN" "$p" "$l")"; rc=$?
  TYPED_WHY="$(printf '%s' "$out" | tail -1 | cut -c1-90)"
  case "$rc" in
    0) return 0 ;;
    124|5) TYPED_WHY="sent, not confirmed (exit $rc): ${TYPED_WHY:-no output}"; return 2 ;;
    127) TYPED_WHY="door missing on $m's runtime (bin/agents/eindri-send.sh)"; return 3 ;;
    *) return 1 ;;
  esac
}

# ── per-target work ───────────────────────────────────────────────────────────
tell_arm() {  # machine
  local m="$1" arm="-" pane="-" typed=no why="" holder="-" out rc
  local text="$SIGN to the arm holder: $LINE"
  [ "$VERB" = steer ] && text="$SIGN to the arm holder (steer): $LINE"
  [ "$VERB" = stop ] && text="$SIGN to the arm holder: $LINE"
  if [ "$DRY" = 1 ]; then row "$m" "arm holder" "-" "dry-run" "-" no "would hand: $text"; return; fi
  out="$(rexec "$m" bash bin/voice/rodd-arm.sh who)"; rc=$?
  [ "$rc" -eq 0 ] && holder="$(printf '%s' "$out" | sed -n '2p' | cut -d, -f1-2 | tr -d '"')"
  [ -n "$holder" ] || holder="-"
  if [ "$rc" -eq 255 ] || [ "$rc" -eq 124 ]; then
    row "$m" "arm holder" "-" no-answer "-" no "$m did not answer (ssh exit $rc) within ${LIMIT}s"; return
  fi
  if [ "$MODE" != pane ]; then
    out="$(rexec "$m" bash bin/agents/tell.sh --from "$SIGN" arm "$text")"; rc=$?
    if [ "$rc" -eq 127 ] || printf '%s' "$out" | grep -q 'No such file'; then
      out="$(bash "$ROOT/bin/fleet/arm-send.sh" "$m" "$text" 2>&1)"; rc=$?   # its runtime predates tell.sh
      printf '%s' "$out" | grep -q handed && rc=0
    fi
    arm="$(wire_state "$rc")"
    why="$(printf '%s' "$out" | tail -1 | cut -c1-90)"
  fi
  if [ "$MODE" != arm ]; then
    out="$(RLIMIT="$PANE_LIMIT" rexec "$m" bash bin/fleet/arm-holder-pane.sh)"; rc=$?
    pane="$(printf '%s' "$out" | tail -1 | tr -dc '[:alnum:]:._-')"
    if [ "$rc" -eq 0 ] && [ -n "$pane" ] && [ "$pane" != "not-found" ]; then
      type_pane "$m" "$pane" "$text"; rc=$?
      case "$rc" in
        0) typed=yes ;;
        2) typed=sent-unconfirmed; why="the line was typed into pane $pane but not confirmed: $TYPED_WHY" ;;
        *) why="the pane $pane refused: $TYPED_WHY" ;;
      esac
    elif [ "$rc" -eq 127 ]; then
      pane="not-found"; why="${why:+$why · }door missing on $m's runtime (bin/fleet/arm-holder-pane.sh)"
    elif [ "$rc" -eq 124 ] || [ "$rc" -eq 255 ]; then
      pane="not-found"; why="${why:+$why · }$m did not answer the pane lookup (exit $rc)"
    else
      pane="not-found"; why="${why:+$why · }no agent pane for the arm holder on $m"
    fi
  fi
  if [ "$arm" = refused ] && { [ "$typed" = yes ] || [ "$typed" = sent-unconfirmed ]; }; then
    wake_self "$m's arm is not held — re-arm needed"
    why="the arm is not held; the line was typed into pane $pane · wake=$WAKE_STATE: re-arm needed"
  fi
  [ -z "$why" ] && why="ok"
  row "$m" "arm holder" "$holder" "$arm" "$pane" "$typed" "$why"
}

tell_who() {  # machine who   (an errand id or a pane id)
  local m="$1" who="$2" arm="-" pane="-" typed=no why="" out rc line="$LINE"
  case "$VERB" in steer) line="steer: $LINE" ;; esac
  if [ "$DRY" = 1 ]; then row "$m" "$who" "-" "dry-run" "-" no "would hand: [from $SIGN] $line"; return; fi
  if [ "$VERB" = answer ]; then
    local ra=(bash bin/agents/eindri-answer.sh --from "$SIGN"); [ "$RECORD" = 1 ] && ra+=(--record-only)
    out="$(rexec "$m" "${ra[@]}" "$who" "$LINE")"; rc=$?
    arm="$(wire_state "$rc")"; why="$(printf '%s' "$out" | tail -1 | cut -c1-90)"
    if [ "$rc" -eq 3 ]; then row "$m" "$who" "-" refused "-" no "no open question for $who on $m"; return; fi
    if [ "$arm" = refused ] && [ "$RECORD" != 1 ] && [ "$MODE" != arm ]; then
      # the speak half failed (the pane road): type the answer by the pane road, then record it
      type_pane "$m" "$who" "answer: $LINE"; rc=$?
      if [ "$rc" -eq 0 ] || [ "$rc" -eq 2 ]; then
        typed=yes; [ "$rc" -eq 2 ] && typed=sent-unconfirmed; pane="$who"
        rexec "$m" bash bin/agents/eindri-answer.sh --from "$SIGN" --record-only "$who" "$LINE" >/dev/null
        why="the answer was typed into the pane and recorded"
      else why="answer refused: $why · pane: $TYPED_WHY"; fi
    fi
    row "$m" "$who" "-" "$arm" "$pane" "$typed" "${why:-ok}"; return
  fi
  if [ "$MODE" != pane ]; then
    out="$(rexec "$m" bash bin/agents/tell.sh --from "$SIGN" "$who" "$line")"; rc=$?
    arm="$(wire_state "$rc")"; why="$(printf '%s' "$out" | tail -1 | cut -c1-90)"
    if [ "$arm" = no-answer ] && [ "$rc" -eq 255 ]; then
      row "$m" "$who" "-" no-answer "-" no "$m did not answer (exit $rc) within ${LIMIT}s"; return
    fi
  fi
  if [ "$arm" != handed ] && [ "$MODE" != arm ]; then
    type_pane "$m" "$who" "$line"; rc=$?
    case "$rc" in
      0) typed=yes; pane="$who"; why="the wire did not hand it; typed into $who" ;;
      2) typed=sent-unconfirmed; pane="$who"; why="the wire did not hand it; typed into $who, not confirmed: $TYPED_WHY" ;;
      *) pane="not-found"; why="${why:+$why · }pane: $TYPED_WHY" ;;
    esac
  elif [ "$arm" = handed ]; then pane="$who"; fi
  row "$m" "$who" "-" "$arm" "$pane" "$typed" "${why:-ok}"
}

# ── resolve every target → (machine, who) ─────────────────────────────────────
if [ "$ALL" = 1 ]; then
  while IFS= read -r m; do [ -n "$m" ] && TARGETS+=("$m"); done < <(reg reach; is_machine "$ME" && echo "$ME")
fi
declare -A SEEN=()
for t in "${TARGETS[@]}"; do
  [ -n "${SEEN[$t]:-}" ] && continue; SEEN[$t]=1
  if is_machine "$t"; then
    [ "$VERB" = answer ] && { row "$t" "arm holder" "-" refused "-" no "an answer goes to an errand: use --to $t:<errand>"; continue; }
    tell_arm "$t"
  elif [[ "$t" == *:* ]] && is_machine "${t%%:*}"; then
    tell_who "${t%%:*}" "${t#*:}"
  else
    tell_who "$ME" "$t"
  fi
done

printf 'fleet-tell[%s]{machine,target,verb,holder,arm,pane,typed,why}:\n' "${#ROWS[@]}"
printf '%s\n' "${ROWS[@]}"
printf '# %s sent as %s; a tell is HANDED, not done, until the agent answers (RULES/49)\n' "$VERB" "$SIGN" >&2
exit "$FAILED"

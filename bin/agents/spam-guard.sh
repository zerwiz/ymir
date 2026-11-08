#!/usr/bin/env bash
# spam-guard.sh — a model that loops is a fault, and the agent holding the Gná arm hears of it.
#
# THE FAULT (the Allfather, 2026-11-08, reading the domain:tenancy pane): *"dont we have gurads for models
# thats spamming? this are not allwod. ths bust be notifiet do the agent that hold the gna arm."* He was
# right twice — a seated keeper was emitting malformed tool-call markup in a loop ("<||DSML||>", the same
# sentence again and again, 86k tokens up) and nothing in the house noticed. `model-rows-guard` checks the
# catalog's rows, not a running agent's mouth.
#
# WHAT IT JUDGES, and each is a symptom a person would see:
#   repetition   one line repeated ≥N times in the recent window (a loop)
#   markup       malformed tool-call markup in the transcript (a model that cannot call tools)
#   growth       output far beyond a turn's shape, with no state change (burning tokens)
#
# WHAT IT DOES: names the pane, the symptom and the count; injects ONE line into the arm holder's chat
# (bin/agents/eindri-notify.sh); carves a rune; and — only with --stop — closes the offending pane.
# It never decides for a keeper: a stop is the holder's call, and `--stop` is how it is given.
#
#   spam-guard.sh                 # report only
#   spam-guard.sh --stop          # report, then close the spamming panes
#   spam-guard.sh --lines 60 --repeat 5
#   spam-guard.sh --global [--hours 48]   # every workspace's panes AND every session file on this machine
#
# Exit: 0 nothing found · 1 spam found (and named) · 2 usage
set -uo pipefail
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF/../.." && pwd)"
lines=40; repeat=4; stop=0; global=0; hours=48
while [ $# -gt 0 ]; do case "$1" in --stop) stop=1; shift ;; --lines) lines="${2:-40}"; shift 2 ;;
  --repeat) repeat="${2:-4}"; shift 2 ;;
  --global) global=1; shift ;;
  --hours) hours="${2:-48}"; shift 2 ;; -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) printf 'unknown: %s\n' "$1" >&2; exit 2 ;; esac; done

command -v herdr >/dev/null 2>&1 || { printf 'spam-guard: no herdr on this machine — skipped (a skip is a pass)\n'; exit 0; }

found=0
panes="$(timeout 20 herdr agent list 2>/dev/null | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: raise SystemExit(0)
for a in (d.get("result") or {}).get("agents") or []: print(a.get("pane_id") or "")' 2>/dev/null)"

mine=""
[ -x "$ROOT/bin/seat/who.sh" ] && mine="$(timeout 20 "$ROOT/bin/seat/who.sh" --me 2>/dev/null | sed -n 's/.*"\(w[0-9]*:p[0-9]*\)".*/\1/p' | head -1)"

for p in $panes; do
  [ -n "$p" ] || continue
  # the guard's own words live in the holder's transcript; judging it would be the guard accusing itself
  [ -n "$mine" ] && [ "$p" = "$mine" ] && continue
  txt="$(timeout 20 herdr agent read "$p" --source recent-unwrapped --lines "$lines" --format text 2>/dev/null | grep -vE '^\s*$|^─|↑[0-9]|MCP: |mesh: ')"
  [ -n "$txt" ] || continue
  markup="$(printf '%s' "$txt" | grep -cE 'DSML|<\|?\|>|<tool_call>|</tool_call>' || true)"
  worst="$(printf '%s' "$txt" | sed 's/[[:space:]]*$//' | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')"
  worst="${worst:-0}"
  # ── THE DETECTOR SET (read 2026-11-08; the practices below are the industry's, not invented here) ────
  #   generic_repeat   same tool + identical args N times          (Praison, CoderClaw, weft)
  #   poll_no_progress same args AND the same result, repeatedly   (Praison)
  #   ping_pong        A → B → A → B, two states bouncing          (Praison, RunGuard's window)
  #   error_echo       the same error line repeated                (agentop's "thrash", LoopGuard)
  #   ngram            repeated 3-grams as a RATIO of all 3-grams  (REGS-N, Pegasus / ai_tokenopt)
  #   runaway_spend    cost or context climbing with no progress   (LoopGuard, weft UsageLimit)
  # Each is a SYMPTOM a person would name; together they are "this agent is not getting anywhere".
  calls="$(printf '%s' "$txt" | grep -cE '^\s*(bash|read|grep|write|edit|ls|find)\b|\{"command"' || true)"
  preg="$(printf '%s' "$txt" | grep -E '^\s*(bash|read|grep|write|edit|ls|find)\b|\{"command"' | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')"
  errs="$(printf '%s' "$txt" | grep -ciE 'error|refused|failed|traceback|exception' || true)"
  # ping-pong: count short cycles of two distinct lines repeating in order
  pp="$(printf '%s' "$txt" | awk 'NF{print}' | awk 'NR>3 && $0==prev2 {c++} {prev2=prev; prev=$0} END{print c+0}')"
  # n-gram repetition ratio over 3-word shingles
  ng="$(printf '%s' "$txt" | tr -s '[:space:]' ' ' | tr ' ' '\n' | awk 'NF' | awk '{a[NR]=$0} END{
        total=0; dup=0;
        for(i=1;i<=NR-2;i++){ k=a[i]" "a[i+1]" "a[i+2]; total++; if(k in seen) dup++; seen[k]=1 }
        if(total>0) printf "%d", (100*dup/total); else printf "0" }')"
  # the status bar carries spend and context: ↑86k ↓3.7k $0.016 3.0%/1.0M
  cost="$(timeout 15 herdr pane read "$p" --source visible --lines 3 --format text 2>/dev/null | grep -oE '\$[0-9]+\.[0-9]+' | head -1 | tr -d '$')"
  ctx="$(timeout 15 herdr pane read "$p" --source visible --lines 3 --format text 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)?%/[0-9.]+M' | head -1 | cut -d/ -f1 | tr -d '%')"

  why=""
  [ "$markup" -ge 3 ] && why="malformed tool markup x${markup}"
  [ "$worst" -ge "$repeat" ] && why="${why:+$why · }a line repeated x${worst}"
  [ "${preg:-0}" -ge "$repeat" ] && why="${why:+$why · }generic_repeat: one tool call x${preg}"
  [ "${pp:-0}" -ge 2 ] && why="${why:+$why · }ping_pong x${pp}"
  [ "${errs:-0}" -ge 5 ] && why="${why:+$why · }error_echo x${errs}"
  [ "${ng:-0}" -ge 35 ] && why="${why:+$why · }ngram repetition ${ng}%"
  [ -n "${cost:-}" ] && awk -v c="$cost" 'BEGIN{exit !(c>=2.0)}' && why="${why:+$why · }spend \$${cost} in one seat"
  [ -n "${ctx:-}" ] && awk -v c="$ctx" 'BEGIN{exit !(c>=80)}' && why="${why:+$why · }context ${ctx}% full"

  # ONE mention is a quotation; a loop is three. (Measured: the first version accused the arm holder's own
  # pane because the guard had just been written in it.)
  if [ -n "$why" ]; then
    found=$((found+1))
    printf 'spam[1]{pane,symptom,lines,cost,context}:\n  "%s","%s","%s","%s","%s"\n' "$p" "$why" "$lines" "${cost:-?}" "${ctx:-?}"
    # THE GNA ARM, NOT ONLY THE CHAT (the Allfather, 2026-11-08: *"are this connectet to the gna arm now?"*).
    # A turn injected into a pane reaches a LIVE session and nothing else; the arm's queue is what survives
    # a dead one. So the finding is queued durably FIRST, then spoken — and a session that was not there
    # when it happened still meets it at the next drain.
    if [ -r "$ROOT/bin/agents/eindri-wake-lib.sh" ]; then
      # shellcheck source=/dev/null
      # THE LEASE IS THE AUTHORITY, NOT THE PATH (the house's own 2026-11-05 lesson): the arm's queue lives
      # wherever `.arm.lease` says `state=`, which on this fleet is the hoard — two state shelves exist and
      # only the lease-named one is read. Measured: writing to the XDG shelf left the queue at 13 lines
      # while the arm read the hoard's.
      lease_state="$(sed -n 's/.*state=\([^ ]*\).*/\1/p' "$HOME/Documents/ymirhome/state/.arm.lease" 2>/dev/null | head -1)"
      ( export EINDRI_STATE="${lease_state:-${EINDRI_STATE:-${YMIR_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir}}}"
        . "$ROOT/bin/agents/eindri-wake-lib.sh" >/dev/null 2>&1
        eindri_queue_wake "WAKE spam-guard: pane $p — $why (not allowed; the arm holder was told)" ) || true
    fi
    if [ -x "$ROOT/bin/agents/eindri-notify.sh" ]; then
      "$ROOT/bin/agents/eindri-notify.sh" --from spam-guard -- \
        "a model is spamming in pane $p: $why — not allowed; --stop closes the seat" >/dev/null 2>&1 || true
    fi
    [ -x "$ROOT/bin/records/runes-append.sh" ] && \
      "$ROOT/bin/records/runes-append.sh" brokk model-spam --realm work \
        --message "spam-guard: pane $p — $why (allowed: nothing; the arm holder was told)" >/dev/null 2>&1 || true
    [ "$stop" = 1 ] && { timeout 20 herdr pane close "$p" >/dev/null 2>&1 && printf '  closed %s\n' "$p"; }
  fi
done


# ── GLOBAL SWEEP (2026-11-08: "cant we serch for this spamming globally and report?") ────────────────
# Three places a spamming model leaves a trace, and each is searched:
#   1. every pane in every WORKSPACE, not only the agents herdr has detected in this one
#   2. every session file on this machine's disk (~/.pi/agent/sessions/**), by mtime window
#   3. the opencode session store, if it exists
# The live panes are an ALARM; the files are a LEDGER — the fault has happened before and often
# (measured: six files carry the malformed-markup signature, the oldest from 2026-09-17).
if [ "${global:-0}" = 1 ]; then
  printf '\n-- live panes, every workspace --\n'
  for ws in $(timeout 20 herdr workspace list 2>/dev/null | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: raise SystemExit(0)
r=d.get("result") or d
for w in (r.get("workspaces") or []): print(w.get("workspace_id") or "")' 2>/dev/null); do
    [ -n "$ws" ] || continue
    for p in $(timeout 20 herdr pane list --workspace "$ws" 2>/dev/null | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: raise SystemExit(0)
r=d.get("result") or d
for x in (r.get("panes") or []): print(x.get("pane_id") or "")' 2>/dev/null); do
      [ -n "$p" ] || continue
      txt="$(timeout 15 herdr pane read "$p" --source recent-unwrapped --lines "$lines" --format text 2>/dev/null | grep -vE '^\s*$|^─')"
      m="$(printf '%s' "$txt" | grep -cE 'DSML|<tool_call>|</tool_call>' || true)"
      [ "${m:-0}" -ge 3 ] && printf '  live  %s  markup x%s\n' "$p" "$m"
    done
  done

  printf '\n-- session files on disk (last %s hours) --\n' "${hours:-48}"
  n=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    c="$(timeout 20 grep -c 'DSML' "$f" 2>/dev/null || true)"
    [ "${c:-0}" -ge 3 ] || continue
    n=$((n+1))
    printf '  file  %s  markup x%s  (%s)\n' "$(basename "$f")" "$c" "$(date -r "$f" +%H:%M)"
  done < <(find "$HOME/.pi/agent/sessions" -name '*.jsonl' -mmin "-$(( ${hours:-48} * 60 ))" 2>/dev/null | head -400)
  for d in "$HOME/.local/share/opencode" "$HOME/.opencode"; do
    [ -d "$d" ] || continue
    while IFS= read -r f; do
      c="$(timeout 20 grep -c 'DSML' "$f" 2>/dev/null || true)"
      [ "${c:-0}" -ge 3 ] || continue
      n=$((n+1)); printf '  file  %s  markup x%s  (opencode)\n' "$(basename "$f")" "$c"
    done < <(find "$d" -name '*.json*' -mmin "-$(( ${hours:-48} * 60 ))" 2>/dev/null | head -200)
  done
  printf '\n  %s session file(s) carry the signature in this window\n' "$n"
  if [ "$n" -gt 0 ] && [ -x "$ROOT/bin/agents/eindri-notify.sh" ]; then
    "$ROOT/bin/agents/eindri-notify.sh" --from spam-guard -- \
      "global sweep: $n session file(s) in the last ${hours:-48}h carry the malformed-markup loop — the live panes are clean or named above" >/dev/null 2>&1 || true
  fi
fi

[ "$found" -eq 0 ] && { printf 'spam-guard: no seat is spamming (judged %s panes)\n' "$(printf '%s' "$panes" | grep -c .)"; exit 0; }
printf '\nspam-guard: %s seat(s) spamming — the arm holder was told\n' "$found"
exit 1

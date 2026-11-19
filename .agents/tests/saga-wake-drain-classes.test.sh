#!/usr/bin/env bash
# saga-wake-drain.sh — the arm hears people first (plan 328).
#
# Measured 2026-11-19 22:17: 22 wakes pending, drained in arrival order. Rödd's spoken line sat 17th
# behind sixteen errand reports and a colleague's mail sat 21st. These are the plan's "done means",
# each written through the REAL door that files the line (the state door with --class, the errand
# lib, the mail desk's nudge), and read back through the real drain.
# Fenced state: a temp dir, never the operator's queue.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOOR="$ROOT/bin/time/saga-wake-drain.sh"
STATE_DOOR="$ROOT/bin/records/ymir-state.sh"
pass=0; fail=0
ok() { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n       %s\n' "$1" "${2-}"; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home" YMIR_HOME="$T/home/ymirhome"
export BROKK_STATE_OVERRIDE="$T/state" BROKK_MACHINE_STATE_DIR="$T/machine"
mkdir -p "$HOME" "$BROKK_STATE_OVERRIDE" "$BROKK_MACHINE_STATE_DIR"
Q="$BROKK_STATE_OVERRIDE/.wake-queue"
SUBJECT="your instance stays"

# ── the errand doors: nineteen reports and two questions, through eindri_queue_wake ─────────────
EINDRI_STATE="$BROKK_STATE_OVERRIDE"
# shellcheck source=/dev/null
. "$ROOT/bin/agents/eindri-wake-lib.sh"
for i in $(seq 1 10); do eindri_queue_wake "eindri r$i reported: report filed at $T/r$i.md" report; done
eindri_queue_wake "eindri q1 QUESTION: $T/q1.md — answer with bin/agents/eindri-send.sh q1 \"…\"" ask
for i in $(seq 11 19); do eindri_queue_wake "eindri r$i reported: report filed at $T/r$i.md" report; done
# an OLD, unmarked question (written before plan 328) is still an ask
printf '2026-11-19 18:27 CET — eindri q2 QUESTION: %s/q2.md — answer with bin/agents/eindri-send.sh q2 "…"\n' "$T" >>"$Q"

grep -q $'\tclass=report$' "$Q" && ok "the errand door writes class=report" || bad "the errand door writes class=report" "$(head -1 "$Q")"
grep -q $'q1 QUESTION.*\tclass=ask$' "$Q" && ok "the errand door writes class=ask for a question" || bad "the errand door writes class=ask" "$(grep q1 "$Q")"

# ── the mail desk, through its own nudge (its queue pointed into the fence) ─────────────────────
PYTHONPATH="$ROOT/bin/mail" python3 - "$Q" "$SUBJECT" <<'PY' 2>"$T/mail.err" || true
import sys
from pathlib import Path
import gna_notify
gna_notify.local_queue = lambda: Path(sys.argv[1])
said, detail = gna_notify.nudge("mail: 1 new — question · a colleague · " + sys.argv[2] + " (id abc)")
print("mail nudge:", said, detail, file=sys.stderr)
PY
if grep -q $'^mail: 1 new.*\tclass=voice$' "$Q"; then ok "the mail desk writes class=voice"
else bad "the mail desk writes class=voice" "$(cat "$T/mail.err") · $(grep '^mail' "$Q")"
  # keep the remaining proofs honest even when the desk's imports are absent on this machine
  printf 'mail: 1 new — question · a colleague · %s (id abc)\tclass=voice\n' "$SUBJECT" >>"$Q"; fi

# ── Rödd's voice, posted LAST, through the state door the tell uses ─────────────────────────────
"$STATE_DOOR" queue append signal rodd-1 "Rödd (the voice) to the arm holder: todo_add failed writing the list" \
  --queue "$Q" --class voice >/dev/null 2>&1 || bad "the state door takes --class voice" "rc=$?"
tail -n1 "$Q" | grep -q $'\tclass=voice$' && ok "the state door writes the class as a trailing field" \
  || bad "the state door writes the class as a trailing field" "$(tail -n1 "$Q" | cat -A)"
[ "$(tail -n1 "$Q" | cut -f5)" = "Rödd (the voice) to the arm holder: todo_add failed writing the list" ] \
  && ok "the payload field is untouched by the class" || bad "the payload field is untouched by the class" "$(tail -n1 "$Q" | cut -f5)"

[ "$(awk 'END{print NR}' "$Q")" = 23 ] && ok "23 lines queued (19 reports · 2 asks · 2 voices)" || bad "23 lines queued" "$(awk 'END{print NR}' "$Q")"

# ── the drain ───────────────────────────────────────────────────────────────────────────────────
out="$(bash "$DOOR" drain 2>&1)"
first="$(printf '%s\n' "$out" | head -1)"
[ "$first" = "wake classes: voice 2 · ask 2 · report 19" ] && ok "the summary line is printed first" \
  || bad "the summary line is printed first" "$first"

wakes="$(printf '%s\n' "$out" | grep -E '^(WAKE|REPORTS) ')"
pos() { printf '%s\n' "$wakes" | grep -n -m1 -- "$1" | cut -d: -f1; }
p_rodd="$(pos 'Rödd (the voice)')"; p_mail="$(pos 'mail: 1 new')"
p_q1="$(pos 'q1 QUESTION')"; p_q2="$(pos 'q2 QUESTION')"; p_rep="$(pos '^REPORTS ')"
[ "${p_rodd:-99}" -le 2 ] && ok "a voice line posted after nineteen reports is presented before them (position $p_rodd)" \
  || bad "a voice line posted last is presented first" "position ${p_rodd:-none} · $wakes"
[ "${p_mail:-99}" -le 2 ] && ok "the mail is presented with the voice lines" || bad "the mail is presented with the voice lines" "position ${p_mail:-none}"
[ "${p_q1:-99}" -lt "${p_rep:-0}" ] && [ "${p_q2:-99}" -lt "${p_rep:-0}" ] && [ "${p_q1:-0}" -gt 2 ] \
  && ok "a question is never behind a report, and never ahead of a voice" || bad "question order" "q1=$p_q1 q2=$p_q2 reports=$p_rep"
[ "${p_q1:-0}" -lt "${p_q2:-0}" ] && ok "FIFO inside a class (q1 was filed before q2)" || bad "FIFO inside a class" "q1=$p_q1 q2=$p_q2"
if printf '%s\n' "$wakes" | grep -q 'class='; then bad "the class tail is never shown" "$(printf '%s\n' "$wakes" | grep class=)"
else ok "the class tail is never shown"; fi

rep="$(printf '%s\n' "$wakes" | grep '^REPORTS ')"
[ "$(printf '%s\n' "$rep" | grep -c .)" = 1 ] && ok "nineteen reports show as ONE line" || bad "nineteen reports show as one line" "$rep"
case "$rep" in "REPORTS 19 "*) ok "the collapsed line carries the count" ;; *) bad "the collapsed line carries the count" "$rep" ;; esac
miss=""; for i in $(seq 1 19); do case "$rep" in *" r$i,"*|*" r$i ·"*) ;; *) miss="$miss r$i" ;; esac; done
[ -z "$miss" ] && ok "the collapsed line names every id" || bad "the collapsed line names every id" "missing:$miss · $rep"
[ "$(printf '%s\n' "$wakes" | grep -c 'reported: report filed')" = 0 ] && ok "no report is printed loose beside the count" \
  || bad "no report is printed loose" "$(printf '%s\n' "$wakes" | grep -c 'reported:')"

full="$(bash "$DOOR" drain --full 2>&1)"
[ "$(printf '%s\n' "$full" | grep -c '^WAKE .*reported: report filed')" = 19 ] && ok "--full opens every report as its own line" \
  || bad "--full opens every report" "$(printf '%s\n' "$full" | grep -c '^WAKE .*reported:')"
if printf '%s\n' "$full" | grep -q '^REPORTS '; then bad "--full collapses nothing"; else ok "--full collapses nothing"; fi

cls="$(bash "$DOOR" classes 2>&1)"
[ "$cls" = "voice=2 ask=2 report=19" ] && ok "classes answers one machine row" || bad "classes answers one machine row" "$cls"

# ── the ack: exactly the presented lines leave, a later one stays ───────────────────────────────
bash "$DOOR" drain >/dev/null 2>&1
eindri_queue_wake "eindri late reported: report filed after the drain" report
bash "$DOOR" ack >/dev/null 2>&1
[ "$(awk 'END{print NR}' "$Q")" = 1 ] && grep -q 'eindri late reported' "$Q" \
  && ok "the ack removes exactly the presented lines (nineteen reports among them) and keeps the late one" \
  || bad "the ack removes exactly what was presented" "$(cat "$Q" 2>/dev/null)"

# collapsed reports stay individually ackable: three identical copies presented collapsed leave,
# a fourth filed after the presentation stays
: >"$Q"
for i in 1 2 3; do eindri_queue_wake "eindri dup reported: report filed" report; done
bash "$DOOR" drain >/dev/null 2>&1
eindri_queue_wake "eindri dup reported: report filed" report
bash "$DOOR" ack >/dev/null 2>&1
[ "$(awk 'END{print NR}' "$Q")" = 1 ] && ok "the ack is a multiset diff: three collapsed copies leave, the fourth stays" \
  || bad "the ack is a multiset diff" "$(awk 'END{print NR}' "$Q") line(s) left"

# ── old, unmarked lines are classed by their source ─────────────────────────────────────────────
: >"$Q"
printf '2026-11-19 13:26 CET — eindri a1 reported: report filed at x\n' >>"$Q"
printf '1795091210\t104\tsignal\trodd-1\tagent a1 to the arm holder: a1 done: merged\n' >>"$Q"
printf '1795107892\t107\tsignal\trodd-2\tRödd (the voice) to the arm holder: todo_add failed\n' >>"$Q"
printf 'mail: 15 new — question from a colleague: %s\n' "$SUBJECT" >>"$Q"
printf '2026-11-19 16:20 CET — eindri w reported: needs-decision: rebuild or cut\n' >>"$Q"
cls="$(bash "$DOOR" classes 2>&1)"
[ "$cls" = "voice=2 ask=1 report=2" ] && ok "unmarked lines are classed by source (Rödd and mail voice, needs-decision ask, errands report)" \
  || bad "unmarked lines are classed by source" "$cls"
# a lone report is shown whole, never folded into a row of one
: >"$Q"; eindri_queue_wake "eindri solo reported: report filed" report
out="$(bash "$DOOR" drain 2>&1)"
printf '%s\n' "$out" | grep -q '^WAKE .*solo reported' && ok "a lone report is shown whole" || bad "a lone report is shown whole" "$out"

printf 'saga-wake-drain-classes: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]

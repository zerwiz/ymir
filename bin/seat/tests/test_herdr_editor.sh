#!/usr/bin/env bash
# test_herdr_editor.sh — the input-box reader, judged on the two shapes the hall actually draws.
#
# Plan 293 part 5. The reader is the guard in front of a brief: it is what decides "those words
# are the operator's, refuse". So it is tested on its own, against the shapes measured on live
# panes (measured 2026-11-14 on a live pane of this hall) — pi and claude draw the box differently — plus the cases where
# it must say `unknown` rather than guess. No herdr is called: the text goes in on stdin.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
READER="$ROOT/bin/seat/herdr-editor.py"
[ -f "$READER" ] || { printf 'FAIL no %s\n' "$READER"; exit 1; }

ok=0; fail=0
good() { ok=$((ok+1)); printf 'ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [ -n "${2-}" ] && printf '     %s\n' "$2"; }

R="$(printf '─%.0s' $(seq 1 70))"
verdict() {  # verdict <label> <text> <want> [snippet]
  local out got
  out="$(printf '%s\n' "$2" | python3 "$READER" --stdin)"
  got="$(printf '%s' "$out" | sed -n '2p' | cut -d'"' -f4)"
  if [ "$got" = "$3" ]; then
    if [ -z "${4-}" ] || printf '%s' "$out" | grep -qF "$4"; then good "$1"; else bad "$1" "snippet: $(printf '%s' "$out" | sed -n '2p')"; fi
  else bad "$1" "verdict=$got want=$3"; fi
}

# pi: the box lives between the status separator and the rule beneath it.
verdict 'pi box, empty' " a transcript line
── Elapsed 1.2s $(printf '─%.0s' $(seq 1 30))
$R
~/project (main)
mesh: unconfigured" empty

verdict 'pi box, a draft in it' " a transcript line
── Elapsed 1.2s $(printf '─%.0s' $(seq 1 30))
the operator is half way through a sentence
$R
~/project (main)" text 'the operator is half way through'

verdict 'pi box, a two-line draft' "── Elapsed 1.2s $(printf '─%.0s' $(seq 1 30))
first line of the draft
second line of the draft
$R
~/project (main)" text 'second line of the draft'

# claude: the box is bounded by two rules and opens with its own marker.
verdict 'claude box, empty' " some transcript
$R
❯
$R
  ⏵⏵ auto mode on (shift+tab to cycle)" empty

verdict 'claude box, a draft after the marker' " some transcript
$R
❯ fix the thing before you go
$R
  ⏵⏵ auto mode on (shift+tab to cycle)" text 'fix the thing before you go'

# Honesty: what cannot be read is `unknown`, never `empty`.
verdict 'no box at all is unknown, not empty' "just a log line
and another one" unknown

verdict 'a transcript caught as a box is unknown, not a draft' "a line
$(printf 'x\n%.0s' $(seq 1 2))$R
$(for i in $(seq 1 12); do printf 'transcript line %s\n' "$i"; done)$R
~/p" unknown

# The remote road: the far pane's tail is read there and judged here.
out="$(printf '%s\n' "$R" "the draft" "$R" | python3 "$READER" --stdin --lines 40)"
printf '%s' "$out" | grep -q '"text"' && good 'reads a far pane tail from stdin' || bad 'reads a far pane tail from stdin' "$out"

printf '\nherdr-editor: %s ok, %s failed\n' "$ok" "$fail"
[ "$fail" = 0 ]

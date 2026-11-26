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

# claude's grey prompt suggestion (plan 369 item 18): the pane is read with ANSI, and a box whose only
# content is SGR 2 (dim) is a hint, not typed text. Shapes measured 2026-11-25 on four live workers.
E=$(printf '\033')
RA="${E}[0m${E}[38;2;136;136;136m${R}${E}[0m"
verdict 'claude box, a dim suggestion is a suggestion, not text' " some transcript
$RA
❯ ${E}[0m${E}[2mmerge it when the pr comes${E}[0m
$RA
  ⏵⏵ auto mode on" suggestion 'merge it when the pr comes'

verdict 'claude box, normal-colour text still refuses' " some transcript
$RA
❯ ${E}[0m${E}[38;2;255;255;255mfix the thing before you go${E}[0m
$RA
  ⏵⏵ auto mode on" text 'fix the thing before you go'

verdict 'claude box, dim hint beside real text is text' " some transcript
$RA
❯ typed words ${E}[2mand a hint${E}[0m
$RA
  ⏵⏵ auto mode on" text 'typed words'

verdict 'claude box, empty in ansi is empty' " some transcript
$RA
❯ ${E}[0m
$RA
  ⏵⏵ auto mode on" empty

# The marker is followed by a NO-BREAK SPACE (U+00A0) on a real pane, not a plain one. The first line is
# the box line byte for byte as measured 2026-11-25, trailing CR included.
NB=$(printf '\302\240')
verdict 'claude box, real bytes: no-break space then a dim suggestion' " some transcript
$RA
$(printf '\342\235\257\302\240\033[0m\033[2mcut the 60-second sample now\033[0m\r')
$RA
  ⏵⏵ auto mode on" suggestion 'cut the 60-second sample now'

verdict 'claude box, no-break space then normal text still refuses' " some transcript
$RA
❯${NB}${E}[0mfix the thing before you go
$RA
  ⏵⏵ auto mode on" text 'fix the thing before you go'

verdict 'claude box, a bare marker and no-break space is empty' " some transcript
$RA
❯${NB}${E}[0m
$RA
  ⏵⏵ auto mode on" empty

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

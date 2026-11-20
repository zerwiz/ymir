#!/usr/bin/env bash
# test_question_wake.sh — the arm's fourth eye, end to end with a fake errand (plan 339.3, 2026-11-20).
#
# A fake errand files a question. Through the REAL door (bin/agents/eindri-answer.sh) and the REAL
# engine (src/ymir_runtime/watch.py, raise_line):
#
#   · a question 20 minutes old wakes the helm, once
#   · a question 70 minutes old reaches the operator through the hotline, once (a fake send.sh records it)
#   · eindri-answer.sh speaks into the pane (a fake eindri-send.sh), records the answer and moves the file
#   · an answered question wakes nobody, and a send that fails leaves the question open
#
# Nothing real is touched: a temp state dir, a temp root with a fake hotline, a fake sender.
# Exit: 0 every case held · 1 a case failed.
set -u
HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
ROOT="$(dirname "$HERE")"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ymir-question-wake.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
STATE="$TMP/state"; FAKEROOT="$TMP/root"
mkdir -p "$STATE/eindri-questions" "$FAKEROOT/bin/notify"
export YMIR_HOME="$TMP/home" BROKK_STATE_OVERRIDE="$STATE"
mkdir -p "$YMIR_HOME"

printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"%s/hotline.log"\n' "$TMP" >"$FAKEROOT/bin/notify/send.sh"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"%s/sent.log"\nexit "${FAKE_SEND_RC:-0}"\n' "$TMP" >"$TMP/fake-send.sh"
chmod +x "$FAKEROOT/bin/notify/send.sh" "$TMP/fake-send.sh"
export EINDRI_ANSWER_SEND="$TMP/fake-send.sh"

pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$(printf '%s' "$2" | head -6 | tr '\n' ' ')"; }

ask() {  # <id> <minutes old>
  printf 'id=%s\nseat_pane=wFAKE:p%s\n' "$1" "$2" >"$STATE/$1.meta"
  printf 'needs-decision: which base?\n' >"$STATE/$1.status"
  printf '# Which base should I branch from, %s?\n' "$1" >"$STATE/eindri-questions/$1.md"
  touch -d "-$2 minutes" "$STATE/$1.status" "$STATE/eindri-questions/$1.md"
}
raise() {
  PYTHONPATH="$ROOT/src" python3 - "$STATE" "$FAKEROOT" <<'PY'
import dataclasses, sys
from pathlib import Path
from ymir_runtime import watch
from ymir_runtime.tests.support import Recorder, completed
paths = dataclasses.replace(watch.arm_paths({}), state=Path(sys.argv[1]), root=Path(sys.argv[2]))
real = Recorder()
def runner(argv, **kw):
    if str(argv[0]).endswith("send.sh"):
        import subprocess
        return subprocess.run(list(argv), capture_output=True, text=True)
    return real(argv, **kw)
print(watch.question_wake(paths, runner=runner))
PY
}

ask slow 20
line="$(raise)"
case "$line" in "check: errand slow question unanswered for 20 minutes ("*"Which base should I branch from, slow?") ok "a question 20 minutes old wakes the helm" ;; *) bad "a 20-minute question wakes the helm" "$line" ;; esac
[ -z "$(raise)" ] && ok "the same question does not wake twice" || bad "one wake per question" "$(raise)"

ask stuck 70
raise >/dev/null   # the helm's wake first
line="$(raise)"
[ "$line" = "check: errand stuck question unanswered for 70 minutes — sent to the operator" ] \
  && grep -q -- '--severity HIGH' "$TMP/hotline.log" && grep -q 'Worker stuck has waited 70 minutes' "$TMP/hotline.log" \
  && ok "past an hour it reaches the operator through the hotline" || bad "past an hour it reaches the operator" "$line $(cat "$TMP/hotline.log" 2>&1)"
raise >/dev/null
[ "$(grep -c 'Worker stuck' "$TMP/hotline.log")" = 1 ] && ok "the operator is told once" || bad "the operator is told once" "$(cat "$TMP/hotline.log")"

FAKE_SEND_RC=4 "$ROOT/bin/agents/eindri-answer.sh" slow "branch from main" >/dev/null 2>&1
[ $? = 1 ] && [ -f "$STATE/eindri-questions/slow.md" ] && ok "a failed send leaves the question open" || bad "a failed send leaves it open" "$(ls "$STATE/eindri-questions")"

out="$("$ROOT/bin/agents/eindri-answer.sh" --from "the helm" slow "branch from main" 2>&1)"
grep -q 'wFAKE:p20 Answer to your question: branch from main' "$TMP/sent.log" \
  && [ ! -f "$STATE/eindri-questions/slow.md" ] && grep -q '^answer: .* — branch from main (from the helm)' "$STATE/eindri-questions/answered/slow.md" \
  && ok "the answer is spoken into the pane, recorded and moved to answered/" || bad "the answer door" "$out $(cat "$TMP/sent.log" 2>&1)"

ask again 20
"$ROOT/bin/agents/eindri-answer.sh" again --record-only "answered on the call" >/dev/null 2>&1
[ -z "$(raise)" ] && ok "an answered question wakes nobody" || bad "an answered question wakes nobody" "$(raise)"

printf '\nquestion-wake: %s ok · %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]

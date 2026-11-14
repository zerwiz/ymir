#!/usr/bin/env bash
# test_saga_head.sh — Sága's head fits, means what it says, and forgets what is finished
# (plan 275, item 28).
#
# The fault this guards, measured 2026-11-14: one injection was 55–57 KB over 696 lines, of
# which 156 were errands finished days ago, and three SessionStart hooks re-injected it at
# every compaction. The laws proved here, each with a command:
#
#   1. the head is ≤ 60 lines and ≤ 8 KiB, and `--check` FAILS when it is not
#   2. every section answers by name; a name that is not a section is refused (exit 2)
#   3. a finished errand is reported ONCE and then dropped; anything older than the last
#      head (the 156 the old digest printed) is folded away, never re-reported
#   4. an UNKNOWN row — a pane that can never be read here — is reaped once, then gone
#   5. a compaction re-injects the HEAD ONLY (no section bodies, no stages)
#   6. the fixed core lives in ONE file, and BOTH the head and the seat law read it
#   7. ONE SessionStart hook resolves the CURRENT home (a second home is never injected)
#
# Usage: test_saga_head.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
DOOR="$ROOT/bin/time/saga-session-start.sh"
RUNNER="$ROOT/bin/time/saga-sessionstart-run.sh"
CORE="$ROOT/bin/time/saga-head-core.md"
HOOK="$ROOT/.claude/hooks/saga-session.sh"

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
S1="$TMP/state"; mkdir -p "$S1"

printf 'test_saga_head\n'

# ══ 1 · the budget ════════════════════════════════════════════════════════════
out="$(SAGA_STATE_DIR="$S1" bash "$DOOR" --check 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "--check passes on a head within budget" || bad "--check passes on a head within budget" "$out"
printf '%s' "$out" | grep -q 'PASS: the head fits' && ok "--check says PASS and names the numbers" || bad "--check says PASS and names the numbers" "$out"

out="$(SAGA_STATE_DIR="$S1" YMIR_SAGA_HEAD_LINES=5 bash "$DOOR" --check 2>&1)"; rc=$?
[ "$rc" = 1 ] && ok "--check FAILS (exit 1) when the head is over budget" || bad "--check FAILS (exit 1) when the head is over budget" "rc=$rc $out"
printf '%s' "$out" | grep -q 'over budget' && ok "the failure names the budget it broke" || bad "the failure names the budget it broke" "$out"

# ══ 2 · every section answers by name ═════════════════════════════════════════
sections="$(SAGA_STATE_DIR="$S1" bash "$DOOR" --list 2>/dev/null | sed -n 's/^  "\([a-z]*\)",.*/\1/p')"
n_sections="$(printf '%s\n' "$sections" | grep -c .)"
[ "$n_sections" -ge 15 ] && ok "--list names every section ($n_sections)" || bad "--list names every section" "$n_sections"
missing=""
for s in $sections; do
  o="$(SAGA_STATE_DIR="$S1" bash "$DOOR" --section "$s" 2>/dev/null)"
  [ -n "$o" ] || missing="$missing $s"
done
[ -z "$missing" ] && ok "every section answers by name, with output" || bad "every section answers by name" "silent:$missing"

SAGA_STATE_DIR="$S1" bash "$DOOR" --section nonsense >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok "an unknown section is REFUSED (exit 2, never a silent empty)" || bad "an unknown section is REFUSED" "rc=$rc"

# ══ 3 · finished is not news ══════════════════════════════════════════════════
S2="$TMP/news"; mkdir -p "$S2"
mkseat() {  # <dir> <id> <status> <backend> <window> <age-seconds>
  printf 'backend=%s\nwindow=%s\nlaunched=%s\n' "$4" "$5" "$(( $(date +%s) - $6 ))" >"$1/$2.meta"
  printf '%s\n' "$3" >"$1/$2.status"
}
mkseat "$S2" old-done "done: shipped days ago" herdr w1:p1 90000
mkseat "$S2" alive "working: in hand" herdr w2:p1 3600
mkseat "$S2" gone-tmux "working: claimed" tmux @9 90000

head() { SAGA_STATE_DIR="$S2" bash "$DOOR" --head 2>/dev/null; }

r1="$(head)"
printf '%s' "$r1" | grep -q '"alive"' && ok "the head shows a LIVE errand" || bad "the head shows a LIVE errand" "$r1"
printf '%s' "$r1" | grep -q '"old-done"' && bad "a finished errand older than the last head is NOT news" "$r1" \
  || ok "a finished errand older than the last head is NOT news"
printf '%s' "$r1" | grep -q 'first run of the head' && ok "the first run says what it folded away" || bad "the first run says what it folded away" "$r1"
printf '%s' "$r1" | grep -q 'reaped:' && ok "an UNKNOWN row (a tmux pane that cannot be read) is reaped once" || bad "an UNKNOWN row is reaped once" "$r1"

# A head run a minute ago, then a NEW terminal word: that one IS news, exactly once.
printf '%s\n' "$(( $(date +%s) - 60 ))" >"$S2/.saga-head-last-run"
mkseat "$S2" fresh-done "done: just now, PR opened" herdr w3:p1 30
r2="$(head)"
printf '%s' "$r2" | grep -q '"fresh-done"' && ok "a finished errand SINCE the last head is reported" || bad "a finished errand SINCE the last head is reported" "$r2"
printf '%s' "$r2" | grep -q 'reaped:' && bad "the reaped row does not come back" "$r2" || ok "the reaped row does not come back"
r3="$(head)"
printf '%s' "$r3" | grep -q '"fresh-done"' && bad "the finished errand is reported ONCE, then dropped" "$r3" \
  || ok "the finished errand is reported ONCE, then dropped"
printf '%s' "$r3" | grep -q '"alive"' && ok "the live errand is still shown after a finished one leaves" || bad "the live errand is still shown" "$r3"

# The head is measured, never guessed: a recorded run is what makes the next one quiet.
[ -s "$S2/.saga-head-last-run" ] && ok "the head records when it last ran" || bad "the head records when it last ran"

# ══ 4 · a compaction re-injects the head only ════════════════════════════════
: >"$S2/.session-start-complete"
c="$(SAGA_STATE_DIR="$S2" bash "$RUNNER" --source compact 2>/dev/null)"
printf '%s' "$c" | grep -q 'CONTEXT RE-EMIT' && ok "a compaction says it is a re-emit" || bad "a compaction says it is a re-emit" "$(printf '%s' "$c" | head -3)"
n="$(printf '%s\n' "$c" | awk 'END{print NR}')"
[ "$n" -le 62 ] && ok "a compaction injects the head only ($n lines ≤ 62)" || bad "a compaction injects the head only" "$n lines"
printf '%s' "$c" | grep -qE '^== (CONTEXT DIGEST|MODEL CATALOG|SKILLS|TODAY) ==' && bad "no section body rides along on a compaction" "$c" \
  || ok "no section body rides along on a compaction"

# ══ 5 · the fixed core: ONE file, read by the head AND the seat law ══════════
[ -r "$CORE" ] && ok "the fixed core is one file (bin/time/saga-head-core.md)" || bad "the fixed core is one file"
for law in "PUBLIC repo" "PRIVATE repo" "bin/vault/home-sync.sh" "~/ymir-runtime" "eindri-send.sh" "rodd-arm.sh" "skill-find.sh" "in-call.sh" "eindri/<errand>"; do
  grep -qF -- "$law" "$CORE" 2>/dev/null && ok "the core teaches: $law" || bad "the core teaches: $law"
done
grep -q 'saga-head-core.md' "$ROOT/bin/seat/herdr-run.sh" && ok "the seat law (herdr-run.sh) includes the core, never a copy" || bad "the seat law includes the core"
grep -q 'saga-head-core.md' "$ROOT/bin/agents/einherjar-spawn.sh" && ok "the spawn road (einherjar-spawn.sh) includes the core" || bad "the spawn road includes the core"
grep -q 'saga-head-core.md' "$DOOR" && ok "the head prints the same file" || bad "the head prints the same file"
# ONE COPY: no other file in the tree repeats the core's sentence (a second copy is the drift).
copies="$(grep -rl --exclude-dir=.git --exclude-dir=node_modules "is a PUBLIC repo: never a secret" "$ROOT" 2>/dev/null | grep -v "saga-head-core.md" | grep -v "test_saga_head.sh" | grep -v "/docs/fixes/")"
[ -z "$copies" ] && ok "the core exists in exactly one file" || bad "the core exists in exactly one file" "$copies"

# ══ 6 · ONE SessionStart hook, for the CURRENT home ════════════════════════
[ -x "$HOOK" ] || chmod +x "$HOOK" 2>/dev/null
fake_home() {  # <dir> <marker>
  mkdir -p "$1/.pi" "$1/RULES" "$1/bin/time"
  printf '#!/bin/sh\necho "%s"\n' "$2" >"$1/bin/time/saga-sessionstart-run.sh"
  chmod +x "$1/bin/time/saga-sessionstart-run.sh"
}
A="$TMP/home-a"; B="$TMP/home-b"
fake_home "$A" "DIGEST-A"; fake_home "$B" "DIGEST-B"
o="$(printf '{"source":"startup"}' | CLAUDE_PROJECT_DIR="$A" PWD="$B" HOME="$TMP/nohome" bash "$HOOK" 2>/dev/null)"
[ "$o" = "DIGEST-A" ] && ok "the hook runs the home the session is IN (one injection, never three)" || bad "the hook runs the home the session is IN" "$o"
o="$(printf '{}' | env -u CLAUDE_PROJECT_DIR -u BROKK_ROOT_OVERRIDE PWD="$B" HOME="$TMP/nohome" bash -c "cd '$B' && bash '$HOOK'" 2>/dev/null)"
[ "$o" = "DIGEST-B" ] && ok "with no project dir it still resolves the home it stands in" || bad "with no project dir it resolves the home it stands in" "$o"
o="$(env -u CLAUDE_PROJECT_DIR -u BROKK_ROOT_OVERRIDE PWD=/ HOME="$TMP/nohome" bash -c "cd / && bash '$HOOK'" 2>/dev/null)"; rc=$?
[ "$rc" = 0 ] && [ -z "$o" ] && ok "no Ymir on the machine: the hook prints nothing and exits 0" || bad "no Ymir: silence and exit 0" "rc=$rc out=$o"

printf 'test_saga_head: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ] || exit 1
exit 0

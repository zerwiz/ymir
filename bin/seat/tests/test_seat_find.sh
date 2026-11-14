#!/usr/bin/env bash
# test_seat_find.sh — the finder names the pane whose WORK printed the words, and nothing else.
#
# Plan 293 part 6 (2026-11-14). The fault it answers was measured in the hall: the helm briefed
# the wrong worker because its tab title looked right, and the operator had to stop it. So a
# finder must be judged on the cases that would have saved him:
#   * a word printed in one pane and not in another → only the one;
#   * the caller's own pane (where the operator pasted the words) → skipped, and `--all` says so;
#   * every word, versus `--any`;
#   * a word with regex punctuation is a hook, not a pattern;
#   * a pane that cannot be read is COUNTED, never silently dropped.
#
# A stubbed herdr on PATH and a throwaway HOME: no live pane is read and nothing is written
# outside the temp directory.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DOOR="$ROOT/bin/seat/seat-find.sh"
[ -x "$DOOR" ] || { printf 'FAIL no %s\n' "$DOOR"; exit 1; }

ok=0; fail=0
good() { ok=$((ok+1)); printf 'ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; [ -n "${2-}" ] && printf '     %s\n' "$2"; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" YMIR_HOME="$T/home"
mkdir -p "$HOME" "$T/bin" "$T/stub"
export STUB_DIR="$T/stub"

cat >"$T/bin/herdr" <<'STUB'
#!/usr/bin/env bash
S="${STUB_DIR:?}"
case "${1:-} ${2:-}" in
  "pane list")   cat "$S/panes.json" ;;
  "pane current") printf '{"result":{"pane":{"pane_id":"%s"}}}\n' "${STUB_OWN_PANE:-}" ;;
  "pane read")
    pane="${3:-}"; f="$S/pane-${pane//:/_}.txt"
    [ -f "$S/unreadable-$pane" ] && { printf 'the terminal is gone\n' >&2; exit 1; }
    [ -f "$f" ] || { printf 'no such pane\n' >&2; exit 1; }
    cat "$f" ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$T/bin/herdr"

panes() {  # panes <json> — the pane list the stub answers with
  printf '%s\n' "$1" >"$T/stub/panes.json"
}
pane_text() {  # pane_text <pane> <text>
  printf '%s\n' "$2" >"$T/stub/pane-${1//:/_}.txt"
}
find_words() {  # find_words <words> [flags…] — the door under the stub, own pane named by env
  env PATH="$T/bin:$PATH" HERDR_PANE_ID="${OWN_PANE:-}" bash "$DOOR" "$@" >"$T/out" 2>"$T/err"
  echo $?
}

# ── the hall: three agent panes and one bare shell ───────────────────────────────────
panes '{"result":{"panes":[
 {"pane_id":"w1:p1","agent":"pi","agent_status":"done","terminal_title_stripped":"π - ymirhome"},
 {"pane_id":"w1:p2","agent":"claude","agent_status":"idle","terminal_title_stripped":"notes"},
 {"pane_id":"w1:p3","agent":"pi","agent_status":"working","terminal_title_stripped":"π - other"},
 {"pane_id":"w1:p4","terminal_title_stripped":"a plain shell"}]}}'
pane_text w1:p1 'the record now says who spoke each decision; Reygan is he/him'
pane_text w1:p2 'nothing of interest here, only the weather'
pane_text w1:p3 'the plan ledger was renumbered'
pane_text w1:p4 'Reygan is mentioned in this bare shell and must never be named'

# ── 1. one pane printed the word; the bare shell printed it too and is not an agent ──
rc="$(find_words Reygan)"
if grep -q '"w1:p1"' "$T/out" && ! grep -q '"w1:p3"' "$T/out"; then good 'names the pane that printed the word, and only it'
else bad 'names the pane that printed the word, and only it' "$(cat "$T/out")"; fi
if ! grep -q '"w1:p4"' "$T/out"; then good 'a pane with no agent is never searched'; else bad 'a pane with no agent is never searched' "$(cat "$T/out")"; fi
[ "$rc" = 0 ] && good 'exit 0 when something matched' || bad 'exit 0 when something matched' "rc=$rc"

# ── 2. the caller's own pane is skipped, and `--all` includes it ─────────────────────
OWN_PANE=w1:p1 rc="$(OWN_PANE=w1:p1 find_words Reygan)"
if [ "$rc" = 1 ] && ! grep -q '"w1:p1"' "$T/out"; then good 'skips the caller own pane'
else bad 'skips the caller own pane' "rc=$rc $(cat "$T/out")"; fi
grep -q 'own pane w1:p1 was skipped' "$T/out" && good 'and says which pane it skipped' || bad 'and says which pane it skipped' "$(cat "$T/out")"
rc="$(OWN_PANE=w1:p1 find_words Reygan --all)"
grep -q '"w1:p1"' "$T/out" && [ "$rc" = 0 ] && good '--all searches the caller own pane' || bad '--all searches the caller own pane' "rc=$rc $(cat "$T/out")"

# ── 3. every word by default; `--any` for one of them ────────────────────────────────
rc="$(find_words 'renumbered ledger')"
[ "$rc" = 0 ] && grep -q '"w1:p3"' "$T/out" && good 'every word (AND) matches a pane that printed them all'
rc="$(find_words 'renumbered weather')"
[ "$rc" = 1 ] && good 'every word misses a pane that printed only one of them' || bad 'every word misses a pane that printed only one of them' "rc=$rc $(cat "$T/out")"
rc="$(find_words 'renumbered weather' --any)"
if [ "$rc" = 0 ] && grep -q '"w1:p3"' "$T/out" && grep -q '"w1:p2"' "$T/out"; then good '--any matches either word'
else bad '--any matches either word' "rc=$rc $(cat "$T/out")"; fi

# ── 4. a word is a literal hook, never a pattern ─────────────────────────────────────
pane_text w1:p2 'the marker is axb here'
rc="$(find_words 'a.b')"
[ "$rc" = 1 ] && good 'a dot is a literal dot, not a wildcard' || bad 'a dot is a literal dot, not a wildcard' "rc=$rc $(cat "$T/out")"

# ── 5. a pane that cannot be read is counted and named, never dropped quietly ────────
: >"$T/stub/unreadable-w1:p3"
rc="$(find_words Reygan)"
grep -q 'could not be read (w1:p3)' "$T/out" && good 'an unreadable pane is named in the help line' || bad 'an unreadable pane is named in the help line' "$(cat "$T/out")"
rm -f "$T/stub/unreadable-w1:p3"

# ── 6. nothing matched → exit 1 and an honest empty table (not a silent success) ─────
rc="$(find_words 'a word that nobody printed')"
[ "$rc" = 1 ] && grep -q '^seat-find\[0\]' "$T/out" && good 'an honest empty table, and exit 1' || bad 'an honest empty table, and exit 1' "rc=$rc $(cat "$T/out")"

# ── 7. a usage error is a refusal, not an empty search ───────────────────────────────
rc="$(find_words '')"
[ "$rc" = 2 ] && good 'no words is a usage refusal (exit 2)' || bad 'no words is a usage refusal (exit 2)' "rc=$rc"

printf '\nseat-find: %s ok, %s failed\n' "$ok" "$fail"
[ "$fail" = 0 ]

#!/usr/bin/env bash
# test_todos_digest.sh — the session digest counts HIS list, and names the halves apart.
#
# The fault this guards, measured 2026-11-16: `bin/voice/todos.sh --digest` folded only the
# voice's ledger (`hodd/state/voice/todos.jsonl`), which was empty, so Sága's head printed
# `todos: 0` every session while `hodd/life/personal/me/todo.md` held 57 open items. A count
# that is confidently zero about the Allfather's day is worse than no count at all.
#
# The laws proved here, each with a command:
#
#   1. THREE open checkboxes in his list report THREE — the number in the first line
#   2. his half and the house-kept half are counted APART, and the house-kept total splits
#      into derived + from-his-messages
#   3. the voice ledger is its own named count, never folded into his
#   4. a `[x]` line is not an open item
#   5. an ABSENT list says `unable`, and never `open: 0` (a zero is a claim, not a reading)
#   6. the session head carries the same number into `todos: …`
#
# Usage: test_todos_digest.sh
# Exit: 0 all pass · 1 a failure.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$HERE/../../.." && pwd -P)"
DOOR="$ROOT/bin/voice/todos.sh"
HEAD="$ROOT/bin/time/saga-session-start.sh"

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
printf 'test_todos_digest\n'

# ── a home with a list that has three open items in his half ─────────────────
home_with_list() {  # <dir> <his-open> <his-done> <derived-open> <kept-open>
  local d="$1" ho="$2" hd="$3" dv="$4" kp="$5" i
  mkdir -p "$d/hodd/life/personal/me" "$d/hodd/state/voice"
  {
    printf '# The Allfather'"'"'s day — his acts, and what the house knows\n\n'
    printf '# His half — what only he can do\n\n## Today\n\n'
    for ((i = 1; i <= ho; i++)); do printf -- '- [ ] **his act %s** — unblocks it\n' "$i"; done
    for ((i = 1; i <= hd; i++)); do printf -- '- [x] **his done act %s** — closed\n' "$i"; done
    printf '\n# The derived half — what the house measured\n\n## The mail\n\n'
    for ((i = 1; i <= dv; i++)); do printf -- '- [ ] 2026-11-12 · derived item %s\n' "$i"; done
    printf '\n# The house-kept half — what his messages moved\n\n## Today\n\n'
    for ((i = 1; i <= kp; i++)); do printf -- '- [ ] 2026-11-12 · kept item %s (item a%04d)\n' "$i" "$i"; done
  } >"$d/hodd/life/personal/me/todo.md"
}

digest() { YMIR_HOME="$1" bash "$DOOR" --digest 2>&1; }

# ══ 1 · three open items report three ════════════════════════════════════════
H="$T/h1"; home_with_list "$H" 3 0 0 0
out="$(digest "$H")"; first="$(printf '%s\n' "$out" | head -1)"
printf '%s' "$first" | grep -q '^open: 3 —' \
  && ok "three open checkboxes in his list report three" || bad "three open checkboxes report three" "$first"
printf '%s' "$first" | grep -q 'his half 3' \
  && ok "the three are named as his half" || bad "the three are named as his half" "$first"
printf '%s\n' "$out" | grep -c '^- \[his · ' | grep -q '^3$' \
  && ok "three item lines are printed, each tagged his" || bad "three item lines are printed, each tagged his" "$out"

# a ticked line is not an open item
H2="$T/h2"; home_with_list "$H2" 3 2 0 0
printf '%s' "$(digest "$H2" | head -1)" | grep -q '^open: 3 —' \
  && ok "a [x] line is not counted as open" || bad "a [x] line is not counted as open" "$(digest "$H2" | head -1)"

# ══ 2 · the halves are counted apart ═════════════════════════════════════════
H3="$T/h3"; home_with_list "$H3" 3 0 2 4
first="$(digest "$H3" | head -1)"; second="$(digest "$H3" | sed -n 2p)"
printf '%s' "$first" | grep -q '^open: 9 — his half 3 · house-kept 6 · voice ledger 0' \
  && ok "his half and the house-kept half are counted apart (3 + 6 = 9)" || bad "the halves are counted apart" "$first"
printf '%s' "$second" | grep -q 'derived 2 + from his messages 4' \
  && ok "the house-kept total names its own split (derived 2 + messages 4)" || bad "the house-kept split is named" "$second"
printf '%s' "$second" | grep -q 'hodd/life/personal/me/todo.md' \
  && ok "the source file is named on the second line" || bad "the source file is named" "$second"

# ══ 3 · the voice ledger is its own named count ══════════════════════════════
H4="$T/h4"; home_with_list "$H4" 3 0 2 4
printf '{"id":"v1","action":"add","item":"a voiced todo","ts":"2026-11-16T09:00:00Z","project":"personal"}\n' \
  >"$H4/hodd/state/voice/todos.jsonl"
printf '{"id":"v2","action":"add","item":"a voiced todo already done","ts":"2026-11-16T09:01:00Z"}\n' \
  >>"$H4/hodd/state/voice/todos.jsonl"
printf '{"id":"v2","action":"done","ts":"2026-11-16T09:02:00Z"}\n' >>"$H4/hodd/state/voice/todos.jsonl"
first="$(digest "$H4" | head -1)"
printf '%s' "$first" | grep -q 'his half 3 · house-kept 6 · voice ledger 1' \
  && ok "the voice ledger keeps its own named count (1) and never joins his" || bad "the voice ledger is its own count" "$first"
digest "$H4" | grep -q '^- \[voice · ' \
  && ok "a voiced item is tagged voice, not his" || bad "a voiced item is tagged voice" "$(digest "$H4" | tail -2)"

# ══ 4 · an absent list says unable, never zero ═══════════════════════════════
H5="$T/h5"; mkdir -p "$H5/hodd"
first="$(digest "$H5" | head -1)"
printf '%s' "$first" | grep -q '^open: unable' \
  && ok "an absent list prints unable" || bad "an absent list prints unable" "$first"
printf '%s' "$first" | grep -q '^open: 0' \
  && bad "an absent list never claims zero" "$first" || ok "an absent list never claims zero"
YMIR_HOME="$H5" bash "$DOOR" 2>&1 | grep -q '^unable: his list' \
  && ok "the plain list also says unable rather than 'no open items'" || bad "the plain list also says unable" "$(YMIR_HOME="$H5" bash "$DOOR" 2>&1)"

# ══ 5 · the session head carries the same number ═════════════════════════════
S="$T/state"; mkdir -p "$S"
line="$(YMIR_HOME="$H3" SAGA_STATE_DIR="$S" timeout 25 bash "$HEAD" --head 2>/dev/null | sed -n 's/.*\(todos: .*\)$/\1/p' | head -1)"
printf '%s' "$line" | grep -q 'todos: 9 — his half 3 · house-kept 6' \
  && ok "the head prints todos 9 — his half 3 · house-kept 6" || bad "the head carries the count" "$line"
YMIR_HOME="$H3" SAGA_STATE_DIR="$S" timeout 25 bash "$HEAD" --head 2>/dev/null | grep -q 'todos: 0' \
  && bad "the head never prints a bare zero over a list that holds open items" \
  || ok "the head never prints a bare zero over a list that holds open items"

printf 'test_todos_digest: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

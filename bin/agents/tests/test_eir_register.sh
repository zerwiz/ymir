#!/usr/bin/env bash
# test_eir_register.sh — plan 278: Eir reads one register, mends by risk class, and never leaves a broken
# row without a reason.
#   1. config/surfaces.yaml parses, and every row has a check in Eir (s_<name>) — and every surface in Eir's
#      fallback list has a row, so the register and the script cannot drift apart
#   2. a deliberately broken `safe` surface is mended by `fix --safe` and named as mended
#   3. a broken `ask` surface is NOT mended by `fix --safe`; it is named as owed with the exact command
#   4. a `never` surface is never mended, even when asked by name
#   5. asked by name, an `ask` surface is mended (the operator's word)
#   6. `check` names every broken surface, gives each a reason, and prints `owed: <surface> <risk>`
#   7. a malformed register is refused, and Eir falls back to its own list
#   8. the a2abridge surface is red when the engine's unit boots with a target a user manager never reaches
# Usage: test_eir_register.sh      Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT="$(cd "$HERE/../../.." && pwd)"
EIR="$HERE/../eir-doctor.sh"
READER="$HERE/../surfaces.py"
pass=0; fail=0
t() { local name=$1; shift; if "$@"; then printf '  ok   %s\n' "$name"; pass=$((pass+1)); else printf '  FAIL %s\n' "$name"; fail=$((fail+1)); fi; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# 1 — the real register against the real script
rows="$(python3 -I "$READER" "$ROOT/config/surfaces.yaml")"; rc=$?
t "the register parses" [ "$rc" -eq 0 ] && [ -n "$rows" ]
missing=""
while IFS=$'\t' read -r n _; do grep -q "^s_$n()" "$EIR" || missing="$missing $n"; done <<<"$rows"
t "every register row has a check in Eir (missing:${missing:- none})" [ -z "$missing" ]
fallback="$(sed -n 's/^SURFACES=(\(.*\))$/\1/p' "$EIR")"
unlisted=""
for n in $fallback; do printf '%s\n' "$rows" | cut -f1 | grep -qxF "$n" || unlisted="$unlisted $n"; done
t "every surface in Eir's fallback list has a register row (unlisted:${unlisted:- none})" [ -z "$unlisted" ]

# 2–6 — a test register of four fake surfaces, so no real mend can run
cat >"$T/surfaces.yaml" <<'Y'
version: 1
surfaces:
  - { name: tsafe,  risk: safe,  roles: all, why: "test" }
  - { name: task,   risk: ask,   roles: all, why: "test" }
  - { name: tnever, risk: never, roles: all, why: "test" }
  - { name: tgood,  risk: safe,  roles: all, why: "test" }
Y
cat >"$T/fake.sh" <<F
s_tsafe()  { [ -f "$T/tsafe.ok" ]; }
f_tsafe()  { touch "$T/tsafe.ok"; }
s_task()   { [ -f "$T/task.ok" ]; }
f_task()   { touch "$T/task.ok"; }
s_tnever() { [ -f "$T/tnever.ok" ]; }
f_tnever() { touch "$T/tnever.ok"; }
s_tgood()  { return 0; }
F
run() { YMIR_EIR_TEST=1 YMIR_EIR_TEST_SURFACES="$T/fake.sh" YMIR_EIR_REGISTER="$T/surfaces.yaml" YMIR_EIR_ROLES="" \
        bash "$EIR" "$@" 2>&1; }

out="$(run fix --safe)"
t "fix --safe mends the safe surface" grep -q '^eir: mended tsafe$' <<<"$out"
t "fix --safe leaves the ask surface alone" [ ! -f "$T/task.ok" ]
t "the ask surface is owed, with the exact command" grep -q '^eir: owed task (ask) — bin/agents/eir-doctor.sh fix task$' <<<"$out"
t "the never surface is owed, never mended" bash -c 'grep -q "^eir: owed tnever (never)" <<<"$0" && [ ! -f "$1" ]' "$out" "$T/tnever.ok"

out="$(run fix tnever)"
t "a never surface is not mended even by name" [ ! -f "$T/tnever.ok" ]
out="$(run fix task)"
t "an ask surface asked for by name is mended" bash -c 'grep -q "^eir: mended task$" <<<"$0" && [ -f "$1" ]' "$out" "$T/task.ok"

rm -f "$T/task.ok"
out="$(run check)"; rc=$?
t "check exits 1 with broken surfaces" [ "$rc" -eq 1 ]
t "check names the broken surface" grep -q '^  "task","broken",' <<<"$out"
t "a broken row is never without a reason" bash -c '! grep -q "\"broken\",\"\"$" <<<"$0"' "$out"
t "check prints the owed rows with their risk" bash -c 'grep -qx "owed: task ask" <<<"$0" && grep -qx "owed: tnever never" <<<"$0"' "$out"
t "a healthy surface is not owed" bash -c '! grep -q "owed: tgood" <<<"$0"' "$out"
t "the header counts the broken" grep -q '^  "check",".*",2$' <<<"$out"

# 7
printf 'surfaces:\n  - { name: x, risk: maybe }\n' >"$T/bad.yaml"
python3 -I "$READER" "$T/bad.yaml" >/dev/null 2>&1
t "a register with an unknown risk class is refused" [ $? -eq 1 ]
printf 'surfaces:\n  - { name: x, risk: safe }\n  - { name: x, risk: ask }\n' >"$T/dup.yaml"
python3 -I "$READER" "$T/dup.yaml" >/dev/null 2>&1
t "a register naming a surface twice is refused" [ $? -eq 1 ]

# 8 — the a2abridge boot target, judged from a fake unit and a fake engine
mkdir -p "$T/a2a/bin"; printf '#!/bin/sh\necho "a2abridge 0.0"\n' >"$T/a2a/bin/a2abridge"; chmod +x "$T/a2a/bin/a2abridge"
printf '[Install]\nWantedBy=multi-user.target\n' >"$T/a2a.service"
fault="$(A2ABRIDGE_BIN="$T/a2a/bin/a2abridge" YMIR_A2AB_UNIT="$T/a2a.service" bash -c '
  eval "$(sed -n "/^A2AB_BIN=/,/^s_a2abridge()/p" "$0")"; a2ab_fault' "$EIR")"
t "a2abridge: a unit on multi-user.target is a named fault" grep -q 'multi-user.target, which a user manager never reaches' <<<"$fault"
fault="$(A2ABRIDGE_BIN="$T/none" YMIR_A2AB_UNIT="$T/a2a.service" bash -c '
  eval "$(sed -n "/^A2AB_BIN=/,/^s_a2abridge()/p" "$0")"; a2ab_fault' "$EIR")"
t "a2abridge: no engine is a clean pass (the mesh is optional)" [ -z "$fault" ]

printf 'test_eir_register: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]

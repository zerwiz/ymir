#!/usr/bin/env bash
# test_update_loop_proof.sh — plan 002 §6.2: a candidate is PROVEN ONCE, and the heart flips.
#
# WHY. On 2026-11-17 the heart ran the whole gate suite every fifteen minutes and failed on the
# same candidate `abd366869e90`, from noon until night: `PROVE,FAIL` → build+prove again in fifteen
# minutes → `PROVE,FAIL`. 6m06s of CPU and a fresh round of memory pressure each time, forever,
# because nothing recorded that this sha had already been measured. A proof is a fact about a
# COMMIT; measuring it twice on the machine that must not build teaches nobody anything.
#
# WHAT THIS PROVES, each one a command and its printed output:
#   1. the FIRST pass proves once — the suite runs exactly once — and RECORDS the outcome
#   2. the SECOND pass reads the record: it prints `PROVE,already-proven,fail`, runs the suite
#      ZERO times, exits 4 (held), and never repeats the heavy job for that sha
#   3. a PASSING proof written by ANOTHER machine makes the heart flip without proving at all
#   4. `decide` names the verdict for a candidate, which is the command a person reads
#   5. a proof edited after the fact fails its digest and is treated as no proof at all
#
# The gate suite, the release build, the flip and the health check are fixtures here — this test
# is about the DECISION the loop makes and how many times it makes the heavy work happen, not
# about npm or systemd. `bin/heavy-slot.sh` is the real door, so the loop also takes the slot.
set -uo pipefail
REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
pass=0; fail=0
t() { local name=$1; shift; if "$@"; then printf '  ok   %s\n' "$name"; pass=$((pass+1)); else printf '  FAIL %s\n' "$name"; fail=$((fail+1)); fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
# the loop logs its proof to ${TMPDIR:-/tmp}/ul-prove.log: without its own TMPDIR this fixture overwrote the REAL
# loop's log while the real ci-verify ran this very test, and the heart's proof record then named this fixture's
# FAIL row as the failed gate (the heart, 149f38ebd294, 2026-11-20)
mkdir -p "$T/tmp"; export TMPDIR="$T/tmp"
export YMIR_HOME="$T/ymirhome" YMIR_RELEASES_DIR="$T/releases" YMIR_CURRENT_LINK="$T/current" \
       YMIR_SHARED_DIR="$T/shared" YMIR_PROOFS_DIR="$T/proofs" XDG_STATE_HOME="$T/state" \
       YMIR_HEAVY_SLOT="$T/state/heavy-slot.lock" YMIR_HEAVY_SLOT_HELD=0
mkdir -p "$YMIR_HOME/config" "$T/repo/bin/engine" "$T/repo/bin/gates"

# ── the fixture: a git checkout whose origin/main is HEAD ────────────────────
R="$T/repo"
( cd "$R" && git init -q . && git config user.email t@example.invalid && git config user.name test \
  && echo fixture >README.md && git add README.md && git commit -qm fixture \
  && git update-ref refs/remotes/origin/main HEAD ) >/dev/null 2>&1
SHA="$(git -C "$R" rev-parse HEAD)"; ID="${SHA:0:12}"

# the REAL doors under test
cp "$REPO_ROOT/bin/engine/update-loop.sh" "$R/bin/engine/update-loop.sh"
cp "$REPO_ROOT/bin/engine/release-lib.sh" "$R/bin/engine/release-lib.sh"
cp "$REPO_ROOT/bin/heavy-slot.sh" "$R/bin/heavy-slot.sh"
LOOP="$R/bin/engine/update-loop.sh"

# the fixtures the loop calls
cat >"$R/bin/gates/ci-verify.sh" <<'CI'
#!/usr/bin/env bash
echo x >>"$PROVE_COUNTER"
printf 'ci_verify[1]{gate,status,detail}:\n  "fixture","FAIL","the suite is red on purpose, and this test counts how often it ran"\n'
exit 1
CI
cat >"$R/bin/engine/release-build.sh" <<'BUILD'
#!/usr/bin/env bash
. "$(dirname "$0")/release-lib.sh"; release_config
id="$(git -C "$(dirname "$0")/../.." rev-parse --short=12 "$1" 2>/dev/null)"; id="${id:0:12}"
d="$(release_dir_for "$id")"; mkdir -p "$d"
printf '{"release":"%s"}\n' "$id" >"$d/RELEASE-MANIFEST.json"
echo "STAGE-STUB $id"
BUILD
cat >"$R/bin/engine/release-flip.sh" <<'FLIP'
#!/usr/bin/env bash
. "$(dirname "$0")/release-lib.sh"; release_config
id="$1"
mkdir -p "$YMIR_RELEASES_DIR/$id"
ln -sfn "$YMIR_RELEASES_DIR/$id" "$YMIR_CURRENT_LINK"
echo "FLIP-STUB $id"
FLIP
cat >"$R/bin/engine/release-health.sh" <<'HEALTH'
#!/usr/bin/env bash
echo "HEALTH-STUB ok"
HEALTH
chmod +x "$R/bin/gates/ci-verify.sh" "$R/bin/engine/release-build.sh" \
         "$R/bin/engine/release-flip.sh" "$R/bin/engine/release-health.sh" \
         "$R/bin/engine/update-loop.sh" "$R/bin/heavy-slot.sh"
export PROVE_COUNTER="$T/prove-count"; : >"$PROVE_COUNTER"
runs() { wc -l <"$PROVE_COUNTER" | tr -d ' '; }

# ── 1. the first pass proves ONCE and records it ─────────────────────────────
"$LOOP" run >"$T/p1.out" 2>&1; rc1=$?
first_said_once()    { grep -q "^PROVE,once,$ID" "$T/p1.out"; }
first_ran_once()     { [ "$(runs)" = 1 ]; }
first_recorded()     { PROVE_COUNTER=/dev/null bash -c '. "$1/bin/engine/release-lib.sh"; release_config; release_proof_verify "$2"' _ "$R" "$ID" >/dev/null 2>&1 || true
                       [ -r "$YMIR_PROOFS_DIR/$ID.proof" ] && grep -qx 'result=fail' "$YMIR_PROOFS_DIR/$ID.proof"; }
first_held()         { [ "$rc1" -eq 1 ] && grep -q '^HOLD,proven red' "$T/p1.out"; }
t "the first pass proves once (PROVE,once)"                    first_said_once
t "the suite ran exactly once"                                 first_ran_once
t "the outcome was RECORDED as fail"                           first_recorded
t "the first pass says it held (exit 1)"                       first_held

# ── 2. the second pass reads the record and does NOT prove again ─────────────
"$LOOP" run >"$T/p2.out" 2>&1; rc2=$?
second_reads()    { grep -q "^PROVE,already-proven,fail $ID" "$T/p2.out"; }
second_quiet()    { [ "$(runs)" = 1 ]; }
second_held()     { [ "$rc2" -eq 4 ] && grep -q '^HOLD,main is not proven' "$T/p2.out"; }
second_no_build() { ! grep -q 'STAGE-STUB' "$T/p2.out"; }
t "the second pass prints PROVE,already-proven,fail"           second_reads
t "the suite did NOT run again (still 1 run over the sha)"     second_quiet
t "the second pass holds with exit 4"                          second_held
t "no build was attempted for an already-proven heart"         second_no_build

# ── 4. decide is the command a person reads ─────────────────────────────────
"$LOOP" decide "$ID" >"$T/d.out" 2>&1; rcd=$?
decide_names()  { grep -q '"already-proven-fail"' "$T/d.out" && grep -q 'proven 20' "$T/d.out"; }
decide_holds()  { [ "$rcd" -eq 4 ]; }
t "decide names the verdict for the candidate"                 decide_names
t "decide exits 4 for a proven-red candidate"                  decide_holds

# ── 3. a PASS proof from ANOTHER machine makes the heart flip ───────────────
"$LOOP" proof-record "$ID" --result pass --source forge-builder --detail "the forge ran the suite" >"$T/r.out" 2>&1
recorded()   { grep -q "^proof-recorded" "$T/r.out"; }
"$LOOP" run >"$T/p3.out" 2>&1; rc3=$?
flips()      { grep -q "^PROVE,already-proven,$ID" "$T/p3.out" && grep -q '^FLIP,ok' "$T/p3.out"; }
no_prove()   { [ "$(runs)" = 1 ]; }
t "a proof from the forge is recorded"                         recorded
t "the heart VERIFIES the proof and flips the release"          flips
t "flipping never proved anything on this machine (still 1)"   no_prove
t "the flip run exits 0"                                       [ "$rc3" -eq 0 ]

# ── 5. an edited proof is no proof ──────────────────────────────────────────
tampered() {
  sed -i 's/^result=pass/result=fail/' "$YMIR_PROOFS_DIR/$ID.proof"
  . "$R/bin/engine/release-lib.sh"; release_config
  ! release_proof_verify "$ID"
}
t "a proof edited after the fact fails its digest"             tampered

# ── the slot was used, and given back ───────────────────────────────────────
slot_free() { [ ! -e "$YMIR_HEAVY_SLOT" ]; }
t "the updater took the machine's heavy slot and released it"   slot_free

printf 'update-loop proof: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

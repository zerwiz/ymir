#!/usr/bin/env bash
# test_arm_never_lost.sh — the arm is never lost without a word.
#
# At the Allfather's word, 2026-11-20: "we need to fix so the arm cant randomly lose".
# Measured on this seat the night before, on heimdall: the helm changed hands four
# times in ninety minutes —
#
#   2026-11-19 02:35  pi 2243828 held it
#   2026-11-20 00:34  claude 1074973 took it (its SessionStart hook ran Sága)
#   2026-11-20 01:05  pi 2354925 took it again — while claude 1074973 was STILL ALIVE
#   2026-11-20 01:06  claude 2425137 took it — while pi 2354925 was STILL ALIVE
#
# — and `state/` held no line anywhere saying the arm had moved. A live hand lost
# the helm and was never told, so three sessions each believed they were the helm
# and the room went quiet.
#
# EVERY ASSERTION HERE IS ONE LINE, and each names the road it proves. The state is
# a temp dir; every process this test starts is killed by PID on exit; no live lock,
# no real pane and no real home is touched (`YMIR_LOCK_ANNOUNCE=0`, a stub herdr,
# a recording send door).
#
#   bash bin/seat/tests/test_arm_never_lost.sh
#
# Exit: 0 all passed · 1 a failure (each printed as `FAIL - …`).
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# The lock's liveness (a zombie, a recycled pid) and the pane proof both read /proc.
# A seat without it is a clean skip, never a pile of red (RULES/25).
[ -r /proc/self/stat ] || {
  printf 'SKIP - no /proc on this seat: the lock liveness and the pane proof are Linux roads, nothing to prove here\n'
  exit 0
}
# OUTSIDE the seat's own tmp. `is_seat()` reads `*/ymir/seats/*` out of
# BROKK_MACHINE_STATE_DIR, and a worker's TMPDIR lives under exactly that path — a
# sandbox parked there would make this test believe it is a seat and skip the very
# guard it is proving.
T="$(mktemp -d "${ARM_TEST_ROOT:-/tmp}/arm-never-lost.XXXXXX")"
pass=0; fail=0
ok()  { pass=$((pass + 1)); printf 'PASS - %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL - %s\n' "$1"; [ $# -gt 1 ] && printf '       %s\n' "$2"; }
check() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3" "expected [$2] got [$1]"; fi }

PIDS=()
cleanup() {
  local p
  for p in ${PIDS[@]+"${PIDS[@]}"}; do kill -9 "$p" 2>/dev/null || true; done
  rm -rf "$T"
}
trap cleanup EXIT

# ── the sandbox: its own state, its own home, no announcement ───────────────
export BROKK_HOME="$T/home"
export BROKK_STATE_OVERRIDE="$T/state"
export BROKK_MACHINE_STATE_DIR="$T/machine"
export YMIR_LOCK_ANNOUNCE=0
export SAGA_STATE_DIR="$T/state"
mkdir -p "$T/home" "$T/state" "$T/machine" "$T/bin"
unset BROKK_SESSION_PID BROKK_TAKE_HELM 2>/dev/null || true

STATE_DOOR="$ROOT/bin/records/ymir-state.sh"
LOCK="$T/machine/brokk.lock"
JOURNAL="$T/state/.lock-journal"
HANDOVER="$T/state/.arm.handover"

lock_verb() {  # <verb> [args…] — the ONE implementation, through its shell door
  bash "$STATE_DOOR" lock "$@" 2>/dev/null
}
lock_as() {  # <session-pid> <verb> [args…] — as one session would ask it
  local sess="$1"; shift
  BROKK_SESSION_PID="$sess" bash "$STATE_DOOR" lock "$@" 2>/dev/null
}
owner_now() { lock_verb owner; }
record_has() {  # <needle> — 0 when the journal carries it
  grep -q -- "$1" "$JOURNAL" 2>/dev/null
}

# A fake HARNESS: /proc/<pid>/comm is the executable's own name, so a copy of
# `sleep` called `pi` IS a process the lock recognises as a harness. Killed by PID
# in cleanup — never by name.
cp /bin/sleep "$T/bin/pi" 2>/dev/null || cp "$(command -v sleep)" "$T/bin/pi"
# a herdr-launched harness carries its pane in its own environment
HERDR_PANE_ID=wTEST:p1 "$T/bin/pi" 600 &
FAKE_PI=$!; PIDS+=("$FAKE_PI"); disown "$FAKE_PI" 2>/dev/null || true
sleep 0.2
[ "$(tr -d '\n' <"/proc/$FAKE_PI/comm" 2>/dev/null)" = pi ] \
  && ok "a stand-in harness runs as comm=pi (pid $FAKE_PI)" \
  || bad "a stand-in harness runs as comm=pi" "comm=$(cat /proc/$FAKE_PI/comm 2>/dev/null)"

printf '\n== 1 · a change of hands is on the record ==================================\n'

lock_as "$FAKE_PI" acquire >/dev/null
check "$(owner_now)" "$FAKE_PI" "the door records the harness pid as the owner"
[ -r "$JOURNAL" ] && ok "the journal exists ($JOURNAL)" || bad "the journal exists" "no file at $JOURNAL"
record_has "event=acquire pid=$FAKE_PI" && ok "the journal names the acquire (pid=$FAKE_PI)" \
  || bad "the journal names the acquire" "$(cat "$JOURNAL" 2>/dev/null | tail -2)"
record_has "why=vacant" && ok "the record says WHY the helm was free (why=vacant)" \
  || bad "the record says why (why=vacant)" "$(cat "$JOURNAL" 2>/dev/null | tail -1)"
record_has "from_pid=none" && ok "the record says who it was taken from (from_pid=none)" \
  || bad "the record says who it was taken from" "$(cat "$JOURNAL" 2>/dev/null | tail -1)"
[ -r "$HANDOVER" ] && ok "the last change of hands sits in .arm.handover for a door to read" \
  || bad "the last change of hands sits in .arm.handover" "no file at $HANDOVER"

printf '\n== 2 · a live helm keeps the arm (REFUSED, and the record is untouched) ====\n'

before_lock="$(cksum <"$LOCK")"
before_journal="$(cksum <"$JOURNAL")"
# a second, genuinely live harness that is NOT the owner
cp /bin/sleep "$T/bin/other-pi" && HERDR_PANE_ID=wOLD:p9 "$T/bin/other-pi" 600 &
OTHER_PI=$!; PIDS+=("$OTHER_PI"); disown "$OTHER_PI" 2>/dev/null || true
lock_as "$OTHER_PI" acquire >/dev/null 2>&1
rc=$?
[ "$rc" = 1 ] && ok "a second live session is REFUSED (exit 1, never a steal)" \
  || bad "a second live session is REFUSED" "exit=$rc"
check "$(owner_now)" "$FAKE_PI" "the owner is still the first harness"
check "$(cksum <"$LOCK")" "$before_lock" "the lock file is byte-identical (nothing was taken)"
check "$(cksum <"$JOURNAL")" "$before_journal" "no hand-over was recorded (nothing moved)"

printf '\n== 3 · the .child rule is gone: a live owner with NO supervisor sidecar ===\n'

# The road measured on 2026-11-20 01:05: the extension answered "missing" when
# `<lock>.child` was absent or dead — so a LIVE claude helm (which never writes one)
# was reclaimed by the next pi that booted. Two proofs: the gate itself, and the
# source that used to hold the steal.
rm -f "$LOCK.child"
check "$(lock_verb owner)" "$FAKE_PI" "no .child sidecar: the live owner is still the owner"
lock_as "$OTHER_PI" acquire >/dev/null 2>&1
check "$(lock_verb owner)" "$FAKE_PI" "no .child sidecar: a second session is still refused"
printf '%s' 999999 >"$LOCK.child"   # a dead supervisor, as measured
check "$(lock_verb owner)" "$FAKE_PI" "a DEAD .child sidecar does not cost a live helm the arm"
EXT="$ROOT/.pi/extensions/gna-pi-watch.ts"
if grep -qE '(writeFileSync|rmSync)\(lockPath' "$EXT"; then
  bad "the pi extension no longer writes the lock itself" "it still calls writeFileSync/rmSync on lockPath"
else
  ok "the pi extension no longer writes the lock itself (ONE writer: lock.py)"
fi
grep -q '"lock", "acquire"' "$EXT" \
  && ok "the extension takes a vacant helm THROUGH the door (lock acquire)" \
  || bad "the extension takes a vacant helm through the door" "no door call found in $EXT"
grep -q 'supervisor gone — reclaim it' "$EXT" \
  && bad "the .child steal rule is deleted" "the old comment survives in $EXT" \
  || ok "the .child steal rule is deleted"
rm -f "$LOCK.child"

printf '\n== 4 · a helper shell that is not the harness dies, and the swap is RECORDED =\n'

# The other measured road: a lock bound to a short-lived helper (no harness in its
# ancestry, so `session_pid` falls back to the shell) dies with the shell — and the
# next session start used to take the helm in total silence.
lock_as "$FAKE_PI" release >/dev/null 2>&1    # the helm must be free for the helper to take it
if command -v setsid >/dev/null 2>&1; then
helper_owner="$(setsid --fork bash -c '
  export BROKK_HOME="$1" BROKK_STATE_OVERRIDE="$2" BROKK_MACHINE_STATE_DIR="$3" YMIR_LOCK_ANNOUNCE=0
  unset BROKK_SESSION_PID
  bash "$4/bin/records/ymir-state.sh" lock acquire >/dev/null 2>&1
  bash "$4/bin/records/ymir-state.sh" lock owner
' _ "$BROKK_HOME" "$BROKK_STATE_OVERRIDE" "$BROKK_MACHINE_STATE_DIR" "$ROOT" 2>/dev/null)"
case "$helper_owner" in
  ''|*[!0-9]*) bad "a detached helper can take the lock (for the repro)" "owner=[$helper_owner]" ;;
  *)
    ok "a detached helper takes the lock as pid $helper_owner (no harness stands there)"
    record_has "harness=no" && ok "the record NAMES a lock held by a hand that cannot speak (harness=no)" \
      || bad "the record names a lock held by a hand that cannot speak" "$(tail -1 "$JOURNAL" 2>/dev/null)"
    sleep 0.2
    lock_as "$FAKE_PI" acquire >/dev/null 2>&1
    check "$(owner_now)" "$FAKE_PI" "the dead helper's lock is reaped and the helm taken"
    record_has "event=reap pid=$helper_owner" \
      && ok "the reap is on the record (pid $helper_owner)" \
      || bad "the reap is on the record" "$(grep -c reap "$JOURNAL" 2>/dev/null) reap line(s)"
    record_has "from_pid=$helper_owner" \
      && ok "the acquire names the hand it was taken FROM (from=$helper_owner)" \
      || bad "the acquire names the hand it was taken from" "$(tail -2 "$JOURNAL" 2>/dev/null)"
    ;;
esac
else
  printf 'SKIP - no setsid on this seat: the detached-helper reproduction needs it\n'
fi

printf '\n== 5 · a starttime mismatch is recorded, never a silent swap ===============\n'

printf '%s\n' "$FAKE_PI" >"$LOCK"
printf '1\n' >"$LOCK.starttime"    # a stale sidecar: the pid was 'recycled'
lock_as "$OTHER_PI" acquire >/dev/null 2>&1
check "$(owner_now)" "$OTHER_PI" "a mismatched starttime hands the arm to the next session"
record_has "reason=starttime-mismatch" \
  && ok "the record says the old owner was dropped for a starttime mismatch" \
  || bad "the record says why the old owner was dropped" "$(tail -2 "$JOURNAL" 2>/dev/null)"

printf '\n== 6 · a release from the wrong hand is refused ==========================\n'

before_journal="$(cksum <"$JOURNAL")"
lock_as "$FAKE_PI" release >/dev/null 2>&1
check "$(lock_verb owner)" "$OTHER_PI" "a stranger's release does not remove the lock"
check "$(cksum <"$JOURNAL")" "$before_journal" "a refused release records nothing"
lock_as "$OTHER_PI" release >/dev/null 2>&1
check "$(lock_verb owner)" "" "the owner's own release does remove it"
record_has "event=release pid=$OTHER_PI" && ok "the release is on the record" \
  || bad "the release is on the record" "$(tail -1 "$JOURNAL" 2>/dev/null)"
check "$(lock_verb handover >/dev/null 2>&1; echo $?)" "0" "the door answers the last change of hands"

printf '\n== 7 · the record is append-only ==========================================\n'

lines_before="$(awk 'END{print NR}' "$JOURNAL")"
lock_as "$FAKE_PI" acquire >/dev/null 2>&1
lock_as "$FAKE_PI" release >/dev/null 2>&1
lines_after="$(awk 'END{print NR}' "$JOURNAL")"
[ "$lines_after" -gt "$lines_before" ] && ok "two more changes of hands append two more lines" \
  || bad "the journal grows" "$lines_before -> $lines_after"
grep -q 'event=acquire pid=' "$JOURNAL" && ok "the oldest record is still there (never rewritten)" \
  || bad "the oldest record is still there" "the journal lost its history"

printf '\n== 8 · the arm service never touches the lock (the 23:55 restart road) =====\n'

# The 2026-11-19 23:55 arm restart (gen 59 -> 60) was a candidate road for the loss.
# Ruled out: the arm service owns the LEASE, and neither the door nor the engine
# mentions the session lock anywhere.
if grep -q 'brokk\.lock' "$ROOT/bin/pi/syn-watch.sh"; then
  bad "the arm service door names no session lock" "bin/pi/syn-watch.sh mentions brokk.lock"
else
  ok "the arm service door names no session lock (a restart cannot move the helm)"
fi
if grep -q 'brokk\.lock' "$ROOT/src/ymir_runtime/watch.py"; then
  bad "the arm engine names no session lock" "src/ymir_runtime/watch.py mentions brokk.lock"
else
  ok "the arm engine names no session lock (its lease is a different record)"
fi

printf '\n== 9 · a session start never becomes the helm by surprise ================\n'

# A vacant lock, but the last recorded helm is ALIVE: `--lock-only` must stand
# read-only and NAME the living hand instead of taking the arm in silence.
HERDR_PANE_ID=wTEST:p1 "$T/bin/other-pi" 600 &
LIVE_OLD=$!; PIDS+=("$LIVE_OLD"); disown "$LIVE_OLD" 2>/dev/null || true
printf '%s\n' "$(date +%Y-%m-%dT%H:%M:%S%z) event=acquire pid=$LIVE_OLD starttime=1 from_pid=none to_pid=$LIVE_OLD why=vacant role=pi harness=yes" \
  >"$HANDOVER"
rm -f "$LOCK" "$LOCK.starttime"          # the lock is VACANT — the surprise case
out="$(YMIR_STATE_DIR="$T/state" BROKK_SESSION_PID="$FAKE_PI" bash "$ROOT/bin/time/saga-session-start.sh" --lock-only 2>&1)"
case "$out" in
  *"READ-ONLY"*"$LIVE_OLD"*) ok "a vacant helm whose last holder is ALIVE is NOT taken (read-only, pid named)" ;;
  *) bad "a vacant helm whose last holder is alive is not taken" "$(printf '%s' "$out" | head -3)" ;;
esac
check "$(lock_verb owner)" "" "the session start took nothing (the lock is still vacant)"
out="$(YMIR_STATE_DIR="$T/state" BROKK_SESSION_PID="$FAKE_PI" BROKK_TAKE_HELM=1 bash "$ROOT/bin/time/saga-session-start.sh" --lock-only 2>&1)"
check "$(lock_verb owner)" "$FAKE_PI" "BROKK_TAKE_HELM=1 IS the deliberate takeover the Allfather asked for"
record_has "from_pid=none" && ok "the deliberate takeover is on the record like any other" \
  || bad "the deliberate takeover is on the record" "$(tail -1 "$JOURNAL" 2>/dev/null)"
lock_as "$FAKE_PI" release >/dev/null 2>&1
kill -9 "$LIVE_OLD" 2>/dev/null || true
# and a DEAD prior helm frees the arm for the next session (the ordinary case)
sleep 0.2
out="$(YMIR_STATE_DIR="$T/state" BROKK_SESSION_PID="$FAKE_PI" bash "$ROOT/bin/time/saga-session-start.sh" --lock-only 2>&1)"
check "$(lock_verb owner)" "$FAKE_PI" "a dead prior helm leaves the arm free for a new session"
case "$out" in
  *"held by this session"*) ok "that session says it holds the arm" ;;
  *) bad "that session says it holds the arm" "$(printf '%s' "$out" | head -3)" ;;
esac
lock_as "$FAKE_PI" release >/dev/null 2>&1

printf '\n== 10 · .arm.pane names the holder'"'"'s real pane, or nothing =============\n'

# A stub herdr: it holds exactly the panes it is told to hold, and each pane hosts
# exactly the pid it is told to host. No real pane is touched.
cat >"$T/herdr" <<'STUB'
#!/usr/bin/env bash
# <T>/herdr — pane list | pane process-info --pane <id>
D="$(dirname "$0")"
if [ "${1-}" = pane ] && [ "${2-}" = list ]; then
  printf '{"result":{"panes":['
  first=1
  for p in $(cat "$D/panes" 2>/dev/null); do
    [ "$first" = 1 ] || printf ','
    printf '{"pane_id":"%s"}' "$p"; first=0
  done
  printf ']}}\n'
  exit 0
fi
if [ "${1-}" = pane ] && [ "${2-}" = process-info ]; then
  p="${4-}"
  pid="$(awk -v pane="$p" '$1==pane {print $2}' "$D/pane-pids" 2>/dev/null | head -1)"
  [ -n "$pid" ] || { printf '{"result":{"process_info":{}}}\n'; exit 0; }
  printf '{"result":{"process_info":{"shell_pid":%s,"foreground_processes":[{"pid":%s}]}}}\n' "$pid" "$pid"
  exit 0
fi
exit 1
STUB
chmod +x "$T/herdr"
export YMIR_HERDR_CMD="$T/herdr"

printf 'wTEST:p1\n' >"$T/panes"
printf 'wTEST:p1 %s\n' "$FAKE_PI" >"$T/pane-pids"
out="$(YMIR_STATE_DIR="$T/state" YMIR_HERDR_CMD="$T/herdr" bash "$ROOT/bin/seat/arm-handover.sh" --pane "$FAKE_PI" 2>&1)"
check "$(head -1 "$T/state/.arm.pane" 2>/dev/null)" "wTEST:p1" "the proved pane is written to .arm.pane"
case "$out" in *'"wTEST:p1","yes"'*) ok "the door says the pane was proved" ;; *) bad "the door says the pane was proved" "$out" ;; esac

# The ghost: the pane on file is no longer held by herdr (measured: w39:p23 lived on
# for four days after the pane died). --show clears it instead of serving it.
printf 'w39:p23\n' >"$T/state/.arm.pane"
out="$(YMIR_STATE_DIR="$T/state" YMIR_HERDR_CMD="$T/herdr" bash "$ROOT/bin/seat/arm-handover.sh" --show 2>&1)"
[ -f "$T/state/.arm.pane" ] \
  && bad "a pane herdr no longer holds is cleared" ".arm.pane still names $(cat "$T/state/.arm.pane")" \
  || ok "a pane herdr no longer holds is cleared (a ghost is not served)"

# Nothing provable: nothing is invented.
: >"$T/pane-pids"
out="$(YMIR_STATE_DIR="$T/state" YMIR_HERDR_CMD="$T/herdr" bash "$ROOT/bin/seat/arm-handover.sh" --pane "$FAKE_PI" 2>&1)"
[ -f "$T/state/.arm.pane" ] \
  && bad "an unprovable pane writes no pane" ".arm.pane holds $(cat "$T/state/.arm.pane")" \
  || ok "an unprovable pane writes no pane (nothing is invented)"

printf '\n== 11 · the hand-over is ANNOUNCED into both panes ========================\n'

receipts="$T/sent.log"
cat >"$T/send" <<SEND
#!/usr/bin/env bash
# a recording send door: [--from X] <pane> <text>
printf '%s\t%s\n' "\${3-}" "\${4-}" >>"$receipts"
SEND
chmod +x "$T/send"
printf 'wTEST:p1\n' >"$T/panes"
printf 'wTEST:p1 %s\n' "$FAKE_PI" >"$T/pane-pids"
printf 'wOLD:p9 %s\n' "$OTHER_PI" >>"$T/pane-pids"
printf 'wTEST:p1\nwOLD:p9\n' >"$T/panes"
printf 'wOLD:p9\n' >"$T/state/.arm.pane"            # the hand that is about to lose it
lock_as "$FAKE_PI" acquire >/dev/null 2>&1           # the last change of hands is an acquire
: >"$receipts"
YMIR_STATE_DIR="$T/state" YMIR_HERDR_CMD="$T/herdr" EINDRI_SEND="$T/send" \
  bash "$ROOT/bin/seat/arm-handover.sh" --announce >/dev/null 2>&1
grep -q '^wOLD:p9' "$receipts" && ok "the hand that lost the arm is TOLD (its pane received a line)" \
  || bad "the hand that lost the arm is told" "$(cat "$receipts" 2>/dev/null | head -3)"
grep -q 'the helm moved' "$receipts" && ok "the line says the helm moved, and names the new holder" \
  || bad "the line says the helm moved" "$(cat "$receipts" 2>/dev/null | head -1)"
grep -q '^wTEST:p1' "$receipts" && ok "the hand that holds it is told too" \
  || bad "the hand that holds it is told too" "$(cat "$receipts" 2>/dev/null | head -3)"
check "$(head -1 "$T/state/.arm.pane")" "wTEST:p1" "the announcement refreshed .arm.pane to the new holder"

printf '\n== 12 · the doors that own the lock agree with each other ================\n'

# The lease must not need the lock: `rodd-arm.sh who` reads the LEASE and the identity
# door, so the arm can report `held` while a session holds the helm. Its self-test is
# the contract, and it must still pass after this change.
if timeout 240 bash "$ROOT/bin/voice/rodd-arm.sh" --self-test >"$T/rodd.out" 2>&1; then
  ok "the arm door's own self-test still passes ($(grep -c '  ok ' "$T/rodd.out" 2>/dev/null) checks)"
else
  bad "the arm door's own self-test still passes" "$(tail -3 "$T/rodd.out" 2>/dev/null)"
fi
if env -u BROKK_STATE_OVERRIDE -u BROKK_MACHINE_STATE_DIR -u BROKK_HOME -u YMIR_STATE_DIR \
     timeout 240 bash "$ROOT/.agents/tests/gleipnir-machine-lock.test.sh" >"$T/lock.out" 2>&1; then
  ok "the machine-lock suite still passes ($(grep -c '^ok - ' "$T/lock.out" 2>/dev/null) checks)"
else
  bad "the machine-lock suite still passes" "$(grep -m2 'not ok' "$T/lock.out" 2>/dev/null)"
fi

printf '\narm-never-lost: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]

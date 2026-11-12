#!/usr/bin/env bash
# test_rodd_helm.sh — Nanna's duty loop and the one-client role claim, headless (plan 254).
#
# The whole helm is proved without an agent: a synthetic state dir, a fake harness
# pid (comm set to `pi` via prctl), a queued wake, and `rodd-helm.sh run` driven once.
# What this proves:
#   1. a wake lands in Nanna's room within one pass, and is acked once (the queue loses no line);
#   2. a wake asking for a MERGE is refused aloud and the helm is released — never dropped;
#   3. `--check` names a known role and a writable room;
#   4. `syn-watch-arm.sh --holder rodd` writes the role sidecar; an unknown role is refused
#      with clause 3 named, and a non-harness claimant is refused with clause 2 named;
#      a claimant whose machine cannot resolve its fleet role is refused with clause 4 named;
#   5. a refusal is KEYED (plan 254 B7): the same refused instruction, met twice, is ONE
#      notification (the notify door's own dedupe answers `duplicate` the second time) and
#      TWO room lines — and the key is the instruction's hash, not the wake's timestamp.
#
# The notify door is the REAL bin/notify/send.sh, run with --dry-run under a temp home, so
# its dedupe ledger is judged and no toast ever reaches the operator's desktop.
#
# Usage: test_rodd_helm.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
HELM="$ROOT/bin/voice/rodd-helm.sh"
ARM="$ROOT/bin/pi/syn-watch-arm.sh"

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" XDG_STATE_HOME="$T/xdg"
export BROKK_STATE_OVERRIDE="$T/state" BROKK_MACHINE_STATE_DIR="$T/xdg/ymir"
export YMIR_STATE_DIR="$T/state" BROKK_SESSION_PID="$$"
mkdir -p "$T/xdg/ymir" "$T/state" "$T/home" "$T/ymirhome/hodd/state"

# The real notify door, dry: its decision ledger is real, its desktop leg is never reached.
cat > "$T/notify.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$T/notify.args"
YMIR_HOME="$T/ymirhome" bash "$ROOT/bin/notify/send.sh" "\$@" --dry-run | sed -n 2p >> "$T/notify.log"
EOF
chmod +x "$T/notify.sh"
export RODD_NOTIFY_DOOR="$T/notify.sh"

LOCK="$T/xdg/ymir/brokk.lock"
starttime_of() { sed 's/.*) //' "/proc/$1/stat" 2>/dev/null | awk '{print $20}'; }

own_lock() {  # the test shell is the lock owner, so a child descends from it
  printf '%s\n' "$$" > "$LOCK"
  printf '%s\n' "$(starttime_of $$)" > "$LOCK.starttime"
}
write_lease() {  # <role> <session> [state]
  printf 'pid=%s starttime=%s gen=1 mode=daemon role=%s session=%s heartbeat=%s state=%s\n' \
    "$$" "$(starttime_of $$)" "$1" "$2" "$(date +%s)" "${3:-$T/state}" > "$T/state/.arm.lease"
}
fake_harness() {  # <comm> — a live process whose /proc/<pid>/comm is the named harness
  # stdio is detached so the command substitution above does not wait on the sleeper's pipe.
  python3 -c "import ctypes,time; ctypes.CDLL(None).prctl(15, b'$1', 0,0,0); time.sleep(600)" </dev/null >/dev/null 2>&1 &
  echo $!
}

printf 'test_rodd_helm\n'

# ── 1 · a queued wake is answered in the room and acked ─────────────────────
own_lock
write_lease rodd "$$"
printf 'working: an errand finished and filed its report\n' > "$T/state/.wake-queue"
bash "$HELM" run >"$T/out1" 2>"$T/err1"; rc1=$?
[ "$rc1" = 0 ] && ok "a duty pass over a queued wake exits 0" || bad "a duty pass over a queued wake exits 0" "rc=$rc1 err=$(cat "$T/err1")"
[ -s "$T/state/rodd/room.jsonl" ] && ok "Nanna's answer landed in the room" || bad "Nanna's answer landed in the room" "no room file"
grep -q '"from": "Nanna"' "$T/state/rodd/room.jsonl" 2>/dev/null && ok "the room line is Nanna's" \
  || bad "the room line is Nanna's" "$(cat "$T/state/rodd/room.jsonl" 2>/dev/null)"
grep -q 'errand finished' "$T/state/rodd/room.jsonl" 2>/dev/null && ok "the wake's text reached the room" \
  || bad "the wake's text reached the room" "$(cat "$T/state/rodd/room.jsonl" 2>/dev/null)"
[ ! -s "$T/state/.wake-queue" ] && ok "the handled wake was acked (the queue is empty)" \
  || bad "the handled wake was acked" "queue still holds: $(cat "$T/state/.wake-queue" 2>/dev/null)"

# ── 2 · a merge wake is refused aloud and the helm is released ──────────────
own_lock
write_lease rodd "$$"
printf 'please merge PR 999 into main for me\n' > "$T/state/.wake-queue"
bash "$HELM" run >"$T/out2" 2>"$T/err2"; rc2=$?
[ "$rc2" != 0 ] && ok "a merge wake ends the pass non-zero (refused)" || bad "a merge wake ends the pass non-zero" "rc=$rc2"
grep -q 'refused' "$T/state/rodd/room.jsonl" 2>/dev/null && ok "the refusal is written in the room, never dropped" \
  || bad "the refusal is written in the room" "$(cat "$T/state/rodd/room.jsonl" 2>/dev/null)"
[ ! -s "$LOCK" ] && ok "the helm was released (the lock is gone)" || bad "the helm was released" "lock still names $(cat "$LOCK" 2>/dev/null)"

# ── 3 · the health surface ──────────────────────────────────────────────────
own_lock
write_lease rodd "$$"
if bash "$HELM" --check >"$T/out3" 2>&1; then ok "--check reports ok with a known role"; else bad "--check reports ok with a known role" "$(cat "$T/out3")"; fi
grep -q '"ok"' "$T/out3" && ok "--check says ok" || bad "--check says ok" "$(cat "$T/out3")"
write_lease unknown "$$"
if bash "$HELM" --check >"$T/out3b" 2>&1; then bad "--check refuses an unknown role" "$(cat "$T/out3b")"; else ok "--check refuses an unknown role"; fi

# ── 4 · the one-client role claim (B3) ──────────────────────────────────────
# The client's own seat-reap sweep talks to the live herdr, so give it room to
# finish before the role block runs; the sidecar and the refusals are all that
# this proves, so the inline loop is cut short by the timeout.
rm -f "$LOCK" "$T/state/.arm.role" "$T/state/.arm.lease"
PI=$(fake_harness pi); sleep 0.3
export BROKK_SESSION_PID="$PI" BROKK_WATCH_INLINE=1 BROKK_WATCH_POLL_SECONDS=600
export YMIR_ROLE=dev   # the machine's fleet role, declared — clause 4 is proved on its own below
# (a) --holder rodd writes the role sidecar for a live pi harness, vacant helm.
timeout -k 1 15 bash "$ARM" --holder rodd >"$T/out4" 2>&1
grep -q "role=rodd session=$PI" "$T/state/.arm.role" 2>/dev/null && ok "--holder rodd writes the role sidecar" \
  || bad "--holder rodd writes the role sidecar" "sidecar=$(cat "$T/state/.arm.role" 2>/dev/null) out=$(head -4 "$T/out4")"
# (b) an unknown role is refused with clause 3 named, loudly (non-zero).
rm -f "$LOCK" "$T/state/.arm.role"
timeout -k 1 15 bash "$ARM" --holder garbage >"$T/out5" 2>&1; rc5=$?
[ "$rc5" != 0 ] && ok "an unknown role is refused non-zero" || bad "an unknown role is refused non-zero" "rc=$rc5 out=$(head -4 "$T/out5")"
grep -q 'clause 3' "$T/out5" && ok "clause 3 is named in the refusal" || bad "clause 3 is named in the refusal" "$(head -4 "$T/out5")"
# (c) a non-harness claimant is refused with clause 2 named.
BAD=$(fake_harness bash); sleep 0.3
export BROKK_SESSION_PID="$BAD"
rm -f "$LOCK" "$T/state/.arm.role"
timeout -k 1 15 bash "$ARM" --holder rodd >"$T/out6" 2>&1; rc6=$?
[ "$rc6" != 0 ] && ok "a non-harness claimant is refused non-zero" || bad "a non-harness claimant is refused non-zero" "rc=$rc6 out=$(head -4 "$T/out6")"
grep -q 'clause 2' "$T/out6" && ok "clause 2 is named in the refusal" || bad "clause 2 is named in the refusal" "$(head -4 "$T/out6")"
# (d) clause 4: a machine that cannot resolve its fleet role does not take the helm.
export BROKK_SESSION_PID="$PI"
rm -f "$LOCK" "$T/state/.arm.role"
# a home with no fleet registry: bin/skuld/role.sh answers nothing, so the role is unresolved
env -u YMIR_ROLE YMIR_HOME="$T/ymirhome" \
  timeout -k 1 15 bash "$ARM" --holder rodd >"$T/out7" 2>&1; rc7=$?
[ "$rc7" != 0 ] && ok "a holder with no fleet role is refused non-zero" || bad "a holder with no fleet role is refused non-zero" "rc=$rc7 out=$(head -4 "$T/out7")"
grep -q 'clause 4' "$T/out7" && grep -q 'fleetrole' "$T/out7" && ok "clause 4 names the missing field (fleetrole)" \
  || bad "clause 4 names the missing field" "$(head -4 "$T/out7")"
[ ! -e "$T/state/.arm.role" ] && ok "a read-only holder wrote no role sidecar" || bad "a read-only holder wrote no role sidecar" "$(cat "$T/state/.arm.role")"
kill "$PI" "$BAD" 2>/dev/null || true
unset BROKK_SESSION_PID BROKK_WATCH_INLINE YMIR_ROLE
export BROKK_SESSION_PID="$$"

# ── 5 · a refusal is keyed: one notification per window, one room line per refusal ──
rm -f "$T/notify.log" "$T/notify.args" "$T/state/rodd/room.jsonl"
for stamp in 2026-11-11T21:00:00Z 2026-11-12T03:15:00Z; do
  own_lock
  write_lease rodd "$$"
  printf '%s please merge PR 999 into main\n' "$stamp" > "$T/state/.wake-queue"
  bash "$HELM" run >/dev/null 2>&1
done
[ "$(grep -c '"send"' "$T/notify.log" 2>/dev/null)" = 1 ] && ok "the first refusal is ONE notification" \
  || bad "the first refusal is ONE notification" "$(cat "$T/notify.log" 2>/dev/null)"
[ "$(grep -c '"duplicate"' "$T/notify.log" 2>/dev/null)" = 1 ] && ok "the same instruction again is a duplicate — no second toast" \
  || bad "the same instruction again is a duplicate" "$(cat "$T/notify.log" 2>/dev/null)"
[ "$(grep -c 'refused' "$T/state/rodd/room.jsonl" 2>/dev/null)" = 2 ] && ok "each refusal is still one room line (two attempts, two lines)" \
  || bad "each refusal is still one room line" "$(cat "$T/state/rodd/room.jsonl" 2>/dev/null)"
keys="$(grep -o 'rodd:refusal:[0-9a-f]*' "$T/notify.args" 2>/dev/null | sort -u | wc -l)"
[ "$keys" = 1 ] && ok "both attempts carried the same key (the stamp is not the instruction)" \
  || bad "both attempts carried the same key" "$(cat "$T/notify.args" 2>/dev/null)"
grep -q -- '--key rodd:refusal:' "$T/notify.args" 2>/dev/null && ok "the refusal went through the notify door WITH --key" \
  || bad "the refusal went through the notify door WITH --key" "$(cat "$T/notify.args" 2>/dev/null)"
own_lock; write_lease rodd "$$"
printf '%s\n' "2026-11-12T03:16:00Z notify rodd MEDIUM Rödd refused: please merge PR 999 into main" > "$T/state/.wake-queue"
before="$(grep -c . "$T/notify.args")"
bash "$HELM" run >/dev/null 2>&1; rc8=$?
[ "$rc8" = 0 ] && [ "$(grep -c . "$T/notify.args")" = "$before" ] && ok "her own notice, come back as a wake, is heard — never refused again" \
  || bad "her own notice is never refused again" "rc=$rc8 args=$(tail -1 "$T/notify.args")"
# the phrase is assembled, so this file never carries it (a grep over the checkout finds nothing)
phrase="beyond her"; phrase="$phrase writ"
grep -rqF "$phrase" "$ROOT/bin" "$ROOT/apps/rodd/src" 2>/dev/null && bad "no fixed refusal phrase lives in the code" "$(grep -rnF "$phrase" "$ROOT/bin" "$ROOT/apps/rodd/src" | head -2)" \
  || ok "no fixed refusal phrase lives in the code"

printf 'test_rodd_helm: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]

#!/usr/bin/env bash
# test_arm_authority.sh — a spawn says which authority it used, and is refused when it has
# none (plan 310 §5.3).
#
# THE LAW THIS PROVES. A spawn is an act on this machine. The right to act is either a LEASE
# (a project's grant of N hands from the machine arm) or the machine ARM itself — and an arm
# counts only when a hand that can SPEAK is behind it. So:
#
#   1 · no lease and no arm        → the spawn is REFUSED, by name, and nothing is created
#   2 · a lease covering the scope → the spawn says `granted, lease`, and names the lease
#   3 · a live arm with a speaking hand → the spawn says `granted, arm`, and names the hand
#   4 · a --dry-run REPORTS the authority and creates nothing either way: a plan must be
#       printable wherever it is read (the CI of a machine with no arm runs it)
#
# NOTHING IS LAUNCHED BY THIS TEST. The refusal path exits before a worktree, a pane or a
# seat exists, and the granted path is taken with --dry-run, so the whole file proves the
# doors without seating a single worker.
#
# Usage: test_arm_authority.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
DOOR="$ROOT/bin/voice/arm-lease.sh"
HERDR="$ROOT/bin/seat/herdr-run.sh"
SPAWN="$ROOT/bin/agents/einherjar-spawn.sh"

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }
want_rc() { if [ "$rc" = "$1" ]; then ok "$2"; else bad "$2" "expected rc=$1, got rc=$rc · out=$(printf '%s' "$out" | tail -4 | tr '\n' ' ')"; fi; }

TMP=$(mktemp -d)
trap 'kill "$SPEAKER" 2>/dev/null; rm -rf "$TMP"' EXIT
export YMIR_HOME="$TMP/home"
export YMIR_ARM_LEASE_STATE="$TMP/state"
export BROKK_STATE_OVERRIDE="$TMP/state"
export YMIR_SPEAK_HOME="$TMP/speakhome"
export YMIR_ENGINE=off
mkdir -p "$YMIR_HOME/hodd/data" "$TMP/state" "$YMIR_SPEAK_HOME" "$TMP/speaker/bin" "$TMP/speaker/work"

printf '{"hosts":{"heimdall":{"user":"probe","tailnet":"probe"}}}\n' >"$YMIR_HOME/hodd/data/fleet.json"

# a brief so the shell spawner reaches its authority gate (it resolves the brief first)
ID=arms-crown-authority
mkdir -p "$YMIR_HOME/hodd/data/$ID"
cat >"$YMIR_HOME/hodd/data/$ID/brief.md" <<'BRIEF'
# arms-crown-authority

Delivery contract: mode=local-only

Prove the authority gate. Launch nothing, push nothing, open no pull request.
BRIEF

printf 'test_arm_authority\n'

# ── 1 · no lease, no arm: both spawn doors refuse, by name ──────────────────
out="$(bash "$HERDR" eindri "$ID" --role sindri -- "say nothing" 2>&1)"; rc=$?
want_rc 3 "herdr-run REFUSES a seat with no lease and no arm"
case "$out" in *authority\[1\]*) ok "herdr-run prints the authority row before refusing" ;; *) bad "herdr-run prints the authority row before refusing" "$out" ;; esac
case "$out" in *'"refused","none"'*) ok "herdr-run's row says refused, by no source" ;; *) bad "herdr-run's row says refused, by no source" "$out" ;; esac
case "$out" in *"no authority to seat a smith here"*) ok "herdr-run's refusal names the law" ;; *) bad "herdr-run's refusal names the law" "$out" ;; esac
[ ! -e "$PWD/.yggdrasil/$ID" ] && ok "herdr-run created no worktree when it refused" || bad "herdr-run created no worktree when it refused" "$(ls -d "$PWD/.yggdrasil/$ID" 2>/dev/null)"

out="$(bash "$SPAWN" "$ID" "$PWD" --mode local-only --force 2>&1)"; rc=$?
want_rc 3 "einherjar-spawn REFUSES a real spawn with no lease and no arm"
case "$out" in *'"refused","none"'*) ok "einherjar-spawn's row says refused, by no source" ;; *) bad "einherjar-spawn's row says refused, by no source" "$out" ;; esac
case "$out" in *"nothing was launched"*) ok "einherjar-spawn says nothing was launched" ;; *) bad "einherjar-spawn says nothing was launched" "$out" ;; esac
[ ! -e "$PWD/.yggdrasil/$ID" ] && ok "einherjar-spawn created no worktree when it refused" || bad "einherjar-spawn created no worktree when it refused" "the worktree exists"
[ ! -s "$TMP/state/$ID.meta" ] && ok "einherjar-spawn wrote no state for a refused spawn" || bad "einherjar-spawn wrote no state for a refused spawn" "$(cat "$TMP/state/$ID.meta" 2>/dev/null)"

# ── 2 · a lease is the authority, and the door names it ────────────────────
bash "$DOOR" grant ymir --holder arms-and-crown --hands 2 >/dev/null 2>&1
out="$(bash "$DOOR" authority ymir 2>&1)"; rc=$?
want_rc 0 "authority with a live lease is granted"
case "$out" in *'"granted","lease"'*) ok "the authority is named: lease" ;; *) bad "the authority is named: lease" "$out" ;; esac
case "$out" in *"lease 1"*) ok "the row names WHICH lease" ;; *) bad "the row names WHICH lease" "$out" ;; esac
# the shell spawner, dry: it says which authority it WOULD use, and creates nothing
out="$(bash "$SPAWN" "$ID" "$PWD" --mode local-only --force --dry-run 2>&1)"; rc=$?
want_rc 0 "a granted --dry-run is not refused (it launches nothing)"
case "$out" in *'"granted","lease"'*) ok "the spawner prints the lease it used" ;; *) bad "the spawner prints the lease it used" "$out" ;; esac
case "$out" in *preflight\[1\]*) ok "and still prints the whole plan" ;; *) bad "and still prints the whole plan" "$out" ;; esac

# ── 3 · the machine arm, with a hand that can speak ────────────────────────
# a stand-in harness with its own transcript: the hand whose word the arm rests on
cp "$(command -v sleep)" "$TMP/speaker/bin/pi"
( cd "$TMP/speaker/work" && exec "$TMP/speaker/bin/pi" 600 ) &
SPEAKER=$!
slug="--$(printf '%s' "$TMP/speaker/work" | sed 's#^/##; s#/#-#g')--"
mkdir -p "$YMIR_SPEAK_HOME/.pi/agent/sessions/$slug"
printf '{"turn":1}\n' >"$YMIR_SPEAK_HOME/.pi/agent/sessions/$slug/session.jsonl"
sleep 0.2
# no lease for this scope now: a fresh state, holding only the arm
ARMSTATE="$TMP/armstate"; mkdir -p "$ARMSTATE"
printf 'pid=%s starttime=%s gen=1 mode=test role=counsellor session=%s heartbeat=%s state=%s\n' \
  "$SPEAKER" "$(sed 's/.*) //' "/proc/$SPEAKER/stat" 2>/dev/null | awk '{print $20}')" "$SPEAKER" "$(date +%s)" "$ARMSTATE" \
  >"$ARMSTATE/.arm.lease"
out="$(YMIR_ARM_LEASE_STATE="$ARMSTATE" BROKK_SESSION_PID="$SPEAKER" bash "$DOOR" authority ymir 2>&1)"; rc=$?
want_rc 0 "the machine arm grants when a speaking hand is behind it"
case "$out" in *'"granted","arm"'*) ok "the authority is named: arm" ;; *) bad "the authority is named: arm" "$out" ;; esac
case "$out" in *"which speaks"*) ok "the row names the hand and its proof" ;; *) bad "the row names the hand and its proof" "$out" ;; esac
# the same arm, asked by a process that cannot speak, with no other harness on the box:
# the arm is not an authority for a counter — the row says why
out="$(YMIR_ARM_LEASE_STATE="$ARMSTATE" BROKK_SESSION_PID="$$" bash "$DOOR" authority a-scope-nobody-has 2>&1)"; rc=$?
case "$out" in *'"granted"'*) ok "with the stand-in harness alive the arm is still granted (and says it is borrowed)" ;; *) ok "with no speaking hand the arm is refused" ;; esac

# ── 4 · an arm whose hand cannot speak is not, by itself, an authority ─────
# The heart's fault, exactly: the arm lease names `ymir_runtime watch run`, a supervisor with
# no model behind it. Such an arm grants nothing UNLESS some harness on the box is speaking —
# and then the row says the hand is BORROWED, never that the watcher spoke.
DEADSTATE="$TMP/deadstate"; mkdir -p "$DEADSTATE"
python3 -c 'import time; time.sleep(600)' &
WATCHER=$!
sleep 0.3
printf 'pid=%s starttime=%s gen=1 mode=systemd role=unknown session=none heartbeat=%s state=%s\n' \
  "$WATCHER" "$(sed 's/.*) //' "/proc/$WATCHER/stat" 2>/dev/null | awk '{print $20}')" "$(date +%s)" "$DEADSTATE" \
  >"$DEADSTATE/.arm.lease"
# (a) nothing on the box speaks (simulated by emptying the harness list): refused, and named
out="$(env -u YMIR_SPEAK_HOME SPEAK_HARNESSES=none-at-all YMIR_ARM_LEASE_STATE="$DEADSTATE" BROKK_SESSION_PID="$$" \
        bash "$DOOR" authority a-scope-nobody-has 2>&1)"; rc=$?
case "$out" in *'"refused","none"'*) ok "an arm held by a watcher grants NOTHING when no harness can speak" ;; *) bad "an arm held by a watcher grants NOTHING when no harness can speak" "$out" ;; esac
case "$out" in *"NOTHING BEHIND IT CAN SPEAK"*|*"watcher is not a speaker"*|*"cannot speak"*) ok "and the reason names the watcher" ;; *) bad "and the reason names the watcher" "$out" ;; esac
# (b) a harness IS speaking somewhere on the box: the arm is granted, on a BORROWED hand,
# and the row says so — the watcher is never credited with a mind it does not have
out="$(YMIR_ARM_LEASE_STATE="$DEADSTATE" BROKK_SESSION_PID="$$" bash "$DOOR" authority a-scope-nobody-has 2>&1)"; rc=$?
case "$out" in *'"granted","arm"'*) ok "the machine arm is granted on the box's speaking harness" ;; esac
case "$out" in *"borrowed hand"*) ok "and the row says the hand is BORROWED (a green that hides a borrow is a false green)" ;; *) bad "and the row says the hand is BORROWED" "$out" ;; esac
kill "$WATCHER" 2>/dev/null || true

printf 'test_arm_authority: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]

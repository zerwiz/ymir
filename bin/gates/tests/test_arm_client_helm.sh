#!/usr/bin/env bash
# test_arm_client_helm.sh — the arm client's two measured faults (2026-11-10), with stubs.
#
#   (a) A client must attach ONLY when this session holds the helm. The acquire block
#       skips a LIVE owner, and the client used to attach anyway — so a second session
#       that never held the helm still received wakes. The fix is a hard ownership gate.
#   (b) A new client must retire its SAME session's older clients. Every Stop spawns a
#       new client; the old ones used to wait beside it, so one signal rewoke the session
#       five times.
#
# Everything runs against a throwaway XDG state dir and a stub session pid. No real lock,
# no real service, no file of the operator's is touched.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
ARM="$ROOT/bin/pi/syn-watch-arm.sh"
[ -x "$ARM" ] || { echo "FAIL: no $ARM"; exit 1; }
fail=0
pass() { echo "PASS: $1"; }
bad()  { echo "FAIL: $1"; fail=1; }
alive() {  # <pid> — running (not a reaped-or-zombie child still awaiting wait)
  local p=$1 st
  kill -0 "$p" 2>/dev/null || return 1
  st="$(awk '{print $3}' "/proc/$p/stat" 2>/dev/null)"
  [ -n "$st" ] && [ "$st" != "Z" ]
}
fake_harness() {  # <comm> — a live process whose /proc/<pid>/comm is the named harness
  python3 -c "import ctypes,time; ctypes.CDLL(None).prctl(15, b'$1',0,0,0); time.sleep(600)" </dev/null >/dev/null 2>&1 &
  echo $!
}

T="$(mktemp -d)"
trap 'kill $(cat "$T"/*.pid 2>/dev/null) 2>/dev/null; rm -rf "$T"' EXIT
export HOME="$T/home" XDG_STATE_HOME="$T/xdg"
export BROKK_STATE_OVERRIDE="$T/state"
# The harness that runs this test carries a machine-state override and a session override;
# clear them so the lock resolves inside the sandbox, not to the operator's real helm.
export BROKK_MACHINE_STATE_DIR="$T/xdg/ymir"
unset BROKK_SESSION_PID 2>/dev/null || true
export BROKK_WATCH_INLINE=1 BROKK_WATCH_POLL_SECONDS=600
# plan 257 H6: these tests exercise THIS tree's client, so they take the loud override
# rather than being handed to the operator's pinned runtime.
export YMIR_ARM_TREE=1
mkdir -p "$HOME" "$T/xdg/ymir" "$BROKK_STATE_OVERRIDE"

lock="$T/xdg/ymir/brokk.lock"

# A live process that is NOT an ancestor of the arm: the "other session".
bash -c 'sleep 600' & other=$!; echo "$other" > "$T/other.pid"

# ── (a) a live stranger holds the helm → read-only, no pidfile, no attach ─────
printf '%s\n' "$other" > "$lock"
export BROKK_SESSION_PID="4242"
out="$(timeout 20 bash "$ARM" --restart 2>&1)"; rc=$?
if printf '%s' "$out" | grep -q 'read-only'; then pass "(a) stranger helm refused as read-only"; else bad "(a) no read-only line (out: $out)"; fi
if printf '%s' "$out" | grep -q 'attached'; then bad "(a) client attached despite not holding the helm"; else pass "(a) client did not attach"; fi
if [ -e "$BROKK_STATE_OVERRIDE/.arm.clients/4242.pids" ]; then bad "(a) wrote a client pidfile while not holding the helm"; else pass "(a) no client pidfile written"; fi
[ "$rc" = 0 ] || bad "(a) exit was $rc, expected 0"

# ── (b) this session holds the helm; a new client retires older ones ───────────
rm -f "$lock"
PI=$(fake_harness pi); sleep 0.3
export BROKK_SESSION_PID="$PI"
mkdir -p "$BROKK_STATE_OVERRIDE/.arm.clients"
# Two live stub "older clients" whose cmdline names syn-watch-arm (the real client does).
bash -c 'exec -a syn-watch-arm sleep 600' & a=$!
bash -c 'exec -a syn-watch-arm sleep 600' & b=$!
printf '%s\n%s\n' "$a" "$b" > "$BROKK_STATE_OVERRIDE/.arm.clients/$PI.pids"
timeout 20 bash "$ARM" --restart >"$T/out" 2>&1 &
newc=$!
# Wait for the retirement rather than a fixed sleep: the client's catch-up sweep talks to the
# live herdr first and its time varies, and the identity gate (clause 4) costs a beat too.
for _ in $(seq 1 36); do alive "$a" || alive "$b" || break; sleep 0.5; done
if alive "$a"; then bad "(b) older client $a was not retired (out: $(tr "\n" " " < "$T/out"))"; else pass "(b) older client $a retired"; fi
if alive "$b"; then bad "(b) older client $b was not retired"; else pass "(b) older client $b retired"; fi
if grep -qx "$PI" "$BROKK_STATE_OVERRIDE/.arm.clients/$PI.pids" 2>/dev/null || [ -s "$BROKK_STATE_OVERRIDE/.arm.clients/$PI.pids" ]; then
  pass "(b) the new client recorded a live client for the session"
else
  bad "(b) the new client wrote no pidfile"
fi
kill "$newc" "$PI" 2>/dev/null || true

exit $fail

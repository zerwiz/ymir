#!/usr/bin/env bash
# test_clock_lock.sh — the Nornir clock watches the right lock, says why it stops, and is started once
# again by the trouble panel (plan 369 item 17). Everything runs in a scratch home with its own HOME,
# state dir and notice door: no real clock, lock, pointer or alert is touched.
set -u
ROOT="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
CRON="$ROOT/bin/time/nornir-cron-start.sh"
T="$(mktemp -d)"
H="$T/home"; S="$H/state"; M="$T/xdg/ymir"; C="$H/config"; STUB="$T/root"
mkdir -p "$S" "$M" "$C" "$H/hodd" "$STUB/bin/notify" "$STUB/.pi" "$STUB/RULES"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s/notices.log"\n' "$T" > "$STUB/bin/notify/send.sh"
chmod +x "$STUB/bin/notify/send.sh"
printf '@every:59 true\n' > "$C/cron.yaml"
sleep 300 & OWNER=$!
fail=0; ok() { printf 'ok   %s\n' "$1"; }; no() { printf 'FAIL %s\n' "$1"; fail=1; }
iso() { env -i PATH="$PATH" HOME="$T" XDG_STATE_HOME="$T/xdg" YMIR_HOME="$H" "$@"; }
clock() {
  iso BROKK_STATE_OVERRIDE="$S" BROKK_CONFIG_OVERRIDE="$C" BROKK_ROOT_OVERRIDE="$STUB" BROKK_ROLES=dev \
    BROKK_CRON_TICK=1 BROKK_CRON_LOCK_GRACE=2 BROKK_CRON_LOCK_RECHECK=1 bash "$CRON" "$@"
}
cleanup() { [ -r "$S/cron.pid" ] && kill "$(cat "$S/cron.pid")" 2>/dev/null; kill "$OWNER" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT
has() { local i; for i in $(seq 1 40); do grep -qF -- "$1" "$S/cron.log" 2>/dev/null && return 0; sleep 0.25; done; return 1; }

# 1 · a pointer to a lock outside the state dir is refused in words; the primary lock keeps the clock up
printf '%s\n' "$OWNER" > "$M/brokk.lock"
mkdir -p "$T/elsewhere"; printf '%s\n' "$T/elsewhere/brokk.lock" > "$S/.lock-path"
clock >/dev/null 2>&1; sleep 5
case "$(clock --status 2>/dev/null)" in "cron: running"*) ok "a stray pointer does not stop the clock" ;; *) no "stray pointer: $(clock --status 2>&1)" ;; esac
has "refused: $T/elsewhere/brokk.lock is outside" && ok "the refusal is in the log" || no "no refusal logged"
case "$(clock --status 2>&1)" in *WARNING*refused*) ok "--status says the pointer is refused" ;; *) no "status silent about the pointer" ;; esac

# 2 · a stranger may not stop it while a session holds the lock; a stated reason may, and both are logged
printf '%s\n' "$M/brokk.lock" > "$S/.lock-path"
clock --stop >/dev/null 2>&1; rc=$?
[ "$rc" = 1 ] && has "cron stop REFUSED" && ok "a stop from outside the session is refused and logged" || no "stranger stop not refused (rc=$rc)"
clock --stop --why "the test" >/dev/null 2>&1
has ": the test" && has "cron stopped by signal TERM" \
  && ok "a stop names who and why, and the clock logs its own end" || no "stop not logged: $(tail -n 3 "$S/cron.log")"

# 3 · a pointer inside the state dir whose owner is dead is refused; with no live lock at all it retires
sleep 0 & dead=$!; wait "$dead"
printf '%s\n' "$dead" > "$S/own.lock"; printf '%s\n' "$S/own.lock" > "$S/.lock-path"
: > "$S/cron.log"; printf '%s\n' "$dead" > "$M/brokk.lock"
clock >/dev/null 2>&1
has "refused: $S/own.lock has no live owner" && ok "a dead owner behind the pointer is refused in words" || no "dead owner silent"
has "cron retired - no live session lock at $M/brokk.lock" && ok "no live lock anywhere still retires it" || no "did not retire: $(tail -n 3 "$S/cron.log")"

# 4 · a private machine dir never writes the home's pointer, and a live lock is never repointed
printf '%s\n' "$M/brokk.lock" > "$S/.lock-path"
iso BROKK_MACHINE_STATE_DIR="$T/seat" BROKK_SESSION_PID="$OWNER" PYTHONPATH="$ROOT/src" \
  python3 -c 'from ymir_runtime.state import lock; lock.acquire()' 2>/dev/null
[ -f "$T/seat/brokk.lock" ] && [ "$(cat "$S/.lock-path")" = "$M/brokk.lock" ] \
  && ok "a private machine dir leaves the home's pointer alone" || no "pointer now $(cat "$S/.lock-path")"
printf '%s\n' "$OWNER" > "$S/live.lock"; printf '%s\n' "$S/live.lock" > "$S/.lock-path"
iso BROKK_STATE_OVERRIDE="$S" BROKK_MACHINE_STATE_DIR="$T/seat2" PYTHONPATH="$ROOT/src" \
  python3 -c 'import sys; from pathlib import Path; from ymir_runtime.state import lock; lock.write_pointer(Path(sys.argv[1]))' "$T/seat2/brokk.lock" 2>/dev/null
[ "$(cat "$S/.lock-path")" = "$S/live.lock" ] && ok "a pointer to a live lock is kept" || no "live pointer overwritten"

# 5 · the trouble panel starts a stopped clock once before it is red
rm -f "$S/cron.pid"; : > "$S/.cron-retired"
cat > "$T/cron-stub.sh" <<X
#!/usr/bin/env bash
if [ "\${1:-}" = --status ]; then [ -f "$T/up" ] && echo 'cron: running pid=1 jobs=1' || echo 'cron: stopped jobs=1'; exit 0; fi
echo start >> "$T/starts"; [ -f "$T/healable" ] && touch "$T/up"; exit 0
X
panel() {
  iso YMIR_STATE_DIR="$S" TROUBLE_HOST=testhost TROUBLE_CRON="$T/cron-stub.sh" TROUBLE_SEND="$STUB/bin/notify/send.sh" \
    bash "$ROOT/bin/ward/trouble.sh" check --json --only clock 2>&1
}
touch "$T/healable"; out="$(panel)"
{ printf '%s' "$out" | grep -q 'restarted once by the panel' && [ "$(wc -l < "$T/starts")" = 1 ]; } \
  && ok "a stopped clock is restarted once and reads ok" || no "restart once: $out"
rm -f "$T/up"; out="$(panel)"
{ [ "$(wc -l < "$T/starts")" = 1 ] && printf '%s' "$out" | grep -q '"RED"'; } \
  && ok "a clock that stops again straight after is red, not restarted in a loop" || no "flap: $out"
rm -f "$T/healable" "$T/starts" "$S/trouble/testhost.clock-restart"; panel >/dev/null; out="$(panel)"
{ [ "$(wc -l < "$T/starts")" = 1 ] && printf '%s' "$out" | grep -q '"RED"'; } \
  && ok "a clock that stays down is red and is not restarted again" || no "stays red: $out"

[ "$fail" = 0 ] && echo "test_clock_lock: PASS" || echo "test_clock_lock: FAIL"
exit "$fail"

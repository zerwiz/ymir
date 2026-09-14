#!/usr/bin/env bash
# Unit tests for the machine-scoped primary session lock (bin/gleipnir-lock-lib.sh).
#
# The primary holds ONE machine-global lock so a second checkout of the same
# machine cannot run a competing session; an Eindri-home keeps its own per-home
# lock so workers run in parallel. A pre-contract session lives at the legacy
# state/.lock and must still resolve during migration.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/bin/gleipnir-lock-lib.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- path resolution ---------------------------------------------------------

out=$(BROKK_HOME="$TMP/home" BROKK_MACHINE_STATE_DIR="$TMP/machine" \
  bash -c '. "$0"; gleipnir_lock_path p; printf "%s" "$p"' "$LIB")
[ "$out" = "$TMP/machine/brokk.lock" ] && ok "primary lock is machine-global" \
  || bad "primary lock path: $out"

mkdir -p "$TMP/ehome/data"; : > "$TMP/ehome/data/eindri-home"
out=$(BROKK_HOME="$TMP/ehome" BROKK_MACHINE_STATE_DIR="$TMP/machine" \
  bash -c '. "$0"; gleipnir_lock_path p; printf "%s" "$p"' "$LIB")
[ "$out" = "$TMP/ehome/state/.lock" ] && ok "Eindri-home marker keeps a per-home lock" \
  || bad "Eindri-home lock path: $out"

out=$(BROKK_HOME_KIND=eindri BROKK_HOME="$TMP/ehome2" BROKK_MACHINE_STATE_DIR="$TMP/machine" \
  bash -c '. "$0"; gleipnir_lock_path p; printf "%s" "$p"' "$LIB")
[ "$out" = "$TMP/ehome2/state/.lock" ] && ok "BROKK_HOME_KIND=eindri keeps a per-home lock" \
  || bad "env Eindri-home lock path: $out"

# --- acquire writes the machine lock and the pointer -------------------------

mkdir -p "$TMP/home/state"
BROKK_HOME="$TMP/home" BROKK_MACHINE_STATE_DIR="$TMP/machine" BROKK_SESSION_PID="$$" \
  bash -c '. "$0"; gleipnir_lock_acquire; gleipnir_lock_owner o; printf "%s" "$o"' "$LIB" > "$TMP/owner"
[ "$(cat "$TMP/owner")" = "$$" ] && ok "acquire records the session pid" \
  || bad "owner: $(cat "$TMP/owner")"
[ -f "$TMP/machine/brokk.lock" ] && ok "machine lock file written" \
  || bad "machine lock file missing"
[ "$(cat "$TMP/home/state/.lock-path" 2>/dev/null)" = "$TMP/machine/brokk.lock" ] \
  && ok "pointer records the resolved lock path" \
  || bad "pointer missing or wrong"

# --- a second session on the same machine is refused -------------------------

out=$(BROKK_HOME="$TMP/other" BROKK_MACHINE_STATE_DIR="$TMP/machine" BROKK_SESSION_PID="1" \
  bash -c '. "$0"; if gleipnir_lock_acquire; then printf acquired; else printf refused; fi' "$LIB")
[ "$out" = "refused" ] && ok "a live machine lock refuses a second session" \
  || bad "second session: $out"

# --- migration: a legacy home lock is still honored --------------------------

rm -f "$TMP/machine/brokk.lock"; mkdir -p "$TMP/home2/state"; printf '%s\n' "$$" > "$TMP/home2/state/.lock"
out=$(BROKK_HOME="$TMP/home2" BROKK_MACHINE_STATE_DIR="$TMP/machine" \
  bash -c '. "$0"; gleipnir_lock_owner o; printf "%s" "$o"' "$LIB")
[ "$out" = "$$" ] && ok "legacy home lock is honored during migration" \
  || bad "legacy owner: $out"

# --- reap clears a dead machine lock -----------------------------------------

mkdir -p "$TMP/machine"; printf '999999\n' > "$TMP/machine/brokk.lock"
BROKK_HOME="$TMP/home" BROKK_MACHINE_STATE_DIR="$TMP/machine" \
  bash -c '. "$0"; gleipnir_lock_reap' "$LIB" >/dev/null 2>&1
[ -e "$TMP/machine/brokk.lock" ] && bad "stale machine lock not reaped" \
  || ok "a dead machine lock is reaped"

# --- acquire records a starttime sidecar --------------------------------------

BROKK_HOME="$TMP/home" BROKK_MACHINE_STATE_DIR="$TMP/machine" BROKK_SESSION_PID="$$" \
  bash -c '. "$0"; gleipnir_lock_acquire' "$LIB" >/dev/null 2>&1
[ -s "$TMP/machine/brokk.lock.starttime" ] && ok "acquire records a starttime sidecar" \
  || bad "starttime sidecar missing after acquire"

# --- reap clears a lock whose recorded starttime no longer matches (pid reuse) --

# Use a live unrelated process (this shell) with a deliberately wrong starttime:
# liveness sees the pid "alive" via kill(0) but the recorded starttime belongs
# to a process that is no longer the owner — i.e. the kernel recycled the pid.
mkdir -p "$TMP/machine"; printf '%s\n' "$$" > "$TMP/machine/brokk.lock"
printf '0\n' > "$TMP/machine/brokk.lock.starttime"
BROKK_HOME="$TMP/home" BROKK_MACHINE_STATE_DIR="$TMP/machine" \
  bash -c '. "$0"; gleipnir_lock_reap' "$LIB" >/dev/null 2>&1
[ -e "$TMP/machine/brokk.lock" ] && bad "recycled-pid lock not reaped" \
  || ok "a lock whose pid was recycled is reaped"

# --- reap clears a lock held by a real zombie ---------------------------------

# Fork a child, kill it, and keep the parent alive WITHOUT waiting: the child
# becomes a zombie. kill(0) on a zombie succeeds — the old liveness checked
# only that and missed the death; reap must now see the Z state and clear it.
python3 -c '
import os, signal, sys, time
p = os.fork()
if p == 0:
    time.sleep(10); os._exit(0)
else:
    time.sleep(0.3)
    os.kill(p, signal.SIGKILL)
    time.sleep(0.3)
    with open(sys.argv[1], "w") as h:
        h.write(str(p))
    time.sleep(30)
' "$TMP/zombie.pid" &
zombie_keeper=$!
for _i in 1 2 3 4 5 6 7 8 9 10; do
  [ -s "$TMP/zombie.pid" ] && break
  sleep 0.2
done
zombie_pid=$(cat "$TMP/zombie.pid" 2>/dev/null || true)
state=$(awk '{print $3}' "/proc/$zombie_pid/stat" 2>/dev/null)
if [ -n "$zombie_pid" ] && [ "$state" = "Z" ]; then
  printf '%s\n' "$zombie_pid" > "$TMP/machine/brokk.lock"
  rm -f "$TMP/machine/brokk.lock.starttime"
  BROKK_HOME="$TMP/home" BROKK_MACHINE_STATE_DIR="$TMP/machine" \
    bash -c '. "$0"; gleipnir_lock_reap' "$LIB" >/dev/null 2>&1
  [ -e "$TMP/machine/brokk.lock" ] && bad "zombie-held lock not reaped" \
    || ok "a zombie-held lock is reaped (kill(0) alone cannot see this)"
else
  bad "test setup: expected a zombie child (got state ${state:-none})"
fi
kill "$zombie_keeper" 2>/dev/null || true

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"

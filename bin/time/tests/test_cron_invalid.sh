#!/usr/bin/env bash
# test_cron_invalid.sh — `--status` counts the invalid rows of the schedule as it is NOW, and a clock that
# retires says so without an unbound variable (plan 369 item 12). Scratch home, scratch state, no real alert.
set -u
ROOT="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
CRON="$ROOT/bin/time/nornir-cron-start.sh"
T="$(mktemp -d)"
H="$T/home"; S="$H/state"; C="$H/config"; STUB="$T/root"
mkdir -p "$T/mach" "$S" "$C" "$H/hodd" "$STUB/bin/notify" "$STUB/.pi" "$STUB/RULES"
printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB/bin/notify/send.sh"; chmod +x "$STUB/bin/notify/send.sh"
fail=0; ok() { printf 'ok   %s\n' "$1"; }; no() { printf 'FAIL %s\n' "$1"; fail=1; }
clock() {
  env -i PATH="$PATH" HOME="$T" XDG_STATE_HOME="$T/xdg" YMIR_HOME="$H" BROKK_STATE_OVERRIDE="$S" \
    BROKK_CONFIG_OVERRIDE="$C" BROKK_ROOT_OVERRIDE="$STUB" BROKK_ROLES=dev BROKK_MACHINE_STATE_DIR="$T/mach" \
    BROKK_CRON_TICK=1 BROKK_CRON_LOCK_GRACE=1 BROKK_CRON_LOCK_RECHECK=1 bash "$CRON" "$@"
}
trap 'rm -rf "$T"' EXIT

# rows a former scheduler could not read, left in the file; the schedule now holds only readable rows
printf '@heart @every:5 true\n@heart @every:30 true\n' > "$S/.cron-invalid"
printf '@heart @every:5 true\n@heart @every:30 true\n' > "$C/cron.yaml"
out="$(clock --status 2>&1)"
case "$out" in *invalid=*) no "stale rows are still counted: $out" ;; *"jobs=2"*) ok "a row that is readable now is not invalid" ;; *) no "status: $out" ;; esac

printf '25:99 true\n@every:5 true\n' > "$C/cron.yaml"
out="$(clock --status 2>&1)"
case "$out" in *"invalid=1"*) ok "an unreadable row is counted, with no scheduler running" ;; *) no "status: $out" ;; esac

# no lock at all: it retires, and the log carries no shell error
: > "$S/cron.log"
clock >/dev/null 2>&1
for _ in $(seq 1 40); do grep -q 'cron retired' "$S/cron.log" 2>/dev/null && break; sleep 0.25; done
grep -q 'cron retired' "$S/cron.log" && ! grep -q 'unbound variable' "$S/cron.log" \
  && ok "a retiring clock says so, with no unbound variable" || no "retire log: $(tail -n 3 "$S/cron.log")"

[ "$fail" = 0 ] && echo "test_cron_invalid: PASS" || echo "test_cron_invalid: FAIL"
exit "$fail"

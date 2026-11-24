#!/usr/bin/env bash
# nornir-catchup.test.sh — a scheduler that was down fires today's missed HH:MM job once, never twice.
# A fake `date` sets the clock; BROKK_CRON_ONCE=1 makes the loop run one pass.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCHED="$ROOT/bin/time/nornir-cron-start.sh"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
STATE="$WORK/state"; CONF="$WORK/conf"; FAKE="$WORK/bin"; LOCKD="$WORK/lock"; MARK="$WORK/fired"
mkdir -p "$STATE" "$CONF" "$FAKE" "$LOCKD"; : >"$MARK"
printf '%s\n' "$$" >"$LOCKD/brokk.lock"; printf '%s\n' "$LOCKD/brokk.lock" >"$STATE/.lock-path"
cat >"$FAKE/date" <<'EOS'
#!/usr/bin/env bash
case "$*" in
  "+%H:%M") printf '%s\n' "${FAKE_NOW#* }" ;;
  "+%Y-%m-%d") printf '%s\n' "${FAKE_NOW%% *}" ;;
  "+%Y-%m-%dT%H") printf '%sT%s\n' "${FAKE_NOW%% *}" "$(printf '%s' "${FAKE_NOW#* }" | cut -d: -f1)" ;;
  "+%M") printf '%s\n' "${FAKE_NOW##*:}" ;;
  "-u +%Y-%m-%dT%H:%M:%SZ") printf '%sT%s:00Z\n' "${FAKE_NOW%% *}" "${FAKE_NOW#* }" ;;
  *) printf '%s\n' "${FAKE_NOW:-1970-01-01 00:00}" ;;
esac
EOS
chmod +x "$FAKE/date"
printf '06:45 printf "sweep\\n" >> %s\n19:20 printf "late\\n" >> %s\n' "$MARK" "$MARK" >"$CONF/cron.yaml"
run_at() { PATH="$FAKE:$PATH" FAKE_NOW="$1" BROKK_CRON_ONCE=1 BROKK_CRON_TICK=1 BROKK_STATE_OVERRIDE="$STATE" \
  BROKK_CONFIG_OVERRIDE="$CONF" BROKK_ROLES=dev bash "$SCHED" >/dev/null 2>&1; sleep 2; }
n() { grep -c "^$1\$" "$MARK" 2>/dev/null || true; }
fails=0
chk() { if [ "$2" = "$3" ]; then printf '  %-48s PASS\n' "$1"; else printf '  %-48s FAIL (want %s got %s)\n' "$1" "$2" "$3"; fails=$((fails+1)); fi; }
run_at "2026-11-24 14:00"; chk "a missed morning job fires once on restart" 1 "$(n sweep)"
chk "a job not yet due does not fire" 0 "$(n late)"
run_at "2026-11-24 14:01"; chk "the catch-up does not repeat" 1 "$(n sweep)"
rm -f "$STATE/.cron-fired/"*; run_at "2026-11-25 23:00"; chk "a miss older than the window stays missed (sweep still 1)" 1 "$(n sweep)"
[ "$fails" = 0 ] && { echo "nornir-catchup: PASS"; exit 0; }; echo "nornir-catchup: $fails FAILED" >&2; exit 1

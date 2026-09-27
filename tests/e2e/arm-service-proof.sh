#!/usr/bin/env bash
# arm-service-proof.sh — the arm-as-a-service proofs, runnable, not asserted
# (plan 58, Phase 2).
#
#   tests/e2e/arm-service-proof.sh proof     the plan's gate, live, in a
#                                            throwaway state: the arm seats with
#                                            NO session and idles, its heartbeat
#                                            stays fresh, a killed arm returns,
#                                            status goes non-zero on an induced
#                                            gap, the thin client relays what the
#                                            service raised, and Eir names it
#   tests/e2e/arm-service-proof.sh systemd   the same restart proof THROUGH
#                                            systemd --user: kill -9 the unit's
#                                            main process and watch Restart=always
#                                            bring it back (skips cleanly with a
#                                            named reason where no user manager
#                                            answers)
#
# Everything runs against a scratch state dir with BROKK_STATE_OVERRIDE, so no
# proof touches the live home's arm, its wake queue, or its session lock.
#
# Exit: 0 every proof held · 1 a proof failed · 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WATCH="$ROOT/bin/syn-watch.sh"
ARM="$ROOT/bin/syn-watch-arm.sh"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  proof|systemd) ACTION="$1" ;;
  *) printf 'error: unknown verb %s\nhelp: tests/e2e/arm-service-proof.sh [proof|systemd]\n' "$1" >&2; exit 2 ;;
esac

rows=""
fail=0
record() {  # <name> <ok|FAIL> <evidence>
  rows="${rows}  \"$1\",\"$2\",\"$3\"\n"
  [ "$2" = "ok" ] || fail=1
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ymir-arm-proof.XXXXXX")"
export BROKK_STATE_OVERRIDE="$TMP/state"
export BROKK_MACHINE_STATE_DIR="$TMP/machine"
export BROKK_WATCH_POLL_SECONDS=1
export BROKK_WATCH_DAEMON_GRACE_SECONDS=3
export SYN_WATCH_UNIT="ymir-arm-proof"
mkdir -p "$BROKK_STATE_OVERRIDE" "$BROKK_MACHINE_STATE_DIR"

UNIT_ACTIVE=0
cleanup() {
  [ "$UNIT_ACTIVE" = 1 ] && { systemctl --user stop "$SYN_WATCH_UNIT" >/dev/null 2>&1 || true; systemctl --user reset-failed "$SYN_WATCH_UNIT" >/dev/null 2>&1 || true; }
  "$WATCH" stop >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

lease_pid() { sed -n 's/^pid=\([^ ]*\).*/\1/p' "$BROKK_STATE_OVERRIDE/.arm.lease" 2>/dev/null; }
heartbeat_age() {
  local beat
  beat="$(tr -d '[:space:]' <"$BROKK_STATE_OVERRIDE/.watch.heartbeat" 2>/dev/null || true)"
  case "$beat" in ''|*[!0-9]*) printf '%s' '-1'; return 0 ;; esac
  printf '%s' "$(( $(date -u +%s) - beat ))"
}
session_field() { sed -n 's/.* session=\([^ ]*\).*/\1/p' "$BROKK_STATE_OVERRIDE/.arm.lease" 2>/dev/null | head -1; }

case "$ACTION" in
  proof)
    # 1. seat the arm and prove it stands with NO session seated.
    "$WATCH" start >/dev/null 2>&1
    first="$(lease_pid)"
    if [ -n "$first" ] && kill -0 "$first" 2>/dev/null; then
      record "seats" ok "lease pid=$first"
    else
      record "seats" FAIL "no live lease in $BROKK_STATE_OVERRIDE"
    fi
    # 2. idle-not-dead: the session helm is empty and the arm is still healthy.
    sess="$(session_field)"
    if [ "$sess" = "none" ] && "$WATCH" status >/dev/null 2>&1; then
      record "idle-no-session" ok "session=none, status rc=0 ($("$WATCH" status --detail 2>/dev/null | head -1))"
    else
      record "idle-no-session" FAIL "session=${sess:-?} status rc=$("$WATCH" status >/dev/null 2>&1; echo $?)"
    fi
    # 3. heartbeat fresh.
    age="$(heartbeat_age)"
    if [ "$age" -ge 0 ] && [ "$age" -lt 60 ]; then
      record "heartbeat" ok "age=${age}s"
    else
      record "heartbeat" FAIL "age=${age}s"
    fi
    # 4. the thin client relays what the service raises, and outlives the service.
    printf 'proof wake\n' >"$BROKK_STATE_OVERRIDE/.wake-queue"
    sleep 3   # let the standing service raise it into the delivery slot
    timeout 8 bash "$ARM" --restart >"$TMP/client.out" 2>"$TMP/client.err"
    if grep -q '^signal: wake queue$' "$TMP/client.out"; then
      record "relays" ok "signal: wake queue"
    else
      record "relays" FAIL "client output: [$(tr '\n' '|' <"$TMP/client.out" 2>/dev/null)]"
    fi
    # A fresh client now ATTACHES and waits (queue unchanged): kill the service
    # under it and it must re-seat the watch rather than lose it.
    ( timeout 25 bash "$ARM" --restart >"$TMP/client2.out" 2>"$TMP/client2.err" ) &
    client=$!
    sleep 2
    kill -9 "$first" 2>/dev/null
    sleep 6
    second="$(lease_pid)"
    if [ -n "$second" ] && [ "$second" != "$first" ] && kill -0 "$second" 2>/dev/null; then
      record "killed-returns" ok "pid $first -> $second ($(tr '\n' ' ' <"$TMP/client2.err" 2>/dev/null))"
    else
      record "killed-returns" FAIL "pid $first -> ${second:-none}"
    fi
    kill "$client" 2>/dev/null
    # 5. the re-seated arm is still alive and beating.
    # 6. an induced gap is LOUD: stop the arm, status must exit non-zero.
    "$WATCH" stop >/dev/null 2>&1
    if "$WATCH" status >/dev/null 2>&1; then
      record "gap-is-loud" FAIL "status reported healthy with no live arm"
    else
      record "gap-is-loud" ok "status rc=1: $("$WATCH" status 2>&1 | tail -2 | tr '\n' ' ')"
    fi
    # 7. Eir names the arm (and mends it back).
    "$WATCH" start >/dev/null 2>&1
    arm_row="$(timeout 120 bash "$ROOT/bin/eir-doctor.sh" check 2>/dev/null | grep -m1 '^  "arm",')"
    case "$arm_row" in
      *'"ok"'*) record "eir-names-it" ok "${arm_row#  }" ;;
      *)        record "eir-names-it" FAIL "${arm_row:-no arm row in eir-doctor output}" ;;
    esac
    ;;
  systemd)
    if ! systemctl --user show --property=Version >/dev/null 2>&1; then
      record "systemd-unit" FAIL "no systemd --user manager answers on this host"
    else
      systemd-run --user --unit="$SYN_WATCH_UNIT" --collect \
        -p Type=simple -p Restart=always -p RestartSec=1 -p TimeoutStopSec=5 \
        -p "Environment=BROKK_STATE_OVERRIDE=$BROKK_STATE_OVERRIDE" \
        -p "Environment=BROKK_MACHINE_STATE_DIR=$BROKK_MACHINE_STATE_DIR" \
        -p Environment=SYN_WATCH_MODE=systemd \
        /bin/bash "$WATCH" run >/dev/null 2>&1
      UNIT_ACTIVE=1
      sleep 3
      first="$(lease_pid)"
      if [ -n "$first" ] && [ "$(systemctl --user show -p ActiveState --value "$SYN_WATCH_UNIT" 2>/dev/null)" = "active" ]; then
        record "systemd-unit" ok "unit active, lease pid=$first, session=$(session_field)"
      else
        record "systemd-unit" FAIL "unit not active or no lease"
      fi
      kill -9 "$first" 2>/dev/null
      sleep 5
      second="$(lease_pid)"
      if [ -n "$second" ] && [ "$second" != "$first" ] && [ "$(systemctl --user show -p ActiveState --value "$SYN_WATCH_UNIT" 2>/dev/null)" = "active" ]; then
        record "systemd-restart" ok "Restart=always: pid $first -> $second"
      else
        record "systemd-restart" FAIL "pid $first -> ${second:-none}"
      fi
      age="$(heartbeat_age)"
      if [ "$age" -ge 0 ] && [ "$age" -lt 60 ]; then
        record "systemd-heartbeat" ok "age=${age}s"
      else
        record "systemd-heartbeat" FAIL "age=${age}s"
      fi
      systemctl --user stop "$SYN_WATCH_UNIT" >/dev/null 2>&1
      UNIT_ACTIVE=0
      if "$WATCH" status >/dev/null 2>&1; then
        record "systemd-gap-is-loud" FAIL "status reported healthy after the unit stopped"
      else
        record "systemd-gap-is-loud" ok "status rc=1 after systemctl --user stop"
      fi
    fi
    ;;
esac

printf 'arm-service-proof[1]{verb,verdict}:\n  "%s","%s"\n' "$ACTION" "$([ "$fail" = 0 ] && echo PASS || echo FAIL)"
printf 'proofs[%s]{proof,state,evidence}:\n' "$(printf '%b' "$rows" | grep -c .)"
printf '%b' "$rows"
[ "$fail" = 0 ] || printf 'arm-service-proof: a proof failed — see the FAIL row\n' >&2
exit "$fail"

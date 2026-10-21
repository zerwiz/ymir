#!/usr/bin/env bash
# garmr-smoke.sh — GARMR's smoke test. Is the hound listening, or merely running?
#
# Reusable by hand, by Eir, by a cron row, or by CI. Read-only: it starts nothing,
# stops nothing, pauses nothing, and writes nothing outside its own temp dir.
#
#   bin/ward/garmr-smoke.sh              # the whole check
#   bin/ward/garmr-smoke.sh --quiet      # exit code only
#   bin/ward/garmr-smoke.sh --no-units   # skip the systemd checks (a CI runner, a container)
#
# The distinction it exists for: a service can be `active` and observing NOTHING — that
# is exactly what happened on 2026-10-21 when the hound sat on a rotated audit log for
# three minutes and looked calm. So this test asks three different questions:
#   * is it RUNNING      (units)
#   * is it ARMED        (audit rules in the kernel)
#   * is it WORKING      (a heartbeat that is fresh, and findings that are clean)
#
# Exit: 0 all pass (skips are not failures) · 1 a real failure · 2 usage.
set -u
VERSION="1.0.0"

QUIET=0; UNITS=1
for a in "$@"; do
  case "$a" in
    --quiet|-q) QUIET=1 ;;
    --no-units) UNITS=0 ;;
    --version|-v) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
done

# Under sudo, HOME is root's: adopt the operator's so the hoard resolves.
if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
  op_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  [ -n "$op_home" ] && export HOME="$op_home"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# The hoard is RESOLVED, never restated (Rule 07/25): ask the one resolver, and
# export the answer so the Python sense modules agree with this script.
if [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  # shellcheck disable=SC1091
  . "$ROOT/bin/vault/hoard-lib.sh" >/dev/null 2>&1 || true
  if command -v ymir_home_root >/dev/null 2>&1; then
    garmr_home=""
    ymir_home_root garmr_home 2>/dev/null || true
    [ -n "$garmr_home" ] && export YMIR_HOME="$garmr_home"
  fi
fi
GARMR="$ROOT/bin/ward/garmr"
PY="$(command -v python3 || echo /usr/bin/python3)"
STATE_ROOT="/var/log/ymir/garmr"
HEARTBEAT="$STATE_ROOT/state/hound.heartbeat"
FINDINGS="$STATE_ROOT/findings.jsonl"
MARKER="$STATE_ROOT/PAUSED"

fails=0; passes=0; skips=0
say() { [ "$QUIET" = 1 ] || printf '%s\n' "$*"; }
row() { # <name> <PASS|FAIL|SKIP> <note>
  case "$2" in
    PASS) passes=$((passes + 1)) ;;
    FAIL) fails=$((fails + 1)) ;;
    SKIP) skips=$((skips + 1)) ;;
  esac
  [ "$QUIET" = 1 ] || printf '  "%-22s","%s","%s"\n' "$1" "$2" "$3"
}

say "garmr-smoke{check,state,note}:"
say "  \"config\",\"$( [ -n "${YMIR_HOME:-}" ] && echo "\$YMIR_HOME" || echo resolved )\",\"the hoard and the settings\""

# 1 · does the resolver answer at all?
if PYTHONPATH="$GARMR" "$PY" -c 'import common; c=common.load_config(); print(c["_config_path"])' >/dev/null 2>&1; then
  row config PASS "$(PYTHONPATH="$GARMR" "$PY" -c 'import common; print(common.load_config()["_config_path"])' 2>/dev/null)"
else
  row config FAIL "the settings do not resolve — set YMIR_HOME or fix config/guardian.yaml"
fi

# 2 · the unit suite (the redactor, the rules, the parser) — no root, always runnable
if [ -f "$ROOT/.agents/tests/garmr.test.sh" ]; then
  if bash "$ROOT/.agents/tests/garmr.test.sh" >/dev/null 2>&1; then
    row "unit tests" PASS ".agents/tests/garmr.test.sh"
  else
    row "unit tests" FAIL "bash .agents/tests/garmr.test.sh — the redactor, the rules or the parser"
  fi
else
  row "unit tests" FAIL "the test file is missing"
fi

# 3 · is it ARMED? (root only: auditctl is root's to read)
if [ "$(id -u)" -eq 0 ]; then
  armed="$(auditctl -l 2>/dev/null | grep -c 'ymir-')"
  if [ "${armed:-0}" -ge 1 ]; then
    row "audit armed" PASS "${armed} rule(s) in the kernel"
  else
    row "audit armed" FAIL "no ymir- rules — sudo bin/ward/garmr.sh install"
  fi
  audit_exec="$(auditctl -l 2>/dev/null | grep -c 'key=ymir-exec')"
  [ "${audit_exec:-0}" -ge 1 ] && row "exec sense" PASS "ymir-exec armed" \
    || row "exec sense" FAIL "no ymir-exec rule — executions are not being seen"
else
  row "audit armed" SKIP "needs root: sudo bin/ward/garmr-smoke.sh"
fi

# 4 · is it RUNNING?
if [ "$UNITS" = 1 ]; then
  if systemctl is-active --quiet garmr-hound.service 2>/dev/null; then
    row "hound unit" PASS "garmr-hound.service active"
  elif [ -f "$MARKER" ]; then
    row "hound unit" SKIP "paused by root at $(cat "$MARKER")"
  else
    row "hound unit" FAIL "garmr-hound.service is not active — journalctl -u garmr-hound.service"
  fi
  userctl=(systemctl --user)
  if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    userctl=(sudo -u "$SUDO_USER" XDG_RUNTIME_DIR="/run/user/${SUDO_UID}" systemctl --user)
  fi
  if "${userctl[@]}" is-active --quiet garmr-brain.timer 2>/dev/null; then
    row "brain timer" PASS "garmr-brain.timer active"
  elif [ -f "$MARKER" ]; then
    row "brain timer" SKIP "paused by root"
  else
    row "brain timer" FAIL "garmr-brain.timer is not active — systemctl --user status garmr-brain.timer"
  fi
else
  row "units" SKIP "--no-units"
fi

# 5 · is it WORKING? a fresh heartbeat, and findings that are clean
if [ -f "$MARKER" ]; then
  row "heartbeat" SKIP "paused by root at $(cat "$MARKER") — a paused hound is not a silent one"
elif [ -f "$HEARTBEAT" ]; then
  age=$(( $(date +%s) - $(date -r "$HEARTBEAT" +%s) ))
  if [ "$age" -le 300 ]; then
    row "heartbeat" PASS "${age}s old"
  elif [ -f "$MARKER" ]; then
    row "heartbeat" SKIP "paused by root at $(cat "$MARKER")"
  else
    row "heartbeat" FAIL "${age}s old — the hound is SILENT (a stopped watcher is a finding)"
  fi
else
  if [ -f "$MARKER" ]; then row "heartbeat" SKIP "paused by root"
  else row "heartbeat" FAIL "no heartbeat ever — the hound has not run"; fi
fi

readable=1
if [ -f "$FINDINGS" ]; then
  [ -r "$FINDINGS" ] || readable=0
  if [ "$readable" = 1 ]; then
    lines=$(wc -l < "$FINDINGS" | tr -d ' ')
    row "findings" PASS "${lines} record(s)"
    leaks=$(grep -c 'snotra/\|hodd/data/snotra\|hodd/secrets\|Bearer [A-Za-z0-9]' "$FINDINGS" 2>/dev/null || true)
    if [ "${leaks:-0}" -eq 0 ]; then
      row "no leak" PASS "no sensitive path or token in the findings"
    else
      row "no leak" FAIL "${leaks} record(s) carry a sensitive path or token — the redactor failed"
    fi
  else
    row "findings" SKIP "not readable as this user (root-only record)"
  fi
else
  row "findings" FAIL "no findings file — the senses have written nothing"
fi

# 6 · the on/off switch is root's (a non-root pause must be refused)
if [ "$(id -u)" -ne 0 ]; then
  if bash "$ROOT/bin/ward/garmr.sh" pause >/dev/null 2>&1; then
    row "pause guarded" FAIL "a non-root process could pause the hound — stop and fix this"
  else
    row "pause guarded" PASS "a non-root pause is refused"
  fi
fi

say ""
say "garmr-smoke{pass,fail,skip}: \"${passes}\",\"${fails}\",\"${skips}\""
[ "$fails" -eq 0 ] || { [ "$QUIET" = 1 ] || say "help: the FAIL rows above name the door to open"; exit 1; }
[ "$QUIET" = 1 ] || say "garmr-smoke: the hound is listening"
exit 0

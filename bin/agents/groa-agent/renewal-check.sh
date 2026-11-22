#!/usr/bin/env bash
# renewal-check.sh — is the nightly pair seated, and did its last night end well? (plan 350 part C)
#
# Eir's `renewal` surface. The pair is Gróa's timer and Eir's night unit, chained (Gróa's unit starts
# eir-night.service on success AND on failure). It is RED when:
#   · the platform has a user service manager and the pair is not seated (timer not enabled, the Eir unit
#     absent, or Gróa's unit not chained to it), or
#   · the last night FAILED (a stage hung, a door was missing, Gróa failed outright), or
#   · the last night is older than RENEWAL_MAX_AGE_H (36) hours — the timer stopped firing.
# A night that ended `owed` is not red here: the owed surfaces are red in their own rows.
# A platform with no user service manager is a clean skip, named (RULES/25).
#
#   renewal-check.sh [--detail]      exit 0 healthy or a clean skip · 1 red; --detail prints one line
set -u
DETAIL=0; [ "${1:-}" = --detail ] && DETAIL=1
UNITS="${RENEWAL_UNIT_DIR:-$HOME/.config/systemd/user}"
AGENTS_DIR="${RENEWAL_LAUNCHD_DIR:-$HOME/Library/LaunchAgents}"
STATE="${RENEWAL_STATE:-}"
if [ -z "$STATE" ]; then
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck disable=SC1091
  . "$here/../../vault/hoard-lib.sh" 2>/dev/null && hoard_state_dir STATE 2>/dev/null
fi
LAST="${STATE:-$HOME/.local/state/ymir}/renewal/last-night.json"
say() { [ "$DETAIL" = 1 ] && printf '%s\n' "$1"; return 0; }

platform="${RENEWAL_PLATFORM:-}"
if [ -z "$platform" ]; then
  if [ "$(uname -s)" = Darwin ]; then platform=launchd
  elif command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then platform=systemd
  else platform=none; fi
fi
case "$platform" in
  none) say "no user service manager on this machine — the nightly pair cannot be seated here (a clean skip)"; exit 0 ;;
  systemd)
    [ -f "$UNITS/groa-agent.timer" ] || { say "red: groa-agent.timer is not seated — bash bin/agents/groa-agent/seat.sh"; exit 1; }
    [ -f "$UNITS/eir-night.service" ] || { say "red: eir-night.service is not seated — bash bin/agents/groa-agent/seat.sh"; exit 1; }
    grep -q '^OnSuccess=eir-night.service' "$UNITS/groa-agent.service" 2>/dev/null \
      || { say "red: Gróa's unit does not start Eir after it — bash bin/agents/groa-agent/seat.sh"; exit 1; }
    if [ -z "${RENEWAL_UNIT_DIR:-}" ] && ! systemctl --user is-enabled groa-agent.timer >/dev/null 2>&1; then
      say "red: groa-agent.timer is not enabled — systemctl --user enable --now groa-agent.timer"; exit 1
    fi ;;
  launchd)
    [ -f "$AGENTS_DIR/org.ymir.renewal.plist" ] || { say "red: the nightly launch agent is not seated — bash bin/agents/groa-agent/seat.sh"; exit 1; } ;;
esac

[ -r "$LAST" ] || { say "seated; no night has run yet"; exit 0; }
python3 - "$LAST" "${RENEWAL_MAX_AGE_H:-36}" "$DETAIL" <<'PY'
import json, sys, time
path, max_h, detail = sys.argv[1], float(sys.argv[2]), sys.argv[3] == "1"
try:
    r = json.load(open(path))
except Exception:
    print("red: the last night's record is unreadable") if detail else None
    sys.exit(1)
age_h = (time.time() - r.get("ts", 0)) / 3600
when = time.strftime("%Y-%m-%d %H:%M", time.localtime(r.get("ts", 0)))
if r.get("result") == "failed":
    why = "; ".join(x for x in (r.get("hung") and "hung: " + r["hung"], r.get("failed")) if x)
    print(f"red: the night of {when} failed — {why}") if detail else None
    sys.exit(1)
if age_h > max_h:
    print(f"red: the last night ran {age_h:.0f} h ago ({when}) — the timer stopped firing") if detail else None
    sys.exit(1)
print(f"the night of {when}: {r.get('result')} — Gróa rc {r.get('groa_rc')}, mended {' '.join(r.get('mended') or []) or 'nothing'}") if detail else None
PY

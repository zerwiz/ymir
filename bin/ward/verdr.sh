#!/usr/bin/env bash
# verdr.sh — VÖRÐR, the warden: the standing report.
#
# He walks the house, sees what the eyes see (bin/ward/security-audit.sh), checks the
# things that must be true whether or not anyone is attacking (the clock is synced, the
# well is whole, the keys are seated, the wards pass), writes the report where records
# live, and says one line out loud when something is HIGH.
#
#   verdr.sh report        # walk, print, and write the dated report   (default)
#   verdr.sh last          # the newest written report
#   verdr.sh --no-alert    # do not speak on the desktop
#
# He NEVER changes a door: closing one is the Allfather's decision (bin/ward/harden.sh).
#
# Exit: 0 nothing above the floor · 1 a HIGH or CRITICAL finding · 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  . "$SCRIPT_DIR/../vault/hoard-lib.sh" 2>/dev/null || true
fi
HOME_DIR=""; [ -n "${YMIR_HOME:-}" ] && HOME_DIR="$YMIR_HOME"
[ -n "$HOME_DIR" ] || { command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root HOME_DIR; }
WARD_DIR="${HOME_DIR:-$HOME}/hodd/memory/ward"

CMD="${1:-report}"; shift || true
ALERT=1
[ "${1:-}" = "--no-alert" ] && { ALERT=0; shift; }
case "$CMD" in
  report|last|--version|-h|--help) ;;
  *) printf 'error: unknown command %s\nhelp: verdr.sh [report|last] [--no-alert]\n' "$CMD" >&2; exit 2 ;;
esac
[ "$CMD" = "--version" ] && { printf '%s\n' "$VERSION"; exit 0; }
[ "$CMD" = "-h" ] || [ "$CMD" = "--help" ] && { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' ; exit 0; }

if [ "$CMD" = "last" ]; then
  f="$(ls -1t "$WARD_DIR"/*.md 2>/dev/null | head -1)"
  [ -n "$f" ] && cat "$f" || printf 'no report yet — bin/ward/verdr.sh report\n'
  exit 0
fi

audit="$(bash "$SCRIPT_DIR/security-audit.sh" check 2>/dev/null)"; audit_rc=$?
crit="$(printf '%s' "$audit" | grep -c '"CRITICAL"' || true)"
high="$(printf '%s' "$audit" | grep -c '"HIGH"' || true)"

# The things that must be true whether or not anyone is attacking.
clock="ok"; sync="unknown"
if [ -x "$ROOT/bin/time/sol.sh" ]; then
  sync="$(bash "$ROOT/bin/time/sol.sh" check 2>/dev/null | sed -nE 's/.*"ntp_synchronized","([^"]+)".*/\1/p' | head -1)"
  case "$sync" in yes) ;; *) clock="NOT SYNCHRONISED" ;; esac
fi
well="ok"
if [ -x "$ROOT/bin/records/well-guard.sh" ]; then
  bash "$ROOT/bin/records/well-guard.sh" check >/dev/null 2>&1 || well="a memory loss or junk row"
fi
guards="ok"
if [ -x "$ROOT/bin/gates/guards.sh" ]; then
  bash "$ROOT/bin/gates/guards.sh" >/dev/null 2>&1 || guards="a gate ward is failing"
fi
keys="$(grep -c '^ssh-' "$HOME/.ssh/authorized_keys" 2>/dev/null || echo 0)"
tunnels="$(ls -1 "$HOME/.cloudflared"/config-*.yml 2>/dev/null | wc -l | tr -d ' ')"

verdict="clear"
[ "$high" != "0" ] && verdict="attention"
[ "$crit" != "0" ] && verdict="ACT NOW"

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
local_now="$(bash "$ROOT/bin/time/sol.sh" iso --plain 2>/dev/null || date)"

# The report is assembled by a FUNCTION, not by $(...) — a code fence inside a command
# substitution is a backtick command, and the first version of this script proved it.
write_report() {
  cat <<REPORT
# Vörðr — the warden's report — $now

**Verdict:** $verdict · $crit critical · $high high

\`\`\`
warden[6]{check,state}:
  "clock","$clock (ntp_synchronized=$sync)"
  "the well","$well"
  "the gate wards","$guards"
  "ssh keys authorized","$keys"
  "public tunnels configured","$tunnels"
  "local time","$local_now"
\`\`\`

## The audit

\`\`\`
$audit
\`\`\`

## The mends, written out (nothing here is applied)

\`\`\`
$(bash "$SCRIPT_DIR/harden.sh" plan 2>/dev/null)
\`\`\`

*Written by bin/ward/verdr.sh. Append-only: the next report is a new file, never an edit.*
REPORT
}

if [ -n "$HOME_DIR" ]; then
  mkdir -p "$WARD_DIR"
  out="$WARD_DIR/$(date -u +%Y-%m-%d).md"
  if [ -e "$out" ]; then
    out="$WARD_DIR/$(date -u +%Y-%m-%dT%H%M%SZ).md"
  fi
  write_report >"$out"
  printf 'verdr[1]{wrote,verdict,critical,high}:\n  "%s","%s",%s,%s\n' "${out#"$HOME_DIR"/}" "$verdict" "$crit" "$high"
else
  write_report
fi

if [ "$ALERT" = 1 ] && { [ "$crit" != "0" ] || [ "$high" != "0" ]; }; then
  say="$ROOT/bin/time/snotra/ymir-say.sh"
  [ -x "$say" ] && "$say" fail "Vörðr: $crit critical, $high high — bin/ward/verdr.sh last" >/dev/null 2>&1 || true
fi

[ "$crit" != "0" ] || [ "$high" != "0" ] && exit 1
exit 0

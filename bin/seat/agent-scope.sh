#!/usr/bin/env bash
# agent-scope.sh — every errand's hand stands in its own cgroup, so a kill is LOCAL.
#
# Why (plan 001 §4 F1, measured 2026-11-17): 27 agents lived in ONE cgroup — the desk's. The kernel
# picked one `opencode`, systemd answered by stopping the unit, and every pane came back a shell. A
# ceiling on the desk bounds the pot; a SCOPE per agent makes the death small. With this door in the
# launch path, a hand that eats its own limit is killed alone and the desk still answers.
#
# The limits are the machine's, sized from `free -m` at run time (Rule 07: nothing hardcoded), and
# every one is overridable:
#
#   MemoryHigh   10 % of MemTotal   the hand is throttled before it is killed
#   MemoryMax    15 % of MemTotal   past this, the kernel kills this SCOPE, not the desk
#   MemorySwapMax 12.5 % of swap    a hand may not leak into the machine's swap
#
# A clean skip is a pass (RULES/25): on a host with no systemd user manager (macOS, a container
# without a session bus) the command runs unwrapped and the door SAYS SO — a silent downgrade would
# hide that the failsafe is absent on that machine.
#
# Usage:
#   agent-scope.sh [--max MB] [--high MB] [--swap MB] [--name NAME] -- <command...>
#   agent-scope.sh limits                  # the numbers this machine gives
#   agent-scope.sh --check                 # can this host scope an agent? (0 yes, 0 clean skip says so)
#
# Env:
#   YMIR_AGENT_SCOPE=0        run unwrapped, deliberately (names itself in the output)
#   YMIR_AGENT_HIGH_MB / YMIR_AGENT_MAX_MB / YMIR_AGENT_SWAP_MB
#   YMIR_SCOPE_DRY=1          print the systemd-run line instead of running it (tests)
#
# Exit: the command's own exit status (0 from `limits`/`--check`).
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() { sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
say()  { printf '%s\n' "$*"; }

mem_total_mb() {
  free -m 2>/dev/null | awk '/^Mem:/{print $2}' | head -1
}
swap_total_mb() {
  free -m 2>/dev/null | awk '/^Swap:/{print $2}' | head -1
}
pct_of() {  # <value> <numerator> <denominator>
  case "${1:-}" in ''|*[!0-9]*) printf '0'; return 0 ;; esac
  printf '%s' "$(( $1 * $2 / $3 ))"
}

# THE ONE READING of the limits. `limits` prints it, the wrapper uses it — never two arithmetics.
read_limits() {
  local total swap
  total="$(mem_total_mb)"; swap="$(swap_total_mb)"
  HIGH_MB="${YMIR_AGENT_HIGH_MB:-$(pct_of "${total:-0}" 10 100)}"
  MAX_MB="${YMIR_AGENT_MAX_MB:-$(pct_of "${total:-0}" 15 100)}"
  SWAP_MB="${YMIR_AGENT_SWAP_MB:-$(pct_of "${swap:-0}" 125 1000)}"
  [ "${HIGH_MB:-0}" -gt 0 ] 2>/dev/null || HIGH_MB=512
  [ "${MAX_MB:-0}" -gt 0 ] 2>/dev/null || MAX_MB=1024
  case "${SWAP_MB:-0}" in ''|*[!0-9]*) SWAP_MB=256 ;; esac
}

# scoping_available — the user manager must answer, and `systemd-run --scope` must exist. A host with
# neither is not broken; it simply has no cgroup to put the hand in, and the caller is told.
scoping_available() {
  [ "${YMIR_AGENT_SCOPE:-1}" = "0" ] && return 1
  command -v systemd-run >/dev/null 2>&1 || return 1
  command -v systemctl >/dev/null 2>&1 || return 1
  systemctl --user is-system-running >/dev/null 2>&1 || systemctl --user status >/dev/null 2>&1 || return 1
  return 0
}

skip_reason() {
  [ "${YMIR_AGENT_SCOPE:-1}" = "0" ] && { printf 'YMIR_AGENT_SCOPE=0'; return; }
  command -v systemd-run >/dev/null 2>&1 || { printf 'no systemd-run on this host'; return; }
  command -v systemctl >/dev/null 2>&1 || { printf 'no systemctl on this host'; return; }
  printf 'no systemd user manager answered'
}

ACTION=""
NAME=""
while [ $# -gt 0 ]; do
  case "$1" in
    -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) usage 0 ;;
    limits) ACTION=limits; shift ;;
    --check|check) ACTION=check; shift ;;
    --max) MAX_MB_OVERRIDE="${2:-}"; shift 2 ;;
    --high) HIGH_MB_OVERRIDE="${2:-}"; shift 2 ;;
    --swap) SWAP_MB_OVERRIDE="${2:-}"; shift 2 ;;
    --name) NAME="${2:-}"; shift 2 ;;
    --) shift; break ;;
    *) break ;;
  esac
done

read_limits
[ -n "${MAX_MB_OVERRIDE:-}" ] && MAX_MB="$MAX_MB_OVERRIDE"
[ -n "${HIGH_MB_OVERRIDE:-}" ] && HIGH_MB="$HIGH_MB_OVERRIDE"
[ -n "${SWAP_MB_OVERRIDE:-}" ] && SWAP_MB="$SWAP_MB_OVERRIDE"

print_limits() {
  printf 'agent-scope[1]{high_mb,max_mb,swap_max_mb,scope}:\n  "%s","%s","%s","%s"\n' \
    "$HIGH_MB" "$MAX_MB" "$SWAP_MB" "$(scoping_available && printf yes || printf "no — $(skip_reason)")"
}

case "$ACTION" in
  limits) print_limits; exit 0 ;;
  check)
    if scoping_available; then
      printf 'agent-scope-check[1]{verdict,note}:\n  "scoped","an agent runs in its own cgroup; MemoryMax=%sM so a kill stays local"\n' "$MAX_MB"
      exit 0
    fi
    printf 'agent-scope-check[1]{verdict,note}:\n  "clean skip","%s — the command runs unwrapped, and the failsafe is ABSENT on this host"\n' "$(skip_reason)"
    exit 0 ;;
esac

[ $# -gt 0 ] || { printf 'error: nothing to run\nhelp: agent-scope.sh [--max MB] -- <command...>\n' >&2; exit 2; }

if ! scoping_available; then
  printf 'agent-scope: clean skip — %s; running the command unwrapped\n' "$(skip_reason)" >&2
  exec "$@"
fi

[ -n "$NAME" ] || NAME="ymir-agent-$$-$(date +%s)"
# --collect: a dead scope leaves no failed unit behind (a transient residue is not a record).
set -- systemd-run --user --scope --collect --quiet \
  --unit="$NAME" \
  -p "MemoryHigh=${HIGH_MB}M" \
  -p "MemoryMax=${MAX_MB}M" \
  -p "MemorySwapMax=${SWAP_MB}M" \
  -- "$@"

if [ "${YMIR_SCOPE_DRY:-0}" = "1" ]; then
  printf '%s\n' "$*"
  exit 0
fi
exec "$@"

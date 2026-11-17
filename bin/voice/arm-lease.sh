#!/usr/bin/env bash
# arm-lease.sh — the LEASE between the ranks: write it, renew it, reclaim it, read it, and
# ask WHICH authority a spawn may use (plan 310 §3–§5).
#
# THE THREE RANKS, ONE LOCK EACH (plan 310 §3):
#
#   the machine arm      one per machine — the right to act on it: spawn, steer, merge,
#                        drain. `bin/voice/rodd-arm.sh hold` takes it, and only a session
#                        that CAN SPEAK may (bin/voice/arm-speak-lib.sh defines that; a
#                        watcher is not a speaker).
#   a project's          one per active project — it holds NO arm: it holds a LEASE from
#   orchestrator         its machine arm, "you may have N hands until T", renewed by
#                        heartbeat. THIS DOOR is where that lease is written and read.
#   the crown            one for the fleet — the orchestrator of orchestrators. Only its
#                        RANK is read here (a lease row whose scope is `crown`); its own
#                        service is the Allfather's to seal (plan 310 §7.3) and is not
#                        built by this errand.
#
# Usage:
#   arm-lease.sh list                       # every lease, live or dead, with its verdict
#   arm-lease.sh grant <scope> [--holder H] [--machine M] [--hands N] [--ttl S]
#   arm-lease.sh renew <n> [--ttl S]        # a live lease beats again (a dead one is not renewed)
#   arm-lease.sh reclaim <n> [--why W]      # the machine takes a dead lease back, unasked
#   arm-lease.sh alive <n>                  # is lease <n> still beating? exit 0 live · 1 dead
#   arm-lease.sh authority [<scope>] [--dir D]
#                                           # which authority a spawn may use here, and why
#   arm-lease.sh ranks [--line]             # who holds what, and WHICH RANK THIS SEAT HOLDS
#   arm-lease.sh speaks [<pid>]             # the one definition of "can speak", asked aloud
#   arm-lease.sh who                        # where the table is, and where the journal is
#   arm-lease.sh --check                    # the one-line verdict, for a health surface
#   arm-lease.sh --version
#
# Env (all optional, one default each — Rule 07):
#   YMIR_ARM_LEASE_STATE   the state dir whose table is read (default: the home's state)
#   YMIR_ARM_LEASE_HANDS   hands a lease grants by default (2)
#   YMIR_ARM_LEASE_TTL     seconds a lease runs before it must be renewed (3600)
#   YMIR_ARM_LEASE_STALE   silence after which a lease is reclaimable (300)
#   YMIR_ARM_SCOPE         this caller's project scope, instead of the main worktree's name
#   YMIR_SPEAK_MAX_AGE     how old a transcript may be and still prove a live model (1800)
#
# Exit: 0 ran · 3 refused (a live lease is not reclaimed, an authority is not granted,
#       nobody can speak) · 2 usage · 1 the door itself failed.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

HOARD_LIB="$ROOT/bin/vault/hoard-lib.sh"
# shellcheck source=bin/voice/arm-lease-lib.sh
. "$SCRIPT_DIR/arm-lease-lib.sh"
# shellcheck source=bin/voice/arm-speak-lib.sh
. "$SCRIPT_DIR/arm-speak-lib.sh"

usage() { sed -n '2,42p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
# Every sentence a person reads begins with Sól's stamp (plan 272, fault 4).
if [ -r "$SCRIPT_DIR/../time/sol-lib.sh" ]; then . "$SCRIPT_DIR/../time/sol-lib.sh"; else sol_line() { date '+%Y-%m-%d %H:%M %Z'; }; fi
die()   { printf '%s — arm-lease: %s\n' "$(sol_line)" "$*" >&2; exit 1; }
refuse(){ printf '%s — arm-lease: %s\n' "$(sol_line)" "$*" >&2; exit 3; }

# The state is RESOLVED, never guessed (Rule 04/07). YMIR_ARM_LEASE_STATE is the seam a
# test uses, so no proof ever touches the live table.
STATE=""
resolve_state() {
  if [ -n "${YMIR_ARM_LEASE_STATE:-}" ]; then STATE="$YMIR_ARM_LEASE_STATE"; return 0; fi
  [ -r "$HOARD_LIB" ] || die "the home resolver is missing ($HOARD_LIB) — no state dir can be named"
  # shellcheck source=bin/vault/hoard-lib.sh
  . "$HOARD_LIB"
  hoard_state_dir STATE || die "the home resolver could not name a state dir"
}

# This seat's own name: the sealed one where the roster names it, else the pid that asks.
seat_name() {
  local name="${YMIR_SEAT_NAME:-}"
  [ -n "$name" ] || name="$(sed -n 's/^primary=//p' "$HOME/.pi/agent/extensions/.ymir-seat" 2>/dev/null | head -1)"
  if [ -z "$name" ]; then speaks_claimant_pid _sp; name="pid${_sp}"; fi
  printf '%s' "$name"
}

lease_row_out() {  # one row, exactly the plan's shape
  printf 'lease[1]{n,holder,machine,scope,hands,granted,expires,heartbeat}:\n'
  printf '  "%s","%s","%s","%s","%s","%s","%s","%s"\n' \
    "$LEASE_N" "$LEASE_HOLDER" "$LEASE_MACHINE" "$LEASE_SCOPE" "$LEASE_HANDS" \
    "$LEASE_GRANTED" "$LEASE_EXPIRES" "$LEASE_HEARTBEAT"
}

cmd_list() {
  resolve_state
  local table line n any=0
  table="$(arm_lease_file "$STATE")"
  printf 'arm-leases[1]{state_dir,table,journal,rows}:\n'
  printf '  "%s","%s","%s","%s"\n' "$STATE" "$table" "$(arm_lease_journal "$STATE")" \
    "$(awk '!/^#/ && NF>=8' "$table" 2>/dev/null | awk 'END{print NR}')"
  printf 'leases{verdict,n,holder,machine,scope,hands,granted,expires,heartbeat,detail}:\n'
  [ -r "$table" ] || { printf '  "no lease on this machine","-","-","-","-","-","-","-","-","nothing has been granted here"\n'; return 0; }
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    n="${line%%$'\t'*}"
    arm_lease_row "$table" "$n" || continue
    any=1
    if arm_lease_fresh; then
      printf '  "live","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' \
        "$LEASE_N" "$LEASE_HOLDER" "$LEASE_MACHINE" "$LEASE_SCOPE" "$LEASE_HANDS" \
        "$LEASE_GRANTED" "$LEASE_EXPIRES" "$LEASE_HEARTBEAT" "$(arm_lease_sexagesimal "$LEASE_EXPIRES") left"
    else
      printf '  "dead","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' \
        "$LEASE_N" "$LEASE_HOLDER" "$LEASE_MACHINE" "$LEASE_SCOPE" "$LEASE_HANDS" \
        "$LEASE_GRANTED" "$LEASE_EXPIRES" "$LEASE_HEARTBEAT" "$LEASE_WHY — reclaim: arm-lease.sh reclaim $LEASE_N"
    fi
  done <"$table"
  [ "$any" = 1 ] || printf '  "no lease on this machine","-","-","-","-","-","-","-","-","nothing has been granted here"\n'
  return 0
}

cmd_grant() {
  resolve_state
  local scope="${1:-}" holder="" machine="" hands="" ttl=""
  shift || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --holder) holder="${2:-}"; shift 2 ;;
      --holder=*) holder="${1#--holder=}"; shift ;;
      --machine) machine="${2:-}"; shift 2 ;;
      --machine=*) machine="${1#--machine=}"; shift ;;
      --hands) hands="${2:-}"; shift 2 ;;
      --hands=*) hands="${1#--hands=}"; shift ;;
      --ttl) ttl="${2:-}"; shift 2 ;;
      --ttl=*) ttl="${1#--ttl=}"; shift ;;
      *) die "grant does not take '$1' (usage: grant <scope> [--holder H] [--machine M] [--hands N] [--ttl S])" ;;
    esac
  done
  [ -n "$scope" ] || die 'grant needs a scope: arm-lease.sh grant ymir'
  [ -n "$holder" ] || holder="$(seat_name)"
  arm_lease_grant "$STATE" "$holder" "$scope" "${hands:-$ARM_LEASE_HANDS}" "${ttl:-$ARM_LEASE_TTL}" "$machine" \
    || die "the lease could not be written to $(arm_lease_file "$STATE")"
  lease_row_out
  printf 'lease-detail[1]{verb,expires_in,renew_with,reclaim_with}:\n'
  printf '  "grant","%s","arm-lease.sh renew %s","arm-lease.sh reclaim %s (only once the heartbeat stops)"\n' \
    "$(arm_lease_sexagesimal "$LEASE_EXPIRES")" "$LEASE_N" "$LEASE_N"
  return 0
}

cmd_renew() {
  resolve_state
  local n="${1:-}" ttl=""
  shift || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --ttl) ttl="${2:-}"; shift 2 ;;
      --ttl=*) ttl="${1#--ttl=}"; shift ;;
      *) die "renew does not take '$1'" ;;
    esac
  done
  case "$n" in ''|*[!0-9]*) die 'renew needs a lease number: arm-lease.sh renew 3' ;; esac
  arm_lease_renew "$STATE" "$n" "${ttl:-$ARM_LEASE_TTL}"
  case $? in
    0) ;;
    2) refuse "there is no lease $n on this machine — a renewal of nothing would invent a claim" ;;
    *) die "the lease table could not be written ($(arm_lease_file "$STATE"))" ;;
  esac
  lease_row_out
  printf 'lease-detail[1]{verb,expires_in,heartbeat_age_s}:\n  "renew","%s","0"\n' "$(arm_lease_sexagesimal "$LEASE_EXPIRES")"
  return 0
}

cmd_reclaim() {
  resolve_state
  local n="${1:-}" why="heartbeat stopped"
  shift || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --why) why="${2:-}"; shift 2 ;;
      --why=*) why="${1#--why=}"; shift ;;
      *) die "reclaim does not take '$1'" ;;
    esac
  done
  case "$n" in ''|*[!0-9]*) die 'reclaim needs a lease number: arm-lease.sh reclaim 3' ;; esac
  # The row is read BEFORE the reclaim: the report must name what was taken.
  local holder scope machine hands
  arm_lease_row "$(arm_lease_file "$STATE")" "$n" || refuse "there is no lease $n on this machine — nothing to reclaim"
  holder="$LEASE_HOLDER"; scope="$LEASE_SCOPE"; machine="$LEASE_MACHINE"; hands="$LEASE_HANDS"
  arm_lease_reclaim "$STATE" "$n" "$why"
  case $? in
    0) ;;
    3) refuse "lease $n is ALIVE (heartbeat ${LEASE_AGE}s ago) — a reclaim of a living claim would be theft; it expires on its own at $(date -d "@$LEASE_EXPIRES" '+%Y-%m-%d %H:%M %Z' 2>/dev/null || printf '%s' "$LEASE_EXPIRES")" ;;
    *) die "the lease table could not be written ($(arm_lease_file "$STATE"))" ;;
  esac
  printf 'lease-reclaim[1]{verb,n,holder,machine,scope,hands,why,journal}:\n'
  printf '  "reclaim","%s","%s","%s","%s","%s","%s","%s"\n' \
    "$n" "$holder" "$machine" "$scope" "$hands" "$why" "$(arm_lease_journal "$STATE")"
  return 0
}

cmd_alive() {
  resolve_state
  local n="${1:-}"
  case "$n" in ''|*[!0-9]*) die 'alive needs a lease number: arm-lease.sh alive 3' ;; esac
  arm_lease_row "$(arm_lease_file "$STATE")" "$n" || { printf 'lease %s is not on this machine\n' "$n"; return 1; }
  if arm_lease_fresh; then
    printf 'lease %s is LIVE — %s\n' "$n" "$LEASE_WHY"
    return 0
  fi
  printf 'lease %s is NOT a live lease — %s\n' "$n" "$LEASE_WHY"
  return 1
}

cmd_authority() {
  resolve_state
  local scope="" dir="$PWD"
  while [ $# -gt 0 ]; do
    case "$1" in
      --dir) dir="${2:-$PWD}"; shift 2 ;;
      --dir=*) dir="${1#--dir=}"; shift ;;
      *) [ -z "$scope" ] && scope="$1"; shift ;;
    esac
  done
  [ -n "$scope" ] || scope="$(arm_scope_of "$dir")"
  arm_authority "$STATE" "$scope"
  local rc=$?
  printf 'authority[1]{verdict,source,scope,machine,detail}:\n'
  printf '  "%s","%s","%s","%s","%s"\n' "$AUTH_VERDICT" "$AUTH_SOURCE" "$scope" "$(arm_machine_name)" "$AUTH_WHY"
  if [ "$rc" != 0 ]; then
    printf 'refused: %s\nhelp: a machine arm grants a lease — bin/voice/arm-lease.sh grant %s --holder <name> — or a session that can speak takes the arm: bin/voice/rodd-arm.sh hold\n' \
      "$AUTH_WHY" "$scope" >&2
  fi
  return "$rc"
}

cmd_ranks() {
  resolve_state
  local line=0 sess=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --line) line=1; shift ;;
      *) die "ranks does not take '$1'" ;;
    esac
  done
  speaks_claimant_pid sess
  if [ "$line" = 1 ]; then arm_rank_line "$STATE" "$sess"; return 0; fi
  arm_ranks_rows "$STATE" "$sess"
  arm_rank_line "$STATE" "$sess"
  return 0
}

cmd_speaks() {
  local pid="${1:-}"
  if [ -z "$pid" ]; then speaks_claimant_pid pid; fi
  speaks_probe "$pid"
  local rc=$?
  speaks_line
  return "$rc"
}

cmd_who() {
  resolve_state
  printf 'arm-lease[1]{verb,state_dir,table,journal,stale_s,hands_default,ttl_s,this_seat,this_scope}:\n'
  printf '  "who","%s","%s","%s","%s","%s","%s","%s","%s"\n' \
    "$STATE" "$(arm_lease_file "$STATE")" "$(arm_lease_journal "$STATE")" \
    "$ARM_LEASE_STALE" "$ARM_LEASE_HANDS" "$ARM_LEASE_TTL" "$(seat_name)" "$(arm_scope_of)"
  return 0
}

cmd_check() {
  resolve_state
  local table live=0 dead=0 line n
  table="$(arm_lease_file "$STATE")"
  if [ -r "$table" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in ''|'#'*) continue ;; esac
      n="${line%%$'\t'*}"
      arm_lease_row "$table" "$n" || continue
      if arm_lease_fresh; then live=$((live + 1)); else dead=$((dead + 1)); fi
    done <"$table"
  fi
  printf 'arm-lease[1]{verdict,state_dir,live,dead,table}:\n'
  if [ "$dead" -gt 0 ]; then
    printf '  "dead leases to reclaim","%s","%s","%s","%s"\n' "$STATE" "$live" "$dead" "$table"
  else
    printf '  "ok","%s","%s","%s","%s"\n' "$STATE" "$live" "$dead" "$table"
  fi
  return 0
}

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") usage 0 ;;
  list|ls) shift; cmd_list ;;
  grant) shift; cmd_grant "$@" ;;
  renew) shift; cmd_renew "$@" ;;
  reclaim) shift; cmd_reclaim "$@" ;;
  alive) shift; cmd_alive "$@" ;;
  authority|auth) shift; cmd_authority "$@" ;;
  ranks|rank) shift; cmd_ranks "$@" ;;
  speaks) shift; cmd_speaks "$@" ;;
  who) shift; cmd_who ;;
  --check|check) shift; cmd_check ;;
  *) printf 'error: unknown verb %s\nhelp: arm-lease.sh [list|grant|renew|reclaim|alive|authority|ranks|speaks|who|--check]\n' "$1" >&2; exit 2 ;;
esac

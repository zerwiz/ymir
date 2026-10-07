#!/usr/bin/env bash
# role-lib.sh — what this machine IS, and the components its role owes
# (plan 51 Phase 1, the install half). SOURCE-ONLY: functions, no side effects
# beyond resolving the home; callers set the state they need.
#
# One owner for three things the installer must not re-decide:
#
#   the resolution chain   --role / $YMIR_ROLE → the fleet registry (bin/skuld/role.sh)
#                          → this machine's card row in hodd/data/machines.md
#                          → ASK (a real interactive run) → the safe body
#   the component table    which parts each role owes (heart · forge · dev · hand)
#   the machine card       the fold of this machine into hodd/data/machines.md
#                          (plan 39: ONE registry, never a parallel shelf)
#
# `establish_roles` NEVER invents a role the operator did not name and NEVER
# widens to every role's parts: a host that is nowhere declared is asked, and a
# run that cannot ask takes the documented safe body (`dev`, which owns no record
# and runs no record job) and says so. The installer gates its whole step chain
# on `role_has`; nothing else selects components.
#
#   components_for <roles>                 -> "core,harness,..." (deduped)
#   establish_roles                        -> sets ROLE_SET/ROLE_SRC/ROLE_HOST/
#                                             ROLE_COMPONENTS/ROLE_DEFAULTED
#   machine_card_write <host> <roles> <components> <source>
#                                          -> "written" | "unchanged" | "unwritten"
#
# Depends on: bin/vault/hoard-lib.sh (the home), bin/skuld/role.sh + bin/fleet/topology.sh (reads).
set -u

ROLE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _rl in "${ROLE_LIB_DIR}/../vault/hoard-lib.sh" "$ROLE_LIB_DIR/../vault/hoard-lib.sh" "$ROLE_LIB_DIR/../../vault/hoard-lib.sh"; do
    [ -r "$_rl" ] && { . "$_rl"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _rl
fi

role_has() {  # <role> — true when the machine's resolved role set holds it
  case ",${ROLE_SET:-}," in *",$1,"*) return 0 ;; esac
  return 1
}

components_for() {  # <roles> -> the components those roles owe (deduped, stable)
  local rs="$1" r c x seen=" core" out="core"
  for r in ${rs//,/ }; do
    case "$r" in
      heart) c="record well web mesh" ;;
      forge) c="rail harness sandbox" ;;
      dev)   c="harness rail desktop web mesh well sandbox" ;;
      *)     c="" ;;
    esac
    for x in $c; do case "$seen " in *" $x "*) ;; *) seen="$seen $x"; out="$out,$x" ;; esac; done
  done
  printf '%s' "$out"
}

establish_roles() {
  local host="" src="none" roles="" line="" choice="" sh=""
  host="${YMIR_HOST:-$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')}"; host="${host:-unknown}"
  ROLE_HOST="$host"
  sh="$ROLE_LIB_DIR/role.sh"
  if [ -x "$sh" ]; then
    line="$(bash "$sh" resolve --host "$host" --why 2>/dev/null | head -1)"
    roles="${line%%$'\t'*}"; src="${line##*$'\t'}"
  fi
  case "$src" in env|registry|card) ROLE_SET="$roles"; ROLE_SRC="$src" ;; *) ROLE_SET=""; ROLE_SRC="none" ;; esac
  if [ -z "$ROLE_SET" ]; then
    # Nothing declared anywhere. ASK when there is a person to ask; never guess a
    # role the operator did not name, and never install every role's parts.
    if [ "${CHECK:-0}" = 0 ] && [ "${ASSUME_YES:-0}" = 0 ] && [ -t 0 ]; then
      printf '\nThis machine (%s) has no role in the fleet registry.\n' "$host"
      printf 'h = heart (the record) · f = forge (models/GPU) · d = dev (a full body) · n = hand (phone)\n'
      printf 'role [d]: '
      IFS= read -r choice || choice=""
      case "${choice:-d}" in
        h|H|heart) roles="heart" ;;
        f|F|forge) roles="forge" ;;
        d|D|dev|"") roles="dev" ;;
        n|N|none|hand) roles="hand" ;;
        *) roles="dev" ;;
      esac
      ROLE_SET="$roles"; ROLE_SRC="declared"
    else
      ROLE_SET="dev"; ROLE_SRC="none"; ROLE_DEFAULTED=1
    fi
  fi
  export YMIR_ROLE="$ROLE_SET"
  ROLE_COMPONENTS="$(components_for "$ROLE_SET")"
}

# ── the machine card — one registry (plan 51 P1 · plan 39's fold) ────────────
# Every install records what THIS machine IS into the ONE registry
# (`hodd/data/machines.md`) — no parallel shelf, no second card. The card is keyed
# by a deterministic heading (host + role), so a repeat install writes nothing and
# a role change APPENDS a new card: the registry's history is never rewritten
# (Rule 06). It is private machine state and lives in the hoard, never the tree.
machine_card_write() {  # <host> <roles> <components> <source>
  local host="$1" roles="$2" comps="$3" src="$4"
  local data="" machines="" head="" stamp="" os_name="" platform="" link="" heart=""
  # The hoard's data shelf resolves through bin/vault/hoard-lib.sh — never restated here.
  if command -v hoard_data_dir >/dev/null 2>&1; then hoard_data_dir data || data=""; fi
  [ -n "$data" ] || { printf 'unwritten'; return 1; }
  machines="${YMIR_MACHINES_MD:-$data/machines.md}"
  mkdir -p "$data" 2>/dev/null || true
  stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  os_name="$(. /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-unknown}")"
  platform="$(ymir_os 2>/dev/null || printf unknown) · $(uname -m 2>/dev/null || printf unknown)"
  if [ -x "${ROLE_LIB_DIR}/../fleet/topology.sh" ]; then
    link="$(bash "${ROLE_LIB_DIR}/../fleet/topology.sh" 2>/dev/null | sed -nE 's/^  "link","([^"]+)".*/\1/p')"
    heart="$(bash "${ROLE_LIB_DIR}/../fleet/topology.sh" 2>/dev/null | sed -nE 's/^  "heart","([^"]+)".*/\1/p')"
  fi
  head="## Machine card — $host (role: $roles)"
  if [ -f "$machines" ] && grep -qxF "$head" "$machines" 2>/dev/null; then printf 'unchanged'; return 0; fi
  {
    printf '\n%s\n\n' "$head"
    printf -- '- recorded: %s by `bin/engine/ymir-install.sh` (source: %s)\n' "$stamp" "$src"
    printf -- '- role: %s — components: %s\n' "$roles" "$comps"
    printf -- '- host: %s · %s\n' "$host" "$os_name"
    printf -- '- platform: %s\n' "$platform"
    if [ -n "$link" ]; then printf -- '- link: %s%s\n' "$link" "${heart:+ · heart: $heart}"; fi
    printf -- '- re-declare: `bin/skuld/role.sh set %s heart|forge|dev|hand`\n' "$host"
  } >>"$machines" 2>/dev/null || { printf 'unwritten'; return 1; }
  printf 'written'
}

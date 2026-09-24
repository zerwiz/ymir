#!/usr/bin/env bash
# ymir-autoboot.sh — the boot proof: what this seat's roles OWE, and whether
# every owed program would rise at boot. The counter to the silent no-op:
# a unit with no [Install] contract reports `enabled` only by accident, and a
# raise that swallows its failures reports `healthy` by fiction. This command
# reads the truth from systemd directly and exits on what it finds.
#
# Usage:
#   ymir-autoboot.sh status            # per-role truth (TOON)
#   ymir-autoboot.sh verify            # exit 0 iff every owed program is enabled
#                                      # and (active or recorded-deferred)
#   ymir-autoboot.sh verify --quiet    # the installer's final gate — silent on pass
#   ymir-autoboot.sh roles             # this seat's roles
#   ymir-autoboot.sh linger            # Linger value (the boot needs it headless)
#   ymir-autoboot.sh deferred <p> [why]  # record an OPERATOR-understood inactive
#   ymir-autoboot.sh undeferred <p>    # remove that record
#   ymir-autoboot.sh raise             # materialize + raise (fleet-ensure) then verify
#   ymir-autoboot.sh --version
#
# CI: verify is a pure read (it never writes, never enables) — a CI job on a
# provisioned seat, or the installer's final step, may call it freely. It exits
# non-zero when the seat's boot would come up short, naming the programs and
# the reasons.
set -u

VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; esac
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
. "$SCRIPT_DIR/autoboot-lib.sh"

say() { printf '%s\n' "$*"; }

have_manager() {
  systemctl --user show-environment >/dev/null 2>&1 \
    || { say "error: no systemd user manager — cannot verify (is the seat's user session up?)" >&2; return 1; }
}

# One truth row per owed program:
#   enabled | disabled | deferred-state | failed | none
program_row() {  # <program> → state word
  local p="$1"
  if ! autoboot_is_unit_enabled "$p"; then printf '%s\n' disabled; return; fi
  if autoboot_probe "$p"; then printf '%s\n' active; return; fi
  # Nornir's understood state: the scheduler loop lives only while a session
  # lock holds (its own law) — a seat awaiting its session is not a failure.
  if [ "$p" = "nornir" ] && ! autoboot_cron_alive_owner; then printf '%s\n' pending; return; fi
  if autoboot_is_deferred "$p"; then printf '%s\n' "deferred"; return; fi
  if autoboot_is_unit_failed "$p"; then printf '%s\n' failed; return; fi
  printf '%s\n' inactive
}

status() {
  local roles="" owed="" target_en target_state linger roles_line
  autoboot_owed_roles roles
  autoboot_owed owed
  have_manager || return 1
  if autoboot_is_unit_enabled "ymir.target"; then target_en=enabled; else target_en=disabled; fi
  if systemctl --user is-active --quiet "ymir.target" 2>/dev/null; then target_state=active; else target_state=inactive; fi
  linger="$(autoboot_linger)"
  say "autoboot[1]{host,roles,target,linger}:"
  say "  \"$AUTOBOOT_HOST\",\"${roles}\",\"${target_en}/${target_state}\",\"${linger}\""
  say "programs[$(printf '%s' "$owed" | wc -w | tr -d ' ')]{program,enabled,state,what}:"
  local p n=0
  for p in $owed; do
    autoboot_is_unit_enabled "$p" && en=enabled || en=disabled
    say "  \"$p\",\"$en\",\"$(program_row "$p")\",\"$(autoboot_program_desc "$p")\""
    n=$((n+1))
  done
  return 0
}

# Nornir's understood-inactive: the scheduler loop lives only while a session
# lock holds (its own law) — so "cron down AND no live session" is a seat
# awaiting its session, not a failure. Anything else about nornir is.
verify() {  # [--quiet]
  local quiet=0
  [ "${1-}" = "--quiet" ] && quiet=1
  local roles="" owed=""
  autoboot_owed_roles roles
  autoboot_owed owed
  have_manager || return 1
  local bad=0 p st reason cron_state cron_note
  local rows=""
  # The ONE target: if the install did not enable it, nothing of Ymir boots.
  if autoboot_is_unit_enabled "ymir.target"; then
    rows="${rows}  \"ymir.target\",\"enabled\",\"the one target\"\n"
  else
    bad=$((bad+1)); rows="${rows}  \"ymir.target\",\"disabled\",\"the one target — enable it: systemctl --user enable ymir.target\"\n"
  fi
  for p in $owed; do
    st="$(program_row "$p")"
    case "$st" in
      active|pending) rows="${rows}  \"$p\",\"$st\",\"$(autoboot_program_desc "$p")\"\n" ;;
      deferred)  reason="$(autoboot_deferred_reason "$p")"
                 rows="${rows}  \"$p\",\"$st\",\"$(autoboot_program_desc "$p") — deferred: ${reason:-no reason}\"\n" ;;
      *)         bad=$((bad+1))
                 case "$st" in
                   disabled) reason="not enabled — systemctl --user enable ${p}.service" ;;
                   failed)   reason="unit reached FAILED (see: journalctl --user -u ${p}.service)" ;;
                   inactive) reason="enabled but not active — journalctl --user -u ${p}.service" ;;
                   *) reason="unknown state ${st}" ;;
                 esac
                 rows="${rows}  \"$p\",\"$st\",\"$(autoboot_program_desc "$p") — ${reason}\"\n" ;;
    esac
  done
  if [ "$quiet" = 0 ]; then
    say "autoboot[1]{host,roles,verdict}:"
    say "  \"$AUTOBOOT_HOST\",\"${roles}\",\"$([ "$bad" = 0 ] && echo ok || echo FAIL)\""
    say "programs[$(printf '%s' "$owed" | wc -w | tr -d ' ')]{program,state,detail}:"
    printf '%b' "$rows"
  else
    [ "$bad" = 0 ] || printf '%b' "$rows"
  fi
  return "$([ "$bad" = 0 ] && echo 0 || echo 1)"
}

deferred() {
  local p="${1-}" reason="${2-}"
  case " $AUTOBOOT_PROGRAMS " in *" $p "*) ;; *) say "error: unknown program $p (known: $AUTOBOOT_PROGRAMS)" >&2; return 2 ;; esac
  mkdir -p "$AUTOBOOT_STATE_DIR"
  touch "$AUTOBOOT_DEFERRED_FILE" 2>/dev/null || { say "error: cannot write $AUTOBOOT_DEFERRED_FILE" >&2; return 1; }
  awk -F '\t' -v p="$p" '$1!=p' "$AUTOBOOT_DEFERRED_FILE" >"$AUTOBOOT_DEFERRED_FILE.tmp" 2>/dev/null || true
  printf '%s\t%s\n' "$p" "${reason:-no reason given}" >>"$AUTOBOOT_DEFERRED_FILE.tmp"
  mv "$AUTOBOOT_DEFERRED_FILE.tmp" "$AUTOBOOT_DEFERRED_FILE"
  say "autoboot: $p deferred — ${reason:-no reason given}"
  say "autoboot: this is an OPERATOR override; verify will treat $p's inactivity as understood"
}

undeferred() {
  local p="${1-}"
  case " $AUTOBOOT_PROGRAMS " in *" $p "*) ;; *) say "error: unknown program $p (known: $AUTOBOOT_PROGRAMS)" >&2; return 2 ;; esac
  [ -f "$AUTOBOOT_DEFERRED_FILE" ] || { say "autoboot: $p was not deferred"; return 0; }
  awk -F '\t' -v p="$p" '$1!=p' "$AUTOBOOT_DEFERRED_FILE" >"$AUTOBOOT_DEFERRED_FILE.tmp" 2>/dev/null || true
  mv "$AUTOBOOT_DEFERRED_FILE.tmp" "$AUTOBOOT_DEFERRED_FILE"
  say "autoboot: $p no longer deferred"
}

roles() {
  local roles=""
  autoboot_owed_roles roles
  say "roles[1]{host,roles}:"
  say "  \"$AUTOBOOT_HOST\",\"$roles\""
}

linger() {
  say "linger[1]{user,value}:"
  say "  \"$USER\",\"$(autoboot_linger)\""
}

case "${1-}" in
  -h|--help|"") sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//' ;;
  status) status ;;
  verify) shift; verify "${1-}" ;;
  roles) roles ;;
  linger) linger ;;
  raise)
    if [ ! -x "$SCRIPT_DIR/fleet-ensure.sh" ]; then say "error: no fleet-ensure.sh" >&2; exit 2; fi
    "$SCRIPT_DIR/fleet-ensure.sh" ensure || { say "autoboot: raise failed — see above" >&2; exit 1; }
    verify --quiet
    ;;
  deferred) shift; deferred "${1-}" "${2-}" ;;
  undeferred) shift; undeferred "${1-}" ;;
  *) say "error: unknown command (status|verify|roles|linger|raise|deferred|undeferred)" >&2; exit 2 ;;
esac
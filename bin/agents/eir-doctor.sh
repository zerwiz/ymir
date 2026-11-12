#!/usr/bin/env bash
# eir-doctor.sh — Eir, the healer: diagnose the running system, then mend it.
#
# Eir composes the surfaces that already own their health — she does not
# re-implement them. `check` (default) reports each surface; `fix` runs the
# matching repair path for the broken ones. She never arms supervision (the
# harness extension owns that) and never touches a tracked tree.
#
# Usage:
#   eir-doctor.sh [check]                  # diagnose every surface, aggregate TOON
#   eir-doctor.sh fix [surface…]           # mend the broken (or only the named), then re-check
#   eir-doctor.sh fix --safe [surface…]    # mend only what config/surfaces.yaml calls `safe`; list the
#                                          # rest as OWED with the exact command (Gróa runs this one)
#   eir-doctor.sh --version
#
# The surfaces, their order, their roles and their risk class come from config/surfaces.yaml (plan 278),
# read by bin/agents/surfaces.py — the same rows Gróa reads. Without the register Eir falls back to its own
# list and treats every mend as `ask`.
set -u
# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _yc in "${ROOT:-}/bin/vault/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/bin/vault/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)/bin/vault/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/hoard-lib.sh"; do
    [ -n "$_yc" ] && [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yc
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
STATE="${BROKK_STATE_OVERRIDE:-$YMIR_HOME/state}"

# The cloth: colour and marks for the human reading this report; the TOON rows on
# stdout stay the data (bin/desktop/ymir-style.sh).
if [ -z "${YMIR_STYLE_LOADED:-}" ]; then . "$SCRIPT_DIR/../desktop/ymir-style.sh"; YMIR_STYLE_LOADED=1; fi
style_init
# Where an app lives: apps/<surface> in a clone, node_modules/@zerwiz/<pkg> in an
# npm install — both shapes, one resolver (bin/desktop/app-lib.sh).
if [ -z "${YMIR_APP_LIB_LOADED:-}" ]; then
  _ya="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yac in "$_ya/app-lib.sh" "$(CDPATH='' cd "$_ya" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)/bin/desktop/app-lib.sh"; do
    [ -r "$_yac" ] && { . "$_yac"; YMIR_APP_LIB_LOADED=1; break; }
  done
  unset _ya _yac
fi
app_dir sessrumnir APP_SESSRUMNIR || APP_SESSRUMNIR=""


case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-check}"; shift || true
# `fix` takes --safe and surface names (plan 278); `check` takes none.
FIX_SAFE=0; FIX_ONLY=""
[ "$ACTION" = fix ] || set --   # a check judges every surface; extra words are ignored as before
while [ $# -gt 0 ]; do
  case "$1" in
    --safe) FIX_SAFE=1 ;;
    -*)     printf 'error: unknown flag %s\nhelp: bin/agents/eir-doctor.sh fix [--safe] [surface…]\n' "$1" >&2; exit 2 ;;
    *)      FIX_ONLY="$FIX_ONLY $1" ;;
  esac
  shift
done

have() { command -v "$1" >/dev/null 2>&1; }
say_ok() { return 0; }

# ── the platform and the role: a `hand` on Android is a lawful substrate with
# lawful absences. Before 2026-10-21 Eir asked every surface the same question
# everywhere, so the phone reported ten red rows — vault (cryptsetup cannot exist
# under Android), desktop shells (Electron is not built for bionic), autoboot (no
# systemd) — and the two REAL breaks hid among eight false ones. Rule 25: probe,
# never assume; and a clean skip is a pass.
PLATFORM="linux"
if [ -n "${PREFIX:-}" ] && [ -d "${PREFIX:-}/etc" ]; then PLATFORM="termux"; fi
ROLE=""
for _seat in "${HOME}/.pi/agent/extensions/.ymir-seat" "${YMIR_HOME:-/nonexistent}/state/.ymir-seat"; do
  [ -r "$_seat" ] || continue
  ROLE="$(sed -n 's/^role=//p' "$_seat" 2>/dev/null | head -1)"
  [ -n "$ROLE" ] && break
done
unset _seat
FLEET_ROLES="${YMIR_EIR_ROLES-}"
if [ -z "${YMIR_EIR_ROLES+set}" ] && [ -x "$SCRIPT_DIR/../skuld/role.sh" ]; then
  FLEET_ROLES="$(timeout 10 "$SCRIPT_DIR/../skuld/role.sh" resolve 2>/dev/null | tr ',\n' '  ' | sed 's/  */ /g; s/^ //; s/ $//')"
fi

# surface_skip <surface> — 0 when this substrate/role cannot owe the surface.
surface_skip() {
  # The register's roles (plan 278): a surface declared for other roles is not this seat's to owe.
  # The FLEET role is read once from the fleet registry (bin/skuld/role.sh), never the seat's own word
  # (`.ymir-seat` role= names the agent's office, e.g. counsellor). Unresolved: the seat owes everything.
  local _ro="${SURF_ROLES[$1]:-all}" _fr
  if [ "$_ro" != all ] && [ -n "$FLEET_ROLES" ]; then
    for _fr in $FLEET_ROLES; do case ",$_ro," in *",$_fr,"*) _ro=all; break ;; esac; done
    [ "$_ro" = all ] || return 0
  fi
  # A unit check needs systemd (RULES/05: a clean, named skip on another platform layer).
  if [ "$1" = unitdrift ] && ! command -v systemctl >/dev/null 2>&1; then return 0; fi
  # The mail desk is a systemd user unit; a substrate without systemd cannot owe it
  # (a hand). A clean skip with its reason is a pass (RULES/25).
  if [ "$1" = mail ] && [ "$PLATFORM" = termux ]; then return 0; fi
  # No systemd, no unit to keep on the pin (RULES/05: a clean, named skip on another platform layer).
  if [ "$1" = runtimepin ] && ! command -v systemctl >/dev/null 2>&1; then return 0; fi
  [ "$ROLE" = "hand" ] || return 1
  case "$1" in
    # Hnitbjörg needs cryptsetup + loop devices; a hand has neither, and by law the
    # vault is a server-side property (Rule 15/16), never the roaming seat's.
    vault)      return 0 ;;
    # The Electron shells are not built for Android; the seat is the harness.
    shells|sessrumnir|bilskirnir) return 0 ;;
    # No systemd on Android: there is no boot unit to enable. The Pi watcher owns
    # supervision here, and `ymir-autoboot.sh verify` already names the gap.
    autoboot)   return 0 ;;
    # A hand runs no pinned runtime and supervises nothing: the arm and Rödd live on a seat.
    armpin)     return 0 ;;
    # The desk is a systemd user unit: a substrate without systemd (a hand) cannot
    # owe it — and the arm's own door already names that gap.
    mail)       return 0 ;;
    # a hand runs no arm service and no Rödd window: there is no pin for it to owe
    armpin)     return 0 ;;
    runtimepin) return 0 ;;
  esac
  return 1
}

# surface_ok <surface> — 0 when the surface is satisfied by another door.
surface_ok() {
  case "$1" in
    # herdr is one pane backend; tmux is the other, and it is the one this platform has.
    herdr) have tmux ;;
    *) return 1 ;;
  esac
}

surface_detail_skip() {
  case "$1" in
    vault)      printf '%s\n' 'not this seat (no cryptsetup/loop devices on Android)' ;;
    shells|sessrumnir|bilskirnir) printf '%s\n' 'not this seat (desktop shells are not built for bionic)' ;;
    autoboot)   printf '%s\n' 'not this seat (no systemd; the Pi watcher owns supervision)' ;;
    armpin)     printf '%s\n' 'not this seat (a hand runs no pinned runtime)' ;;
    runtimepin) printf '%s\n' 'not this seat (no systemd: no unit to keep on the pin)' ;;
    mail)       printf '%s\n' 'not this seat (no systemd: the desk is a user unit)' ;;
    unitdrift)  printf '%s\n' 'not this seat (no systemd: no unit to compare with its source)' ;;
    *)          if [ "${SURF_ROLES[$1]:-all}" != all ]; then printf 'not this seat (the register owes it to: %s)\n' "${SURF_ROLES[$1]}"
                else printf '%s\n' 'skip'; fi ;;
  esac
}

# Each surface: `s_<name>` = healthy? (exit 0), `f_<name>` = the repair.
SURFACES=(floors seatpaths hooks packaging herdr a2abridge hermes snotra voice council sessrumnir bilskirnir hnoss shells graphics well memory mail unitdrift mcp harness pidoor claudehooks opencode arm armpin runtimepin roddhelm lock gates migrations hoard autoboot vault ward seats seatreap models)

# ── the register (plan 278): config/surfaces.yaml names the surfaces, their roles and their risk class ──
# The array above is the FALLBACK, kept until every seat carries the register. Without the register every
# mend is `ask`, so an update can never mend more than it should because a file was missing.
declare -A SURF_RISK=() SURF_ROLES=() SURF_WHY=()
SURF_REGISTER="${YMIR_EIR_REGISTER:-$ROOT/config/surfaces.yaml}"
SURF_SOURCE="fallback"
if _rows="$(python3 -I "$SCRIPT_DIR/surfaces.py" "$SURF_REGISTER" 2>/dev/null)" && [ -n "$_rows" ]; then
  _list=()
  while IFS=$'\t' read -r _n _r _ro _w; do
    [ -n "$_n" ] || continue
    _list+=("$_n"); SURF_RISK[$_n]="$_r"; SURF_ROLES[$_n]="$_ro"; SURF_WHY[$_n]="$_w"
  done <<<"$_rows"
  SURFACES=("${_list[@]}"); SURF_SOURCE="register"
  unset _list _n _r _ro _w
fi
unset _rows
surface_risk() { printf '%s' "${SURF_RISK[$1]:-ask}"; }
# Test seam: extra surfaces defined by a test, honoured only under YMIR_EIR_TEST=1 (never in a real run).
if [ "${YMIR_EIR_TEST:-}" = 1 ] && [ -n "${YMIR_EIR_TEST_SURFACES:-}" ] && [ -r "$YMIR_EIR_TEST_SURFACES" ]; then
  # shellcheck source=/dev/null
  . "$YMIR_EIR_TEST_SURFACES"
fi

# ── the three surfaces the 2026-11-03 Windows audit found, and the rule they read ──────────
# A SEAT IS NOT UPDATED BY A PULL. The checkout moves; the installed hooks, the PATH a later
# shell sees, and the packaging that builds the door do not. These three ask the doors that own
# those answers, so `eir-doctor check` names the same faults the installer and Gróa heal.
seat_profile() {  # the profile this operator's shell actually reads (probed, never assumed)
  case "${SHELL##*/}" in zsh) printf '%s' "$HOME/.zprofile" ;; *) printf '%s' "$HOME/.profile" ;; esac
}
s_seatpaths() {
  local d f; f="$(seat_profile)"
  for d in "$HOME/.bun/bin" "$HOME/.local/bin"; do
    [ -d "$d" ] || continue
    grep -qF "$d" "$f" 2>/dev/null || return 1     # provisioned, but no login shell would find it
  done
  return 0
}
f_seatpaths() { "$SCRIPT_DIR/../engine/prereq-ensure.sh" --persist-path >/dev/null 2>&1; }

# ── seats: the two faults of 2026-11-10, plus the sweep that closes finished seats ──
# (a) `~/.pi/agent/extensions/.ymir-root` must never name a LINKED WORKTREE — a root is a
#     home, a worktree is an errand, and the errand dies. (b) no Eindri worktree may carry
#     the broken `rm -rf .pi/extensions` + assume-unchanged state that made git report all
#     45 extension files as deleted. (c) the sweep that closes finished seats must be
#     seated on every harness this host actually runs.
# One test for a linked worktree: --git-common-dir and --git-dir resolve to different
# paths (the same expression lives in bin/seat/valknut-load.sh and migration 0019).
_is_linked_worktree() {  # <path>
  local p=${1:-.} common own
  common="$(git -C "$p" rev-parse --git-common-dir 2>/dev/null)" || return 1
  own="$(git -C "$p" rev-parse --git-dir 2>/dev/null)" || return 1
  [ -n "$common" ] && [ -n "$own" ] || return 1
  [ "$(CDPATH='' cd "$p" && CDPATH='' cd "$common" 2>/dev/null && pwd -P)" \
    = "$(CDPATH='' cd "$p" && CDPATH='' cd "$own" 2>/dev/null && pwd -P)" ] && return 1
  return 0
}
s_seats() {
  local pointer="${PI_EXT_HOME:-$HOME/.pi/agent/extensions}/.ymir-root" line
  if [ -r "$pointer" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      case "$line" in */.yggdrasil/*|*/.yggdrasil) return 1 ;; esac
      [ -d "$line" ] && _is_linked_worktree "$line" && return 1
    done <"$pointer"
  fi
  local wt dirty
  while IFS= read -r wt; do
    [ -n "$wt" ] || continue
    case "$wt" in */.yggdrasil/*) ;; *) continue ;; esac
    [ -d "$wt" ] || continue
    dirty="$(git -C "$wt" status --porcelain 2>/dev/null | grep -c '^\( \{0,1\}\)D  *\.pi/extensions/')"
    [ "${dirty:-0}" = 0 ] || return 1
  done < <(git -C "$ROOT" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10)}')
  [ -x "$SCRIPT_DIR/../seat/seat-reap.sh" ] || return 1
  "$SCRIPT_DIR/../seat/seat-reap.sh" --check >/dev/null 2>&1
}
f_seats() {
  # The two structural faults are the migration's to mend (one door, called by install,
  # by Gróa and by Eir alike); the harness hooks are the sweep door's own.
  [ -x "$SCRIPT_DIR/../engine/ymir-migrate.sh" ] && "$SCRIPT_DIR/../engine/ymir-migrate.sh" apply >/dev/null 2>&1
  [ -x "$SCRIPT_DIR/../seat/seat-reap.sh" ] && "$SCRIPT_DIR/../seat/seat-reap.sh" --install >/dev/null 2>&1
  s_seats
}
# The row's detail is ONE clean line: what the sweep's own --check says is not seated, or the harnesses
# it is seated on. (It once printed `the seat wire` with no newline and then the first line of
# `--list`, a TOON header, so the row read as malformed.)
seats_detail() {
  local door="$SCRIPT_DIR/../seat/seat-reap.sh" out bad seated
  [ -x "$door" ] || { printf 'the sweep door is missing (bin/seat/seat-reap.sh)'; return 0; }
  out="$("$door" --check 2>/dev/null)"
  bad="$(printf '%s\n' "$out" | awk -F'","' '/NOT SEATED/{gsub(/^ *"/,"",$1); printf "%s%s", (n++?", ":""), $1}')"
  if [ -n "$bad" ]; then
    printf 'the seat wire is not seated on: %s — bin/seat/seat-reap.sh --install' "$bad"
  else
    seated="$(printf '%s\n' "$out" | awk -F'","' '/","seated","/{gsub(/^ *"/,"",$1); printf "%s%s", (n++?" · ":""), $1}')"
    printf 'the seat wire is seated%s' "${seated:+ on $seated}"
  fi
}
# ── seatreap (plan 255): a seat kept as finished-idle past a day is the fault the
# sweep exists to clear. Where herdr is absent there is no seat to judge — a clean
# skip with its reason, never a guess (RULES/25).
s_seatreap() {
  have herdr || return 0
  local door="$SCRIPT_DIR/../seat/seat-reap.sh" now d f base id age
  [ -x "$door" ] || return 1
  now="$(date +%s)"
  for d in "$STATE" "$ROOT/state"; do
    [ -d "$d" ] || continue
    for f in "$d"/.*.idle-since; do
      [ -f "$f" ] || continue
      base="${f##*/}"; base="${base#.}"; id="${base%.idle-since}"
      age=$(( now - $(head -n1 "$f" 2>/dev/null | tr -dc '0-9') ))
      [ "${age:-0}" -gt 86400 ] && return 1
    done
  done
  return 0
}
f_seatreap() {
  [ -x "$SCRIPT_DIR/../seat/seat-reap.sh" ] && "$SCRIPT_DIR/../seat/seat-reap.sh" --sweep >/dev/null 2>&1
  s_seatreap
}
s_hooks() {
  local hooks; hooks="$(cd "$ROOT" && git rev-parse --git-path hooks 2>/dev/null || printf '.git/hooks')"
  case "$hooks" in /*) ;; *) hooks="$ROOT/$hooks" ;; esac
  [ -x "$hooks/pre-commit" ] && [ -x "$hooks/pre-push" ] || return 1
  # A hook that BAKES a home path dies when that tree is reclaimed, and takes every ward with it
  # (the pre-push hook was taught this on 2026-10-20; the pre-commit one still baked a path).
  ! grep -q "^\"/home/\|^\"/Users/" "$hooks/pre-commit" 2>/dev/null
}
f_hooks() {
  [ -x "$SCRIPT_DIR/../gates/guards/secret-guard.sh" ] && "$SCRIPT_DIR/../gates/guards/secret-guard.sh" --install >/dev/null 2>&1
  [ -x "$SCRIPT_DIR/../gates/guards/fixes-guard.sh" ] && "$SCRIPT_DIR/../gates/guards/fixes-guard.sh" --install >/dev/null 2>&1
}
# The packaged door: every path a shipped installer names must exist, and the host must be able
# to say what it can build. A broken directive is named by the ward; there is no mending here —
# it is a code change, so the fix row points at the ward.
s_packaging() { [ -x "$SCRIPT_DIR/../gates/guards/packaging-guard.sh" ] && "$SCRIPT_DIR/../gates/guards/packaging-guard.sh" check >/dev/null 2>&1; }

s_floors()    { [ -x "$SCRIPT_DIR/../engine/prereq-ensure.sh" ] && "$SCRIPT_DIR/../engine/prereq-ensure.sh" status >/dev/null 2>&1; }
f_floors()    { "$SCRIPT_DIR/../engine/prereq-ensure.sh" ensure --install >/dev/null 2>&1; }
s_herdr()     { [ -x "$SCRIPT_DIR/../seat/herdr-ensure.sh" ] && "$SCRIPT_DIR/../seat/herdr-ensure.sh" status >/dev/null 2>&1; }
f_herdr()     { "$SCRIPT_DIR/../seat/herdr-ensure.sh" ensure --install >/dev/null 2>&1; }
# a2abridge (plan 278, proved 2026-11-12): `a2abridge-ensure.sh status` always exits 0, so this surface was
# green while the directory never rose — the engine's own installer writes `WantedBy=multi-user.target`, a
# target the user manager does not have, so an "enabled" unit is pulled in by nothing at boot. Judge the
# truth instead: no engine is a clean pass (the mesh is optional); an engine whose unit cannot boot, or
# whose directory is down, is broken. The mend is `ensure` WITHOUT --install: it repoints the boot target
# and starts the unit, and never downloads (a missing engine is `ensure --install`, the operator's word).
A2AB_BIN="${A2ABRIDGE_BIN:-$HOME/.a2abridge/bin/a2abridge}"
A2AB_UNIT="${YMIR_A2AB_UNIT:-$HOME/.config/systemd/user/a2abridge-directory.service}"
a2ab_fault() {  # prints the fault, or nothing when healthy
  [ -x "$A2AB_BIN" ] || return 0
  if [ -f "$A2AB_UNIT" ] && grep -qE '^WantedBy=multi-user\.target' "$A2AB_UNIT" 2>/dev/null; then
    printf 'the directory unit boots with multi-user.target, which a user manager never reaches — bin/bridge/a2abridge-ensure.sh ensure'
    return 0
  fi
  if command -v systemctl >/dev/null 2>&1 && [ -f "$A2AB_UNIT" ] \
     && ! systemctl --user is-active --quiet a2abridge-directory 2>/dev/null; then
    printf 'the directory unit is %s — bin/bridge/a2abridge-ensure.sh ensure' \
      "$(systemctl --user is-active a2abridge-directory 2>/dev/null || printf inactive)"
  fi
}
s_a2abridge() { [ -z "$(a2ab_fault)" ]; }
f_a2abridge() { "$SCRIPT_DIR/../bridge/a2abridge-ensure.sh" ensure >/dev/null 2>&1; s_a2abridge; }
a2abridge_detail() {
  local f; f="$(a2ab_fault)"
  if [ -n "$f" ]; then printf '%s' "$f"
  elif [ -x "$A2AB_BIN" ]; then printf '%s · directory up' "$("$A2AB_BIN" version 2>/dev/null | head -1)"
  else printf 'engine absent (optional — bin/bridge/a2abridge-ensure.sh ensure --install)'; fi
}
# unitdrift (plan 278): an installed unit that still runs a value its source has retired. The adopt road
# moves a unit's paths onto the pin and keeps every argument, so the mail desk ran on a retired port through
# every update. The register declares what was retired; the mend re-seats exactly the drifted units.
s_unitdrift() { [ -x "$SCRIPT_DIR/../engine/units.sh" ] || return 0; "$SCRIPT_DIR/../engine/units.sh" drift >/dev/null 2>&1; }
f_unitdrift() {
  local n
  for n in $("$SCRIPT_DIR/../engine/units.sh" drift 2>/dev/null | awk -F'","' '/"DRIFT"/{gsub(/^ *"/,"",$1); print $1}' | sort -u); do
    "$SCRIPT_DIR/../engine/units.sh" write "$n" --render >/dev/null 2>&1 || return 1
  done
  s_unitdrift
}
unitdrift_detail() {
  "$SCRIPT_DIR/../engine/units.sh" drift 2>/dev/null | awk -F'","' 'NR>1{gsub(/^ *"/,"",$1); gsub(/"$/,"",$4); printf "%s%s: %s", (n++?"; ":""), $1, $4}'
}
# A door's own status, read for its first complaint (plan 278: every broken row carries a reason). The
# doors print TOON rows; the first one that names a fault is the reason, with its quotes taken off.
door_reason() {  # <door> [args…]
  "$@" 2>&1 | grep -m1 -E 'ABSENT|absent|MISSING|missing|NOT |not |down|FAIL|stale|refus' \
    | sed -E 's/^ *//; s/"//g; s/,/ · /g' | cut -c1-200
}
s_hermes()    { [ -x "$SCRIPT_DIR/../engine/hermes-ensure.sh" ] && "$SCRIPT_DIR/../engine/hermes-ensure.sh" status >/dev/null 2>&1; }
f_hermes()    { "$SCRIPT_DIR/../engine/hermes-ensure.sh" ensure --install >/dev/null 2>&1; }
# The meeting ear's engine (whisper.cpp + a model); the MCP face + unit ride
# the fleet surface below. A seat that captures but transcribes elsewhere still
# passes (voxtype counts as an engine).
s_snotra()    { [ -x "$SCRIPT_DIR/../../systems/snotra/services/ear/snotra-ensure.sh" ] && "$SCRIPT_DIR/../../systems/snotra/services/ear/snotra-ensure.sh" status >/dev/null 2>&1; }
# The voice engines (whisper STT + piper TTS): a machine property, adopted or installed.
s_voice()     { [ -x "$SCRIPT_DIR/../voice/voice-ensure.sh" ] && "$SCRIPT_DIR/../voice/voice-ensure.sh" status >/dev/null 2>&1; }
f_voice()     { "$SCRIPT_DIR/../voice/voice-ensure.sh" ensure --install >/dev/null 2>&1; }
# The council of models (plan 92): its roster must exist in the home, or `logretta_sit`
# is a loud skip. The surface asks the ensure door, which never overwrites a stack.
s_council()   { [ -x "$SCRIPT_DIR/../pi/logretta-ensure.sh" ] && "$SCRIPT_DIR/../pi/logretta-ensure.sh" status >/dev/null 2>&1; }
f_council()   { "$SCRIPT_DIR/../pi/logretta-ensure.sh" ensure >/dev/null 2>&1; }
f_snotra()    { "$SCRIPT_DIR/../../systems/snotra/services/ear/snotra-ensure.sh" ensure --install >/dev/null 2>&1; }
s_sessrumnir(){ [ -x "$SCRIPT_DIR/../desktop/sessrumnir-ensure.sh" ] && "$SCRIPT_DIR/../desktop/sessrumnir-ensure.sh" status >/dev/null 2>&1; }
f_sessrumnir(){ "$SCRIPT_DIR/../desktop/sessrumnir-ensure.sh" ensure --install >/dev/null 2>&1; }
# Bilskirnir, the business hall (plan 259): healthy when its setup door's --check passes (agent home,
# soul, .env, dependencies); the repair is the door itself. A tree without the app is not owed it.
s_bilskirnir(){ [ -x "$ROOT/apps/bilskirnir/setup.sh" ] || return 0; "$ROOT/apps/bilskirnir/setup.sh" --check >/dev/null 2>&1; }
f_bilskirnir(){ [ -x "$ROOT/apps/bilskirnir/setup.sh" ] && "$ROOT/apps/bilskirnir/setup.sh" >/dev/null 2>&1; }
# Hnoss — the design smithy's model door (2026-11-10). The MCP bridge is only as good as
# the door it reaches a model through; a hand-placed launcher plus a rail/BYOK mismatch
# made every design generation die silently. The ensure door seats the launcher and the
# pi MCP entry, and REFUSES a provider it has no door for instead of falling back.
s_hnoss()     { [ -x "$SCRIPT_DIR/../pi/hnoss-ensure.sh" ] && "$SCRIPT_DIR/../pi/hnoss-ensure.sh" status >/dev/null 2>&1; }
f_hnoss()     { "$SCRIPT_DIR/../pi/hnoss-ensure.sh" ensure >/dev/null 2>&1; }
# The boot law (2026-09-24): every role-owed program enabled and standing. The
# mend for a stopped boot IS the raise — re-materialize, re-enable, re-verify.
s_autoboot()  { [ -x "$SCRIPT_DIR/../engine/ymir-autoboot.sh" ] && "$SCRIPT_DIR/../engine/ymir-autoboot.sh" verify >/dev/null 2>&1; }
f_autoboot()  { [ -x "$SCRIPT_DIR/../fleet/fleet-ensure.sh" ] && "$SCRIPT_DIR/../fleet/fleet-ensure.sh" ensure >/dev/null 2>&1; }
# Hnitbjörg — the encrypted vault. The surface checks only that the tooling and
# the vault directory stand; a sealed vault is HEALTHY, not a fault to mend.
s_vault()     { [ -x "$SCRIPT_DIR/../vault/hnitbjorg-ensure.sh" ] && "$SCRIPT_DIR/../vault/hnitbjorg-ensure.sh" status >/dev/null 2>&1; }
# The ward (Rule 24): Vörðr's audit says whether this machine has a door above the floor.
# A green house with an open port is exactly the state that let a public tunnel answer
# 200 with no login for ten days (2026-10-18).
s_ward()      { [ -x "$SCRIPT_DIR/../ward/security-audit.sh" ] && "$SCRIPT_DIR/../ward/security-audit.sh" check --quiet >/dev/null 2>&1; }
f_ward()      { "$SCRIPT_DIR/../ward/harden.sh" apply --ssh-keys-perm >/dev/null 2>&1; }
f_vault()     { "$SCRIPT_DIR/../vault/hnitbjorg-ensure.sh" ensure --install >/dev/null 2>&1; }
# ── Gná — the mail desk (:8494, plan 193 §14) ────────────────────────────────
# Three named truths, and none of them may masquerade as another:
#   ok            the desk answers /health AND declares an account
#   unconfigured  the desk answers but has no account row — a NAMED, non-green
#                 state, because "no mail" is a claim such a desk cannot make
#   broken        the desk does not answer at all
# The fix is the installer; the ACCOUNT itself is the operator's word, never a mend.
GNA_DESK_PORT="${GNA_DESK_PORT:-8494}"
GNA_DESK_URL="${GNA_DESK_URL:-http://127.0.0.1:$GNA_DESK_PORT}"
mail_accounts_file() {  # the ONE resolver (Rule 04/07) — this file never guesses a home
  local h="${YMIR_HOME:-}"
  [ -n "$h" ] || ymir_home_root h 2>/dev/null || true
  printf '%s\n' "${h:+$h/hodd/memory/mail/accounts.yaml}"
}
mail_state() {  # prints ok | unconfigured | broken — the desk's own answer, never a guess
  local h
  h="$(curl -fsS -m 3 "$GNA_DESK_URL/health" 2>/dev/null)" || { printf 'broken'; return 0; }
  printf '%s' "$h" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("broken"); raise SystemExit
print("ok" if d.get("ok") and d.get("accounts") else "unconfigured")' 2>/dev/null || printf 'broken'
}
mail_grant_keys() {  # the vault KEY NAMES the declared account grants — never a value
  python3 - "$(mail_accounts_file)" <<'PY' 2>/dev/null
import sys, yaml
try:
    rows = (yaml.safe_load(open(sys.argv[1])) or {}).get("accounts") or []
except Exception:
    raise SystemExit(0)
for row in rows:
    if not (isinstance(row, dict) and row.get("id")):
        continue
    for k in ("grant", "client", "client_secret"):
        if row.get(k):
            print(row[k])
    break
PY
}
vault_has_key() {  # <KEY> — the NAME is asked, the value never leaves the vault
  "$ROOT/bin/vault/hodd.sh" emit secrets/platform.env 2>/dev/null | grep -q "^export $1="
}
mail_detail() {
  local st; st="$(mail_state)"
  case "$st" in
    broken)       printf 'no answer at %s/health — bash bin/mail/install.sh' "$GNA_DESK_URL" ;;
    unconfigured) printf 'the desk answers, but no account row in %s — nothing to read, and "no mail" cannot be said' "$(mail_accounts_file)" ;;
    *)            local k missing="" acc
                  acc="$(curl -fsS -m 3 "$GNA_DESK_URL/health" 2>/dev/null | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
print(",".join(d.get("accounts") or []))' 2>/dev/null)"
                  for k in $(mail_grant_keys); do vault_has_key "$k" || missing="$missing $k"; done
                  if [ -n "$missing" ]; then
                    printf 'desk answers for %s at %s, but the declared grant names vault keys that are ABSENT:%s' \
                      "${acc:-no account}" "$GNA_DESK_URL" "$missing"
                  else
                    printf 'desk answers for %s at %s' "${acc:-no account}" "$GNA_DESK_URL"
                  fi ;;
  esac
}
s_mail()      { [ "$(mail_state)" = ok ]; }
# ── the allow-list (2026-11-12): only the models this operator approved run as Eindri ────────
# Broken when a seat still working, or a configured default (agents.yaml, pi's settings), names a
# model the list refuses. The mend is the operator's word (the list, a grant, or stopping the seat),
# never a rewrite by the doctor, so f_models only says where to look.
s_models()    { "$SCRIPT_DIR/../model/model-allow.sh" audit "$STATE" >/dev/null 2>&1; }
f_models()    { return 1; }
models_detail() {
  local out n
  if ! "$SCRIPT_DIR/../model/model-allow.sh" list >/dev/null 2>&1; then printf 'the allow-list does not read — bin/model/model-allow.sh list'; return; fi
  if "$SCRIPT_DIR/../model/model-allow.sh" list 2>/dev/null | sed -n 2p | grep -q unpoliced; then
    printf 'unpoliced — no allow-list at %s (template: config/models-allowed.yaml.example)' "$("$SCRIPT_DIR/../model/model-allow.sh" path)"; return
  fi
  out="$("$SCRIPT_DIR/../model/model-allow.sh" audit "$STATE" 2>/dev/null)"
  n="$(printf '%s\n' "$out" | sed -n '1s/.*\[\([0-9]*\)\].*/\1/p')"
  if [ "${n:-0}" = 0 ]; then printf 'every live seat and configured default is on the allow-list'
  else printf '%s off the allow-list: %s' "$n" "$(printf '%s\n' "$out" | sed -n '2,4p' | cut -d'"' -f2,6 | tr '"' '=' | paste -sd' ' -)"; fi
}
f_mail()      { [ -x "$ROOT/bin/mail/install.sh" ] && "$ROOT/bin/mail/install.sh" >/dev/null 2>&1; }
# The desktop shells (P8, 2026-09-24): the RESOLVER answers — app-local,
# workspace-hoisted, or the sibling package (bin/desktop/electron-lib.sh). ABSENT for
# an app the operator has installed is a FAILURE, never healthy: a desktop
# that cannot open must be reported red, not quietly green. Only a surface
# whose app dir is not installed at all — the recorded web-only decision — is
# skipped.
shell_surfaces() { printf '%s\n' hlidskjalf odrerir sessrumnir; }
s_shells() {
  local s dir state
  while IFS= read -r s; do
    dir=""
    app_dir "$s" dir 2>/dev/null || dir=""
    [ -n "$dir" ] || continue          # not installed — a deliberate web-only install
    state="$(electron_runtime_state "$dir" "$ROOT" "$(app_pkg "$s")" 2>/dev/null)"
    [ "$state" = ok ] || return 1      # absent OR partial: the shell cannot open
  done < <(shell_surfaces)
  return 0
}
f_shells() {
  # The healer MENDS: a gated postinstall is the ordinary case on npm 11+, and telling
  # the user to run the installer by hand was the fault this surface kept reporting
  # (2026-11-08: "electron are missing errors" after every update).
  if [ -x "$SCRIPT_DIR/../desktop/electron-ensure.sh" ]; then
    "$SCRIPT_DIR/../desktop/electron-ensure.sh" ensure --root "$ROOT" --quiet >/dev/null 2>&1 && return 0
  fi
  printf 'eir: the shells still need mending after electron-ensure — the row it printed names the road\n' >&2
  electron_remedy >&2
  return 1
}
if [ -z "${YMIR_ELECTRON_LIB_LOADED:-}" ] && [ -r "$SCRIPT_DIR/../desktop/electron-lib.sh" ]; then
  . "$SCRIPT_DIR/../desktop/electron-lib.sh"; YMIR_ELECTRON_LIB_LOADED=1
fi
# Graphics (P8): the DRM truth and the effective GPU policy. A host with a
# display but NO DRM card cannot render at all — that is a named failure, not
# a green row. On a headless box nothing renders anyway: healthy.
s_graphics() {
  if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then return 0; fi
  graphics_block --json 2>/dev/null | grep -qF '"cards":[{' || return 1
  return 0
}
f_graphics() {
  printf 'eir: a display is up but no DRM card is sensed — inspect the driver (bin/host/omarchy-sense.sh observe) and the kernel log\n' >&2
  return 1
}
if [ -z "${YMIR_GRAPHICS_LIB_LOADED:-}" ] && [ -r "$SCRIPT_DIR/../host/graphics-lib.sh" ]; then
  . "$SCRIPT_DIR/../host/graphics-lib.sh"; YMIR_GRAPHICS_LIB_LOADED=1
fi

# The well: the door answers AND the store is whole (Rule 20). A memory that
# shrank is a loss even while the bridge still serves — so the ward rides this
# surface, and the mend re-checks before rolling the checkpoint forward.
well_detail() {
  if { exec 3<>/dev/tcp/127.0.0.1/4602; } 2>/dev/null; then
    exec 3>&-
    printf 'engram :4602 answering\n'
  else
    printf 'door silent on :4602%s\n' "${ROLE:+ (role $ROLE: the well is the heart door)}"
  fi
}

s_well()      {
  # HONESTY (2026-10-21): this used to answer `ok` from the presence of two
  # scripts, never from the well itself — a green row while nothing listened on
  # :4602. Ask the port.
  { exec 3<>/dev/tcp/127.0.0.1/4602; } 2>/dev/null && { exec 3>&-; return 0; }
  return 1
}
f_well()      { "$SCRIPT_DIR/../records/mimir.sh" start >/dev/null 2>&1; "$SCRIPT_DIR/../records/well-guard.sh" record >/dev/null 2>&1; }

# MEMORY — the well's PRACTICE, not just its port (plan 136). `well` asks whether
# someone is listening; `memory` asks whether there is anything worth listening to:
# how big the store is, when it was last watered, last drunk from, last written as
# a day, and last pruned. A well that answers and is never fed is green on `well`
# and useless to the Allfather, which is exactly the failure this surface names.
# The measuring lives in bin/records/mimir.sh memory (one door, stdlib only), so a
# broken bridge still yields a report rather than a blank row.
memory_detail() {
  local out
  out="$("$SCRIPT_DIR/../records/mimir.sh" memory --line 2>/dev/null)"
  [ -n "$out" ] || { printf 'the memory door did not answer — bin/records/mimir.sh memory\n'; return 1; }
  printf '%s\n' "$out"
}
s_memory()    { "$SCRIPT_DIR/../records/mimir.sh" memory --check >/dev/null 2>&1; }
f_memory()    {
  # The mends are: raise the well, then let the grading pass run (it only annotates
  # and moves; it never lowers the count). A stale DAILY record is not something a
  # healer can write honestly — the row keeps saying so.
  "$SCRIPT_DIR/../records/mimir.sh" start >/dev/null 2>&1
  "$SCRIPT_DIR/../records/mimir.sh" grade --apply >/dev/null 2>&1
}
# MCP: the well door + the mesh wired into every harness present.
s_mcp() {
  local pi="$HOME/.pi/agent/mcp-adapter.json" oc="$ROOT/opencode.json"
  # The live MCP surfaces: the OpenCode config must bind the WELL DOOR (the gateway's
  # /mcp/well — engram is Kaia's engine only, 2026-11-10, and a direct engram server is a
  # leak that never reaches the heart), and the Pi config must parse and carry the fleet
  # servers. If the A2A mesh engine (a2abridge) is seated, its bridge must be wired too —
  # a seated engine with no bridge is the silent half; the deeper connection proof lives
  # in smoke_test.sh (2026-09-23). The other harnesses are read by the seating door.
  [ -f "$pi" ] || [ -f "$oc" ] || return 1
  if [ -f "$oc" ]; then grep -q '/mcp/well' "$oc" 2>/dev/null || return 1; fi
  if [ -x "$SCRIPT_DIR/../bridge/mcp-config.sh" ]; then
    "$SCRIPT_DIR/../bridge/mcp-config.sh" seat --check 2>/dev/null | grep -q 'direct engram' && return 1
  fi
  if [ -f "$pi" ]; then
    grep -q '"mcpServers"' "$pi" 2>/dev/null || return 1
    command -v python3 >/dev/null 2>&1 && ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$pi" 2>/dev/null && return 1
    if [ -x "$HOME/.a2abridge/bin/a2abridge" ]; then
      grep -q '"a2abridge"' "$pi" 2>/dev/null || return 1
    fi
  fi
  return 0
}
f_mcp()       {
  [ -x "$SCRIPT_DIR/../bridge/a2a-mcp.sh" ] && "$SCRIPT_DIR/../bridge/a2a-mcp.sh" install >/dev/null 2>&1
  [ -x "$SCRIPT_DIR/../bridge/mcp-config.sh" ] && "$SCRIPT_DIR/../bridge/mcp-config.sh" seat >/dev/null 2>&1
}
# Harness: the Pi extensions are DEPLOYED away from this tree, so a copy cannot
# find bin/ by walking up — it reads the root recorded beside it (`.ymir-root`,
# written by bin/seat/valknut-load.sh, resolved by .pi/extensions/lib/ymir-home.ts).
# A record with no live root means every `${root}/bin/…` they exec is a path that
# does not exist: the Gná arm child dies at 127 before its first poll, no
# state/.watch.heartbeat is ever written, and the watch is dead while every file
# listing looks correct. Absent extensions are healthy — nothing to resolve.
PI_EXT_HOME="${PI_EXT_HOME:-$HOME/.pi/agent/extensions}"
s_harness() {
  [ -d "$PI_EXT_HOME" ] || return 0
  [ -n "$(ls "$PI_EXT_HOME"/*.ts 2>/dev/null)" ] || return 0
  [ -r "$PI_EXT_HOME/.ymir-root" ] || return 1
  local line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    [ -x "$line/bin/pi/syn-watch-arm.sh" ] && return 0
  done <"$PI_EXT_HOME/.ymir-root"
  return 1
}
f_harness()   { [ -x "$SCRIPT_DIR/../seat/valknut-load.sh" ] && "$SCRIPT_DIR/../seat/valknut-load.sh" --pi >/dev/null 2>&1 && s_harness; }
# The pi door must be what `pi` resolves to (2026-11-12): a hand-started pi that bypasses it loads two
# extension homes and refuses all of them. A host with no pi is healthy. Eir mends it by seating the
# installer's PATH block (the operator's shell picks it up at its next login).
_pidoor_dst() { printf '%s' "${YMIR_PI_DOOR:-$HOME/.pi/agent/bin/pi}"; }
s_pidoor() {
  command -v pi >/dev/null 2>&1 || return 0
  local got want; got="$(command -v pi)"; want="$(_pidoor_dst)"
  [ -x "$want" ] && [ "$got" = "$want" ]
}
pidoor_detail() {
  command -v pi >/dev/null 2>&1 || { printf 'no pi on this host'; return 0; }
  local got want; got="$(command -v pi)"; want="$(_pidoor_dst)"
  if [ "$got" = "$want" ] && [ -x "$want" ]; then printf 'pi resolves to the one-home door (%s)' "$want"
  else printf '`pi` resolves to %s, not the door %s — bin/seat/harness-extensions-install.sh seats the PATH block (YMIR_PI_DOOR_PATH=print shows it)' "$got" "$want"; fi
}
f_pidoor() { [ -x "$SCRIPT_DIR/../seat/harness-extensions-install.sh" ] && "$SCRIPT_DIR/../seat/harness-extensions-install.sh" >/dev/null 2>&1; s_pidoor; }
# Claude hooks (2026-11-10): every Claude seat in the fleet carries THREE user-scope hooks, seated
# by bin/seat/harness-extensions-install.sh — the AGENTS.md loader (Claude reads CLAUDE.md, never
# a project's AGENTS.md), the Eindri-only PreToolUse (Claude must never spawn its own subagents),
# and the global Gná arm (a seat in any project takes a wake). A host with no Claude is healthy:
# nothing to wire. A Claude present with a stale or absent entry is a NAMED failure.
s_claudehooks() {
  command -v claude >/dev/null 2>&1 || return 0
  [ -x "$SCRIPT_DIR/../seat/harness-extensions-install.sh" ] || return 1
  local out
  out="$("$SCRIPT_DIR/../seat/harness-extensions-install.sh" --check 2>/dev/null)" || true
  ! printf '%s\n' "$out" | grep -q '"claude-[^"]*","stale"'
}
# The detail names the rows the installer's own --check calls stale (it used to print a fixed
# sentence whatever the state, so a red row never said what was red).
claudehooks_detail() {
  command -v claude >/dev/null 2>&1 || { printf 'no claude on this host'; return 0; }
  local door="$SCRIPT_DIR/../seat/harness-extensions-install.sh" out stale
  [ -x "$door" ] || { printf 'the installer is missing (bin/seat/harness-extensions-install.sh)'; return 0; }
  out="$("$door" --check 2>/dev/null)" || true
  stale="$(printf '%s\n' "$out" | awk -F'","' '/"claude-[^"]*","stale"/{gsub(/^ *"/,"",$1); printf "%s%s", (n++?", ":""), $1}')"
  if [ -n "$stale" ]; then
    printf 'stale: %s — bin/seat/harness-extensions-install.sh (a pinned runtime that lags origin is the usual cause: bin/seat/armpin.sh)' "$stale"
  else
    printf 'the Claude hooks: AGENTS.md · Eindri-only · NDA-write (the global Gná arm is opt-in)'
  fi
}
f_claudehooks() { [ -x "$SCRIPT_DIR/../seat/harness-extensions-install.sh" ] && "$SCRIPT_DIR/../seat/harness-extensions-install.sh" >/dev/null 2>&1 && s_claudehooks; }
# OpenCode launch shape (plan 262): OpenCode v2's interactive TUI takes --prompt and --auto but not --model,
# and a release that drops either flag kills every OpenCode worker in its pane. The surface reads
# `opencode --help` through the launcher's own check, so a drifted TUI is a red surface, not a dead
# pane. A host with no OpenCode owes nothing.
s_opencode() {
  command -v opencode >/dev/null 2>&1 || return 0
  [ -x "$SCRIPT_DIR/../seat/opencode-launcher.sh" ] || return 1
  "$SCRIPT_DIR/../seat/opencode-launcher.sh" check >/dev/null 2>&1
}
f_opencode() { s_opencode; }   # nothing here can mend an upstream flag: the finding names it for the Allfather
# Arm: Sýn as a SERVICE (plan 58, Phase 2) — one standing watcher per home that
# idles when no session is seated, never retires with one. The surface is the
# arm's own door (bin/pi/syn-watch.sh): a live lease with a fresh heartbeat is
# healthy whether a session is up (state=up) or none is (state=idle). A missing
# or stale arm is a NAMED failure — command merges and a blind turn end are what
# a dead watch costs — and the mend is to seat the service again.
s_arm()      { [ -x "$SCRIPT_DIR/../pi/syn-watch.sh" ] && "$SCRIPT_DIR/../pi/syn-watch.sh" status >/dev/null 2>&1; }
f_arm()      { [ -x "$SCRIPT_DIR/../pi/syn-watch.sh" ] && "$SCRIPT_DIR/../pi/syn-watch.sh" start >/dev/null 2>&1 && s_arm; }
# armpin (plan 257 H8): the pinned runtime is current with origin, and every surface that
# supervises — the arm service, its clients, Rödd's window and her tool server — executes
# from it. bin/seat/armpin.sh is the judge; the mend moves the pin (runtime-deploy.sh),
# which restarts and proves the units, then the judge is asked again.
s_armpin()   { [ -x "$SCRIPT_DIR/../seat/armpin.sh" ] && "$SCRIPT_DIR/../seat/armpin.sh" check >/dev/null 2>&1; }
f_armpin()   { [ -x "$SCRIPT_DIR/../engine/runtime-deploy.sh" ] && "$SCRIPT_DIR/../engine/runtime-deploy.sh" >/dev/null 2>&1; s_armpin; }
# runtimepin (plan 269): EVERY Ymir systemd unit and desktop launcher on this machine runs from the pinned
# runtime and is in the one register (config/units.yaml). armpin judges the pin's age and the arm; this
# judges the whole fleet of units — one in a working tree is the fault the pre-push ward `runtime-pinned`
# refused a collaborator's push for. The mend is the one writer: bin/engine/units.sh write.
s_runtimepin() { [ -x "$SCRIPT_DIR/../engine/units.sh" ] && "$SCRIPT_DIR/../engine/units.sh" check >/dev/null 2>&1; }
f_runtimepin() {
  [ -x "$SCRIPT_DIR/../engine/runtime-seat.sh" ] || return 1
  "$SCRIPT_DIR/../engine/runtime-seat.sh" >/dev/null 2>&1
  s_runtimepin
}
# roddhelm: the lease names a known holder role, the room is writable, and the
# drain door answers (plan 254 B6). The check is rodd-helm.sh --check; there is
# no safe auto-mend — a role is the holder's declaration, never invented.
s_roddhelm() { [ -x "$SCRIPT_DIR/../voice/rodd-helm.sh" ] && "$SCRIPT_DIR/../voice/rodd-helm.sh" --check >/dev/null 2>&1; }
f_roddhelm() { s_roddhelm; }
# Lock: absent, or held by a live pid.
s_lock() {
  local f="$STATE/.lock" pid
  [ -r "$f" ] || return 0
  pid="$(tr -d '[:space:]' <"$f" 2>/dev/null || true)"
  [ -n "$pid" ] || return 0
  kill -0 "$pid" 2>/dev/null
}
f_lock() {
  local f="$STATE/.lock" pid
  if [ -r "$f" ]; then
    pid="$(tr -d '[:space:]' <"$f" 2>/dev/null || true)"
    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$f" "$STATE/.lock-path"
      # A stale arm marker with no live session would silence the turn-end guard.
      rm -f "$STATE/.supervision-armed" "$STATE/.watch.heartbeat"
    fi
  fi
}
s_migrations(){ [ ! -x "$SCRIPT_DIR/../engine/ymir-migrate.sh" ] || "$SCRIPT_DIR/../engine/ymir-migrate.sh" status >/dev/null 2>&1; }

# Gates: the delivery hook that is INSTALLED, not the installer that is right.
# `fixes-guard.sh --install` was fixed on 2026-10-20 to judge the PUSHING worktree
# (`git rev-parse --show-toplevel`) instead of the checkout that installed it — but
# the hook already seated on this machine kept the old shape, so for four days every
# push from a Yggdrasil worktree was judged against the main tree, and a branch that
# had regenerated its register was still refused (measured 2026-10-24). A mend that
# is not re-seated is not a mend: this surface checks the artifact, not the script.
_gates_hook() {  # <result-var> — the installed pre-push hook's path
  local hooks
  hooks="$(cd "$ROOT" 2>/dev/null && git rev-parse --git-path hooks 2>/dev/null)" || return 1
  [ -n "$hooks" ] || return 1
  case "$hooks" in /*) ;; *) hooks="$ROOT/$hooks" ;; esac
  printf -v "${1:?}" '%s' "$hooks/pre-push"
}
s_gates() {
  local h
  _gates_hook h || return 1
  [ -x "$h" ] || return 1
  grep -q 'git rev-parse --show-toplevel' "$h" 2>/dev/null || return 1
  grep -q 'branch-current.sh' "$h" 2>/dev/null || return 1
}
f_gates() {
  _gates_hook h >/dev/null 2>&1 || true
  bash "$SCRIPT_DIR/../gates/guards/fixes-guard.sh" --install >/dev/null 2>&1 || return 1
  s_gates
}
f_migrations(){ [ -x "$SCRIPT_DIR/../engine/ymir-migrate.sh" ] && "$SCRIPT_DIR/../engine/ymir-migrate.sh" apply >/dev/null 2>&1; }
# Hoard: private data sits under the hoard, and .ymir-layout.yaml tells the truth.
# Two failures this catches: (1) a declared layout path that does not exist — a
# stale map is what lets private work land outside the hoard; (2) a flat
# $YMIR_HOME/{identity,data,docs,secrets,tenants} duplicate beside hodd/ — the
# drift that RULES/04-hoard.md (correction 2026-09-17) forbids.
_hoard_root() { local r; if [ -x "$SCRIPT_DIR/../vault/hoard-lib.sh" ]; then . "$SCRIPT_DIR/../vault/hoard-lib.sh"; hoard_root r; printf '%s' "$r"; else printf '%s' "${YMIR_HOARD:-$YMIR_HOME/hodd}"; fi; }
s_hoard() {
  local h; h="$(_hoard_root)"
  [ -d "$h" ] || return 1
    local lay="$YMIR_HOME/.ymir-layout.yaml" k p rp maproot
    if [ -f "$lay" ]; then
      # A path naming the SAME home under another root is not foreign: a substrate
      # THE MAP MUST DESCRIBE *THIS* MACHINE. The previous code RETRIED a foreign path
      # under this root, which made a map naming another computer pass as 'ok' —
      # masking the very fault this surface exists to catch (measured 2026-10-13:
      # .ymir-layout.yaml pointed at an absolute per-user home for every path, and this
      # surface still reported 'ok'). A foreign map is now a FAILURE.
      maproot="$(sed -nE 's/^git_repo: "([^"]+)".*/\1/p' "$lay" 2>/dev/null | head -1)"
      if [ -n "$maproot" ] && [ "$maproot" != "$YMIR_HOME" ]; then
        return 1   # the map names another machine's home — regenerate it on this one
      fi
      for k in config secrets identity workspaces memory smidja state data; do
        p="$(sed -nE "s/^  $k: \"([^\"]+)\".*/\1/p" "$lay" | head -1)"
        [ -n "$p" ] || continue
        if [ "${p#/}" != "$p" ]; then [ -d "$p" ] || return 1
        else [ -d "$YMIR_HOME/$p" ] || return 1; fi
      done
    fi
  # STATE LIVES IN THE HOME AND NOWHERE ELSE (Rule 21). Two faults measured 2026-10-13:
  # state beside the home (~/Documents/Ymir/state) and state INSIDE the public repo
  # (ymir/.agents/state, ymir/bin/state — git-ignored, so no guard could see it either).
  [ -d "$YMIR_HOME/state" ] || return 1
  local baddir
  for baddir in "$HOME/Documents/Ymir" "$HOME/hodd"; do  # allow-home-default: names the LEGACY drift paths on purpose (Rule 21)
    [ -e "$baddir" ] && return 1
  done
  if [ -n "${ROOT:-}" ]; then
    for baddir in "$ROOT/.agents/state" "$ROOT/bin/state"; do
      # An EMPTY leftover holds no state (the 0008 migration rmdirs what it emptied); only a
      # directory with something in it is state in the repo. f_hoard removes the empty one.
      [ -e "$baddir" ] || continue
      [ -d "$baddir" ] && [ -z "$(ls -A "$baddir" 2>/dev/null)" ] && continue
      return 1
    done
  fi
  # A COMPANY OR PROJECT DOCUMENT MUST NOT SIT IN THE OPERATOR'S OWN SHELF (Rule 21):
  # hodd/life is the operator's own, never a company's or a project's.
  local life="$YMIR_HOME/hodd/life"
  if [ -d "$life" ]; then
    [ -d "$life/work" ] && return 1
    local cid
    for cid in "$YMIR_HOME"/hodd/identity/companies/*/; do
      [ -d "$cid" ] || continue
      cid="$(basename "$cid")"
      [ "$cid" = '*' ] && continue
      find "$life" -maxdepth 3 -iname "*$cid*" -print -quit 2>/dev/null | grep -q . && return 1
    done
  fi
  for k in identity data docs secrets tenants; do
    [ -d "$YMIR_HOME/$k" ] && return 1
  done
  # A session-lock pointer that names another machine's home is stale drift: the
  # lock is machine-local, but the pointer lives in the synced home, so a box
  # reinstalled under a new username inherits the old one. The arm then tries to
  # mkdir a foreign home and fails with EACCES, stranding supervision (2026-09-23).
  local lp="$YMIR_HOME/state/.lock-path" rec
  if [ -f "$lp" ]; then
    rec="$(head -n1 "$lp" 2>/dev/null | tr -d '[:space:]')"
    if [ -n "$rec" ] && [ -n "${HOME:-}" ] && [ "$rec" != "$HOME" ] && [ "${rec#"$HOME"/}" = "$rec" ]; then
      return 1
    fi
  fi
  return 0
}
f_hoard() {
  local h; h="$(_hoard_root)"
  mkdir -p "$h" 2>/dev/null || return 1
  # A flat duplicate beside hodd/ is the drift: merge it in, never clobber.
  local k
  for k in identity data docs secrets tenants; do
    local src="$YMIR_HOME/$k"
    [ -d "$src" ] || continue
    mkdir -p "$h/$k" 2>/dev/null || continue
    cp -an "$src/." "$h/$k/" 2>/dev/null || true
    rm -rf "$src" 2>/dev/null || true
  done
    # A layout entry naming a nonexistent dir is repointed at the hoard.
    local lay="$YMIR_HOME/.ymir-layout.yaml" k2 p rp maproot
    if [ -f "$lay" ] && [ -d "$h" ]; then
      maproot="$(sed -nE 's/^git_repo: "([^"]+)".*/\1/p' "$lay" 2>/dev/null | head -1)"
      for k2 in identity data secrets docs tenants; do
        p="$(sed -nE "s/^  $k2: \"([^\"]+)\".*/\1/p" "$lay" | head -1)"
        [ -n "$p" ] || continue
        rp="$p"
        if [ ! -d "$rp" ] && [ -n "$maproot" ] && [ "${p#"$maproot"}" != "$p" ]; then
          rp="$YMIR_HOME/${p#"$maproot"/}"
        fi
        # Resolves under this root, or under a container's view of the same home:
        # nothing to repoint.
        if [ -d "$rp" ]; then continue; fi
        if [ "${p#/}" = "$p" ] && [ -d "$YMIR_HOME/$p" ]; then continue; fi
        sed -i "s|^  $k2: .*|  $k2: \"$h/$k2\"|" "$lay"
      done
    fi
  # An empty state directory inside the repo tree is a leftover shell, never state: remove it.
  local sd
  for sd in "$ROOT/.agents/state" "$ROOT/bin/state"; do
    [ -d "$sd" ] && rmdir "$sd" 2>/dev/null || true
  done
  # A stale session-lock pointer (see s_hoard) is repointed at this machine.
  local lp="$YMIR_HOME/state/.lock-path" rec want
  if [ -f "$lp" ]; then
    rec="$(head -n1 "$lp" 2>/dev/null | tr -d '[:space:]')"
    if [ -n "$rec" ] && [ -n "${HOME:-}" ] && [ "$rec" != "$HOME" ] && [ "${rec#"$HOME"/}" = "$rec" ]; then
      want="${BROKK_MACHINE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir}/brokk.lock"
      printf '%s\n' "$want" >"$lp" 2>/dev/null || true
    fi
  fi
  s_hoard
}

# Each branch PRINTS the command that produces the fact; the caller evaluates it
# (the branches used to be bare command text, which is a command-not-found — a
# single quoted word, not a command — so every row's detail came out EMPTY, and
# the `arm` surface is the one the plan's proof asks to NAME the arm, 2026-09-27).
detail() { # <name> -> the command that prints one short fact
  case "$1" in
    floors)    printf '%s\n' "[ -x $SCRIPT_DIR/../engine/prereq-ensure.sh ] && echo 'tool floors'" ;;
    herdr)     printf '%s\n' "have herdr && herdr --version 2>/dev/null | head -1 || { have tmux && tmux -V | sed 's/^/tmux fallback: /' || echo 'no pane backend'; }" ;;
    a2abridge) printf '%s\n' a2abridge_detail ;;
    unitdrift) printf '%s\n' "unitdrift_detail | grep . || echo 'every installed unit runs what its source says'" ;;
    voice)     printf '%s\n' "door_reason $SCRIPT_DIR/../voice/voice-ensure.sh status" ;;
    hnoss)     printf '%s\n' "door_reason $SCRIPT_DIR/../pi/hnoss-ensure.sh status" ;;
    snotra)    printf '%s\n' "door_reason $SCRIPT_DIR/../../systems/snotra/services/ear/snotra-ensure.sh status" ;;
    council)   printf '%s\n' "door_reason $SCRIPT_DIR/../pi/logretta-ensure.sh status" ;;
    vault)     printf '%s\n' "door_reason $SCRIPT_DIR/../vault/hnitbjorg-ensure.sh status" ;;
    ward)      printf '%s\n' "door_reason $SCRIPT_DIR/../ward/security-audit.sh check" ;;
    hermes)    printf '%s\n' "have hermes && echo present || echo absent" ;;
    sessrumnir)printf '%s\n' "[ -d $APP_SESSRUMNIR/out ] && echo built || echo 'not built'" ;;
    bilskirnir)printf '%s\n' "[ -x $ROOT/apps/bilskirnir/setup.sh ] && { $ROOT/apps/bilskirnir/setup.sh --check 2>&1 | tail -1; } || echo 'not in this tree'" ;;
    well)      printf '%s\n' well_detail ;;
    memory)    printf '%s\n' memory_detail ;;
    mail)      printf '%s\n' mail_detail ;;
    models)    printf '%s\n' models_detail ;;
    mcp)       printf '%s\n' "echo 'a2abridge + the well door'" ;;
    graphics)  printf '%s\n' "if [ -z \"\${DISPLAY:-}\${WAYLAND_DISPLAY:-}\" ]; then echo headless; else echo \"\$(graphics_block 2>/dev/null | sed -n '1p' | sed 's/.*{//;s/}//') · \$(graphics_policy 2>/dev/null)\"; fi" ;;
    harness)   printf '%s\n' "s_harness && echo 'deployed extensions resolve their bin/' || echo 'no live root recorded'" ;;
    pidoor) printf '%s\n' pidoor_detail ;;
    claudehooks) printf '%s\n' claudehooks_detail ;;
    opencode)  printf '%s\n' "command -v opencode >/dev/null 2>&1 && $SCRIPT_DIR/../seat/opencode-launcher.sh check 2>&1 | sed -n '2p' | sed -E 's/^ *\"[a-z]+\",//; s/\"//g' || echo 'no opencode on this host'" ;;
    arm)       printf '%s\n' "$SCRIPT_DIR/../pi/syn-watch.sh status --detail 2>/dev/null | head -1 || echo 'arm door missing'" ;;
    armpin)    printf '%s\n' "$SCRIPT_DIR/../seat/armpin.sh --detail 2>/dev/null | head -1 || echo 'armpin door missing'" ;;
    runtimepin) printf '%s\n' "$SCRIPT_DIR/../engine/units.sh check 2>&1 | grep -E 'OFF-PIN|UNREGISTERED|ABSENT' | head -2 | tr -d '\"' | paste -sd';' - | grep . || echo 'every unit and launcher is on the pin'" ;;
    roddhelm)  printf '%s\n' "$SCRIPT_DIR/../voice/rodd-helm.sh --check 2>&1 | head -1 || echo 'rodd-helm door missing'" ;;
    gates)     printf '%s\n' "s_gates && echo 'pre-push hook: the worktree that pushes' || echo 'installed hook is stale — bin/gates/guards/fixes-guard.sh --install'" ;;
    lock)      printf '%s\n' "cat $STATE/.lock 2>/dev/null | tr -d '[:space:]' | sed 's/^/pid /' || echo none" ;;
    migrations)printf '%s\n' "echo 'structure'" ;;
    shells)    printf '%s\n' 'shell_surfaces | while IFS= read -r s; do d=""; app_dir "$s" d 2>/dev/null || d=""; [ -n "$d" ] && printf "%s %s; " "$s" "$(electron_runtime_state "$d" "$ROOT" "$(app_pkg "$s")" 2>/dev/null)"; done' ;;
    hoard)     printf '%s\n' "printf 'hoard %s' \"\$(_hoard_root)\" ; [ -d \"\$YMIR_HOME/identity\" ] && printf ' +flat-duplicate' ; printf '\n'" ;;
    autoboot)  printf '%s\n' "$SCRIPT_DIR/../engine/ymir-autoboot.sh verify >/dev/null 2>&1 && echo 'boot proven' || echo 'boot gap — bin/engine/ymir-autoboot.sh verify'" ;;
    seatpaths) printf '%s\n' "printf '%s' \"$(seat_profile)\" ; grep -qF \"$HOME/.bun/bin\" \"$(seat_profile)\" 2>/dev/null && printf ' carries the marked block' || printf ' does not carry ~/.bun/bin — a unit or validator will not find bun'" ;;
    hooks)     printf '%s\n' "printf 'installed hooks' ; _hk=\"$(cd "$ROOT" && git rev-parse --git-path hooks 2>/dev/null || printf '.git/hooks')\"; case \"\$_hk\" in /*) ;; *) _hk=\"$ROOT/\$_hk\" ;; esac; [ -x \"\$_hk/pre-commit\" ] && printf ' present' || printf ' MISSING — a guarded deletion and a staged secret would both pass'" ;;
    seats)     printf '%s\n' seats_detail ;;
    seatreap)  printf '%s\n' "printf 'a finished-idle seat kept past a day' ; for f in $STATE/.*.idle-since $ROOT/state/.*.idle-since; do [ -f \$f ] && echo \$(basename \$f); done" ;;
    packaging) printf '%s\n' "bash \"$SCRIPT_DIR/../gates/guards/packaging-guard.sh\" check 2>&1 | grep -o 'the File directive names a file that does not exist: [^)]*' | head -1 || printf 'every named input exists'" ;;
  esac
}

# A healthy row whose detail would be a door's first complaint says plainly that it is healthy instead.
ok_text() {
  case "$1" in
    voice)   printf 'the voice engines and the face answer' ;;
    hnoss)   printf 'the design door is seated' ;;
    snotra)  printf 'the meeting ear has an engine' ;;
    council) printf 'the council roster stands' ;;
    vault)   printf 'the vault tooling stands (a sealed vault is healthy)' ;;
    ward)    printf 'no door above the floor' ;;
  esac
}

broken=0
unconfigured=0
OWED=""   # surface<TAB>risk, one per line: broken, and not mended by this run
if [ "$ACTION" = "fix" ]; then
  for s in "${SURFACES[@]}"; do
    if [ -n "$FIX_ONLY" ]; then case " $FIX_ONLY " in *" $s "*) ;; *) continue ;; esac; fi
    surface_skip "$s" && continue
    declare -F "s_$s" >/dev/null || continue
    "s_$s" >/dev/null 2>&1 && continue
    risk="$(surface_risk "$s")"
    # --safe (Gróa's road, plan 278): only a `safe` mend runs unattended. A named surface is the operator
    # asking for that one, so it is mended whatever its class — except `never`, which no door can mend.
    if [ "$risk" = never ] || { [ "$FIX_SAFE" = 1 ] && [ "$risk" != safe ]; }; then
      printf 'eir: owed %s (%s) — bin/agents/eir-doctor.sh fix %s\n' "$s" "$risk" "$s"
      continue
    fi
    if declare -F "f_$s" >/dev/null && "f_$s" >/dev/null 2>&1 && "s_$s" >/dev/null 2>&1; then
      printf 'eir: mended %s\n' "$s"
      # Every mend is a Runes entry (operational law 3); the line carries the surface and the class.
      [ "${YMIR_EIR_TEST:-}" = 1 ] || { [ -x "$SCRIPT_DIR/../records/runes-append.sh" ] && \
        "$SCRIPT_DIR/../records/runes-append.sh" eir mend --message "eir mended surface $s (risk $risk)" >/dev/null 2>&1; } || true
    else
      printf 'eir: could not mend %s (%s) — bin/agents/eir-doctor.sh fix %s, then read its row\n' "$s" "$risk" "$s" >&2
    fi
  done
fi

rows=""
count=0
for s in "${SURFACES[@]}"; do
  if surface_skip "$s"; then
    state=skip
    d="$(surface_detail_skip "$s")"
    rows="${rows}  \"${s}\",\"${state}\",\"${d}\"\n"
    count=$((count+1))
    continue
  fi
  # A surface may NAME its own state where a yes/no would be a lie (the mail desk:
  # answering with no account is not healthy, and it is not broken either).
  named=""
  case "$s" in mail) named="$(mail_state)" ;; esac
  if [ -n "$named" ]; then
    state="$named"
    case "$state" in
      # `mail` speaks three words, and one of them is `ok`. The catch-all below counted a HEALTHY
      # desk as broken — measured 2026-11-10: every surface said ok, and the header said "broken 1".
      ok)           : ;;
      unconfigured) unconfigured=$((unconfigured+1)) ;;
      *)            broken=$((broken+1)) ;;
    esac
  elif ! declare -F "s_$s" >/dev/null; then state=broken; broken=$((broken+1)); d_override="the register names this surface but Eir has no check for it (s_$s)"
  elif "s_$s" >/dev/null 2>&1; then state=ok
  elif surface_ok "$s"; then state=ok; d_override="tmux fallback"
  else state=broken; broken=$((broken+1)); fi
  if [ "$state" = ok ] && [ -n "$(ok_text "$s")" ]; then d="$(ok_text "$s")"
  else d="$(eval "$("detail" "$s" 2>/dev/null)" 2>/dev/null | head -1)"; fi
  [ -n "${d_override:-}" ] && { d="$d_override"; d_override=""; }
  # A broken row ALWAYS carries a reason and the command (plan 278, problem 10): `voice` and `hnoss`
  # printed an empty detail, which told the operator nothing.
  if [ "$state" = broken ]; then
    [ -n "$d" ] || d="the check gave no reason — bin/agents/eir-doctor.sh fix $s"
    d="$(printf '%s' "$d" | tr -d '"')"
    OWED="${OWED}${s}	$(surface_risk "$s")
"
  fi
  rows="${rows}  \"${s}\",\"${state}\",\"${d}\"\n"
  count=$((count+1))
done

printf 'eir[1]{action,root,broken}:\n  "%s","%s",%s\n' "$ACTION" "$ROOT" "$broken"
printf 'health[%d]{surface,state,detail}:\n' "$count"
printf '%b' "$rows"
# For the eye, on stderr: marks and colour; for the pipe, the TOON above.
if [ -t 2 ]; then
  printf '\n' >&2
  while IFS='|' read -r surface state detail; do
    [ -n "$surface" ] || continue
    style_line "$state" "$surface" "$detail"
  done <<<"$(printf '%b' "$rows" | sed 's/^  //; s/"//g; s/,/|/; s/,/|/')"
fi
if [ "$broken" != 0 ] || [ "$unconfigured" != 0 ]; then
  # One line per broken surface with its risk class, so Gróa and the operator read the same owed list
  # (plan 278). Machine-clean: `owed: <surface> <risk>`.
  printf '%s' "$OWED" | while IFS=$'\t' read -r _s _r; do [ -n "$_s" ] && printf 'owed: %s %s\n' "$_s" "$_r"; done
  [ "$broken" != 0 ] && printf 'eir: %s surface(s) need mending — run: bin/agents/eir-doctor.sh fix\n' "$broken"
  [ "$unconfigured" != 0 ] && printf 'eir: %s surface(s) are unconfigured — a name must be DECLARED, never mended\n' "$unconfigured"
  exit 1
fi
exit 0

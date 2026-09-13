#!/usr/bin/env bash
# eir-doctor.sh — Eir, the healer: diagnose the running system, then mend it.
#
# Eir composes the surfaces that already own their health — she does not
# re-implement them. `check` (default) reports each surface; `fix` runs the
# matching repair path for the broken ones. She never arms supervision (the
# harness extension owns that) and never touches a tracked tree.
#
# Usage:
#   eir-doctor.sh [check]      # diagnose every surface, aggregate TOON
#   eir-doctor.sh fix          # mend what can be mended safely, then re-check
#   eir-doctor.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE="${BROKK_STATE_OVERRIDE:-$ROOT/state}"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-check}"; shift || true

have() { command -v "$1" >/dev/null 2>&1; }
say_ok() { return 0; }

# Each surface: `s_<name>` = healthy? (exit 0), `f_<name>` = the repair.
SURFACES=(floors herdr a2abridge hermes sessrumnir well mcp lock migrations)

s_floors()    { [ -x "$SCRIPT_DIR/prereq-ensure.sh" ] && "$SCRIPT_DIR/prereq-ensure.sh" status >/dev/null 2>&1; }
f_floors()    { "$SCRIPT_DIR/prereq-ensure.sh" ensure --install >/dev/null 2>&1; }
s_herdr()     { [ -x "$SCRIPT_DIR/herdr-ensure.sh" ] && "$SCRIPT_DIR/herdr-ensure.sh" status >/dev/null 2>&1; }
f_herdr()     { "$SCRIPT_DIR/herdr-ensure.sh" ensure --install >/dev/null 2>&1; }
s_a2abridge() { [ -x "$SCRIPT_DIR/a2abridge-ensure.sh" ] && "$SCRIPT_DIR/a2abridge-ensure.sh" status >/dev/null 2>&1; }
f_a2abridge() { "$SCRIPT_DIR/a2abridge-ensure.sh" ensure --install >/dev/null 2>&1; }
s_hermes()    { [ -x "$SCRIPT_DIR/hermes-ensure.sh" ] && "$SCRIPT_DIR/hermes-ensure.sh" status >/dev/null 2>&1; }
f_hermes()    { "$SCRIPT_DIR/hermes-ensure.sh" ensure --install >/dev/null 2>&1; }
s_sessrumnir(){ [ -x "$SCRIPT_DIR/sessrumnir-ensure.sh" ] && "$SCRIPT_DIR/sessrumnir-ensure.sh" status >/dev/null 2>&1; }
f_sessrumnir(){ "$SCRIPT_DIR/sessrumnir-ensure.sh" ensure --install >/dev/null 2>&1; }
s_well()      { [ -x "$SCRIPT_DIR/mimir.sh" ] && "$SCRIPT_DIR/mimir.sh" health >/dev/null 2>&1; }
f_well()      { "$SCRIPT_DIR/mimir.sh" start >/dev/null 2>&1; }
# MCP: both A2A servers wired into opencode + pi.
s_mcp() {
  local pi="$HOME/.pi/agent/mcp.json" oc="$ROOT/opencode.json"
  [ -f "$oc" ] || return 1
  grep -q '"engram"' "$oc" 2>/dev/null && grep -q '"a2abridge"' "$oc" 2>/dev/null || return 1
  if [ -f "$pi" ]; then grep -q '"a2abridge"' "$pi" 2>/dev/null || return 1; fi
  return 0
}
f_mcp()       { [ -x "$SCRIPT_DIR/a2a-mcp.sh" ] && "$SCRIPT_DIR/a2a-mcp.sh" install >/dev/null 2>&1; }
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
s_migrations(){ [ ! -x "$SCRIPT_DIR/ymir-migrate.sh" ] || "$SCRIPT_DIR/ymir-migrate.sh" status >/dev/null 2>&1; }
f_migrations(){ [ -x "$SCRIPT_DIR/ymir-migrate.sh" ] && "$SCRIPT_DIR/ymir-migrate.sh" apply >/dev/null 2>&1; }

detail() { # <name> -> one short fact
  case "$1" in
    floors)    "[ -x $SCRIPT_DIR/prereq-ensure.sh ] && echo tool floors" ;;
    herdr)     "have herdr && herdr --version 2>/dev/null | head -1 || echo 'herdr absent'" ;;
    a2abridge) "have a2abridge && a2abridge --version 2>/dev/null | head -1 || echo 'engine absent'" ;;
    hermes)    "have hermes && echo present || echo absent" ;;
    sessrumnir)"[ -d $ROOT/apps/sessrumnir/out ] && echo built || echo 'not built'" ;;
    well)      "echo 'engram :4602'" ;;
    mcp)       "echo 'a2abridge + engram'" ;;
    lock)      "cat $STATE/.lock 2>/dev/null | tr -d '[:space:]' | sed 's/^/pid /' || echo none" ;;
    migrations)"echo 'structure'" ;;
  esac
}

broken=0
if [ "$ACTION" = "fix" ]; then
  for s in "${SURFACES[@]}"; do
    if ! "s_$s" >/dev/null 2>&1; then
      "f_$s" >/dev/null 2>&1 && printf 'eir: mended %s\n' "$s" || printf 'eir: could not mend %s\n' "$s" >&2
    fi
  done
fi

rows=""
count=0
for s in "${SURFACES[@]}"; do
  if "s_$s" >/dev/null 2>&1; then state=ok; else state=broken; broken=$((broken+1)); fi
  d="$("detail" "$s" 2>/dev/null | head -1)"
  rows="${rows}  \"${s}\",\"${state}\",\"${d}\"\n"
  count=$((count+1))
done

printf 'eir[1]{action,root,broken}:\n  "%s","%s",%s\n' "$ACTION" "$ROOT" "$broken"
printf 'health[%d]{surface,state,detail}:\n' "$count"
printf '%b' "$rows"
if [ "$broken" != 0 ]; then
  printf 'eir: %s surface(s) need mending — run: bin/eir-doctor.sh fix\n' "$broken"
  exit 1
fi
exit 0

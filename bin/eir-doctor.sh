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
YMIR_HOME="${YMIR_HOME:-$HOME/Documents/ymirhome}"
STATE="${BROKK_STATE_OVERRIDE:-$YMIR_HOME/state}"

# The cloth: colour and marks for the human reading this report; the TOON rows on
# stdout stay the data (bin/ymir-style.sh).
if [ -z "${YMIR_STYLE_LOADED:-}" ]; then . "$SCRIPT_DIR/ymir-style.sh"; YMIR_STYLE_LOADED=1; fi
style_init
# Where an app lives: apps/<surface> in a clone, node_modules/@zerwiz/<pkg> in an
# npm install — both shapes, one resolver (bin/app-lib.sh).
if [ -z "${YMIR_APP_LIB_LOADED:-}" ]; then
  _ya="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yac in "$_ya/app-lib.sh" "$(dirname "$_ya")/bin/app-lib.sh"; do
    [ -r "$_yac" ] && { . "$_yac"; YMIR_APP_LIB_LOADED=1; break; }
  done
  unset _ya _yac
fi
app_dir sessrumnir APP_SESSRUMNIR || APP_SESSRUMNIR=""


case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-check}"; shift || true

have() { command -v "$1" >/dev/null 2>&1; }
say_ok() { return 0; }

# Each surface: `s_<name>` = healthy? (exit 0), `f_<name>` = the repair.
SURFACES=(floors herdr a2abridge hermes sessrumnir shells well mcp harness lock migrations hoard autoboot)

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
s_autoboot()  { [ -x "$SCRIPT_DIR/ymir-autoboot.sh" ] && "$SCRIPT_DIR/ymir-autoboot.sh" verify >/dev/null 2>&1; }
# The mend for a stopped boot IS the raise: re-materialize, re-enable, re-verify.
f_autoboot()  { [ -x "$SCRIPT_DIR/fleet-ensure.sh" ] && "$SCRIPT_DIR/fleet-ensure.sh" ensure >/dev/null 2>&1; }
# The desktop shells: absent is healthy (the web surfaces stand alone), PARTIAL is
# not — npm gated the Electron postinstall, so the window cannot open while every
# build still passes (bin/electron-lib.sh).
shell_dirs() {
  local a d
  for a in hlidskjalf odrerir sessrumnir; do
    for d in "$ROOT/apps/$a" "$ROOT/node_modules/@zerwiz/$a"; do
      [ -d "$d" ] && { printf '%s\n' "$d"; break; }
    done
  done
}
s_shells() {
  local d state
  while IFS= read -r d; do
    state="$(electron_runtime_state "$d" 2>/dev/null || true)"
    [ "$state" = partial ] && return 1
  done < <(shell_dirs)
  return 0
}
f_shells() {
  printf 'eir: the shells need YOUR hand — npm gated the runtime download:\n' >&2
  electron_remedy >&2
  return 1
}
if [ -z "${YMIR_ELECTRON_LIB_LOADED:-}" ] && [ -r "$SCRIPT_DIR/electron-lib.sh" ]; then
  . "$SCRIPT_DIR/electron-lib.sh"; YMIR_ELECTRON_LIB_LOADED=1
fi

s_well()      { [ -x "$SCRIPT_DIR/mimir.sh" ] && "$SCRIPT_DIR/mimir.sh" health >/dev/null 2>&1; }
f_well()      { "$SCRIPT_DIR/mimir.sh" start >/dev/null 2>&1; }
# MCP: both A2A servers wired into opencode + pi.
s_mcp() {
  local pi="$HOME/.pi/agent/mcp.json" oc="$ROOT/opencode.json"
  # The live MCP surfaces: the OpenCode config must still bind engram (the well),
  # and the Pi config must parse and carry the fleet servers. The old demand for
  # "a2abridge" is retired — the fleet moved to well/bolthorn/skuld/firecrawl, and
  # the real connection proof now lives in smoke_test.sh (2026-09-23).
  [ -f "$pi" ] || [ -f "$oc" ] || return 1
  if [ -f "$oc" ]; then grep -q '"engram"' "$oc" 2>/dev/null || return 1; fi
  if [ -f "$pi" ]; then
    grep -q '"mcpServers"' "$pi" 2>/dev/null || return 1
    command -v python3 >/dev/null 2>&1 && ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$pi" 2>/dev/null && return 1
  fi
  return 0
}
f_mcp()       { [ -x "$SCRIPT_DIR/a2a-mcp.sh" ] && "$SCRIPT_DIR/a2a-mcp.sh" install >/dev/null 2>&1; }
# Harness: the Pi extensions are DEPLOYED away from this tree, so a copy cannot
# find bin/ by walking up — it reads the root recorded beside it (`.ymir-root`,
# written by bin/valknut-load.sh, resolved by .pi/extensions/lib/ymir-home.ts).
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
    [ -x "$line/bin/syn-watch-arm.sh" ] && return 0
  done <"$PI_EXT_HOME/.ymir-root"
  return 1
}
f_harness()   { [ -x "$SCRIPT_DIR/valknut-load.sh" ] && "$SCRIPT_DIR/valknut-load.sh" --pi >/dev/null 2>&1 && s_harness; }
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
# Hoard: private data sits under the hoard, and .ymir-layout.yaml tells the truth.
# Two failures this catches: (1) a declared layout path that does not exist — a
# stale map is what lets private work land outside the hoard; (2) a flat
# $YMIR_HOME/{identity,data,docs,secrets,tenants} duplicate beside hodd/ — the
# drift that RULES/04-hoard.md (correction 2026-09-17) forbids.
_hoard_root() { local r; if [ -x "$SCRIPT_DIR/hoard-lib.sh" ]; then . "$SCRIPT_DIR/hoard-lib.sh"; hoard_root r; printf '%s' "$r"; else printf '%s' "${YMIR_HOARD:-$YMIR_HOME/hodd}"; fi; }
s_hoard() {
  local h; h="$(_hoard_root)"
  [ -d "$h" ] || return 1
  local lay="$YMIR_HOME/.ymir-layout.yaml" k p
  if [ -f "$lay" ]; then
    for k in config secrets identity workspaces memory smidja state data; do
      p="$(sed -nE "s/^  $k: \"([^\"]+)\".*/\1/p" "$lay" | head -1)"
      [ -n "$p" ] && [ ! -d "$p" ] && return 1
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
  local lay="$YMIR_HOME/.ymir-layout.yaml" k2 p
  if [ -f "$lay" ] && [ -d "$h" ]; then
    for k2 in identity data secrets docs tenants; do
      p="$(sed -nE "s/^  $k2: \"([^\"]+)\".*/\1/p" "$lay" | head -1)"
      if [ -n "$p" ] && [ ! -d "$p" ]; then
        sed -i "s|^  $k2: .*|  $k2: \"$h/$k2\"|" "$lay"
      fi
    done
  fi
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

detail() { # <name> -> one short fact
  case "$1" in
    floors)    "[ -x $SCRIPT_DIR/prereq-ensure.sh ] && echo tool floors" ;;
    herdr)     "have herdr && herdr --version 2>/dev/null | head -1 || echo 'herdr absent'" ;;
    a2abridge) "have a2abridge && a2abridge --version 2>/dev/null | head -1 || echo 'engine absent'" ;;
    hermes)    "have hermes && echo present || echo absent" ;;
    sessrumnir)"[ -d $APP_SESSRUMNIR/out ] && echo built || echo 'not built'" ;;
    well)      "echo 'engram :4602'" ;;
    mcp)       "echo 'a2abridge + engram'" ;;
    harness)   "s_harness && echo 'deployed extensions resolve their bin/' || echo 'no live root recorded'" ;;
    lock)      "cat $STATE/.lock 2>/dev/null | tr -d '[:space:]' | sed 's/^/pid /' || echo none" ;;
    migrations)"echo 'structure'" ;;
    shells)    'shell_dirs | while IFS= read -r d; do printf "%s %s; " "$(basename "$d")" "$(electron_runtime_state "$d" 2>/dev/null || true)"; done' ;;
    hoard)     "printf 'hoard %s' \"$(_hoard_root)\" ; [ -d \"$YMIR_HOME/identity\" ] && printf ' +flat-duplicate' ; printf '\\n'" ;;
    autoboot)  "$SCRIPT_DIR/ymir-autoboot.sh verify >/dev/null 2>&1 && echo 'boot proven' || echo 'boot gap — bin/ymir-autoboot.sh verify'" ;;
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
# For the eye, on stderr: marks and colour; for the pipe, the TOON above.
if [ -t 2 ]; then
  printf '\n' >&2
  while IFS='|' read -r surface state detail; do
    [ -n "$surface" ] || continue
    style_line "$state" "$surface" "$detail"
  done <<<"$(printf '%b' "$rows" | sed 's/^  //; s/"//g; s/,/|/; s/,/|/')"
fi
if [ "$broken" != 0 ]; then
  printf 'eir: %s surface(s) need mending — run: bin/eir-doctor.sh fix\n' "$broken"
  exit 1
fi
exit 0

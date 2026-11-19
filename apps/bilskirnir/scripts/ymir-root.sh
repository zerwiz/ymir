#!/usr/bin/env bash
# ymir-root.sh — where Ymir is on this machine, if it is here at all (the split, 2026-11-19).
#
# Bilskirnir used to climb out of its own folder into Ymir's tree (`$APP/../../bin/…`). Installed in its own
# home (~/.local/share/ymir-apps/bilskirnir/), that climb finds nothing. Ymir is an OPTIONAL neighbour: its home
# resolver, its voice door, its MCP door and its model catalog are borrowed when it is present, and their absence
# is said in words, never a crash.
#
# Source it, then:
#   ymir_root <result-var>   the Ymir tree to borrow from, or empty (exit 1) when there is none
# First hit wins, each one proved by the file it must carry:
#   YMIR_RUNTIME_DIR · ~/ymir-runtime (the pin) · the tree this app sits in (Ymir's apps/ before the split)
ymir_root() {
  local _yr_rv=${1-} _yr_c _yr_app
  [ -n "$_yr_rv" ] || return 2
  _yr_app="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  for _yr_c in "${YMIR_RUNTIME_DIR:-}" "$HOME/ymir-runtime" "$(dirname "$(dirname "$_yr_app")")"; do
    [ -n "$_yr_c" ] && [ -f "$_yr_c/bin/vault/hoard-lib.sh" ] && { printf -v "$_yr_rv" '%s' "$_yr_c"; return 0; }
  done
  printf -v "$_yr_rv" '%s' ""
  return 1
}

# The home, by Ymir's own resolver when Ymir is here; otherwise its one documented default (RULES/07).
bilskirnir_home_root() {  # <result-var>
  local _bh_rv=${1-} _bh_root=""
  [ -n "$_bh_rv" ] || return 2
  if ymir_root _bh_root && . "$_bh_root/bin/vault/hoard-lib.sh" 2>/dev/null && command -v ymir_home_root >/dev/null 2>&1; then
    ymir_home_root "$_bh_rv"; return 0
  fi
  printf -v "$_bh_rv" '%s' "${YMIR_HOME:-$HOME/Documents/ymirhome}"
}

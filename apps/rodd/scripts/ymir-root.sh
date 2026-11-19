#!/usr/bin/env bash
# ymir-root.sh — the Ymir that gives Rödd her voice (the split, 2026-11-19).
#
# Rödd's window is a face over Ymir's voice: the voice door, the head, the toolbox, the desk check and the arm
# all live in Ymir and stay there (the arm is the house's, never the window's). The window used to climb out of
# its own folder to reach them (`$APP/../..`); installed in its own home, that climb finds nothing. So Ymir is a
# HARD need, found here, and named in words when it is missing.
#
# Source it, then:
#   ymir_root <result-var>   the Ymir tree, or empty (exit 1)
# First hit wins, each proved by the voice door it must carry:
#   YMIR_RUNTIME_DIR · ~/ymir-runtime (the pin) · the tree this window sits in (Ymir's apps/ before the split)
ymir_root() {
  local _yr_rv=${1-} _yr_c _yr_app
  [ -n "$_yr_rv" ] || return 2
  _yr_app="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  for _yr_c in "${YMIR_RUNTIME_DIR:-}" "$HOME/ymir-runtime" "$(dirname "$(dirname "$_yr_app")")"; do
    [ -n "$_yr_c" ] && [ -f "$_yr_c/bin/voice/voice-door.sh" ] && { printf -v "$_yr_rv" '%s' "$_yr_c"; return 0; }
  done
  printf -v "$_yr_rv" '%s' ""
  return 1
}

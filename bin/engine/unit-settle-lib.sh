#!/usr/bin/env bash
# unit-settle-lib.sh — every script that writes a unit hands it to the register afterwards (plan 272, fault 12).
# Sourced, never executed.
#
# WHY (measured on a collaborator's seat, 2026-11-12): an old checkout ran its own `garmr.sh`, which rendered
# `garmr-brain` with whatever tree it stood in and switched the unit off the pin — once, unseen. Plan 269 made
# `bin/engine/units.sh` (the register, config/units.yaml) the ONE writer of units; a script that still renders its own
# unit must therefore settle it through that writer in the same breath, so the unit is on the pin when the script
# returns, whatever tree the script ran from.
#
#   unit_settle <name…>      retarget the named registered units onto the pinned runtime and prove it (no restart:
#                            the script that wrote the unit decides its own restart). Prints one line per outcome.
#   unit_pin_dir             print the pinned runtime directory, or nothing when none is seated
#
# The PIN's own `units.sh` is the one run — never the calling tree's, which is exactly the tree that may be old. A seat
# with no pin seated is told so in words; nothing is written to a working tree in its place.
unit_pin_dir() {
  local d="${YMIR_RUNTIME_DIR:-}" home="" conf=""
  if [ -z "$d" ]; then
    if command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root home 2>/dev/null; fi
    home="${home:-${YMIR_HOME:-$HOME/Documents/ymirhome}}"
    conf="$home/config/runtime.env"
    if [ -r "$conf" ]; then d="$(sed -n 's/^YMIR_RUNTIME_DIR=//p' "$conf" 2>/dev/null | tail -1 | tr -d "\"'")"; fi
  fi
  d="${d:-$HOME/ymir-runtime}"
  case "$d" in '~/'*) d="$HOME/${d#\~/}" ;; esac
  [ -d "$d" ] && printf '%s' "$d"
}

unit_settle() {  # <name…>
  local pin tool rc
  pin="$(unit_pin_dir)"
  if [ -z "$pin" ]; then
    printf 'units: no pinned runtime is seated — %s left as written; seat the pin (bin/engine/runtime-seat.sh) and run bin/engine/units.sh write\n' "$*" >&2
    return 1
  fi
  tool="$pin/bin/engine/units.sh"
  if [ ! -x "$tool" ] && [ ! -r "$tool" ]; then
    printf 'units: the pin at %s carries no bin/engine/units.sh — %s not settled\n' "$pin" "$*" >&2
    return 1
  fi
  bash "$tool" write "$@" --no-restart >/dev/null 2>&1; rc=$?
  if [ "$rc" = 0 ]; then
    printf 'units: %s settled on the pin through the register\n' "$*" >&2
  else
    printf 'units: %s could NOT be settled on the pin (rc=%s) — run bin/engine/units.sh write\n' "$*" "$rc" >&2
  fi
  return "$rc"
}

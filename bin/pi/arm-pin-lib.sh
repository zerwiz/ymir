#!/usr/bin/env bash
# arm-pin-lib.sh — where the ARM's code lives: the pinned runtime, never a working tree.
#
# Plan 257 H6 (corrected): "the helm runs the PINNED code". The arm service already runs
# from the pin (ymir-syn-watch.service → $YMIR_RUNTIME_DIR); the per-turn clients that
# carry its wakes ran the WORKING tree, which an agent may be standing on any branch of.
# This lib is the one resolver every client and adapter shares, reading the same file the
# ward reads (bin/gates/guards/runtime-pinned-guard.sh, RULES/02 §7):
#
#   $YMIR_RUNTIME_DIR (env) → <home>/config/runtime.env YMIR_RUNTIME_DIR → ~/ymir-runtime when seated → empty
#
# Source-safe: defines functions only; call `<fn> <result-var>`.
#
#   arm_pin_dir <var>       the pinned checkout, or empty when none is configured
#   arm_pin_branch <var>    the branch the pin follows (YMIR_RUNTIME_BRANCH, default main)
#   arm_pin_client <var>    the pin's bin/pi/syn-watch-arm.sh, or empty when it is missing
#   arm_code_root <var>     the checkout THIS lib's code is executing from (resolved)
# (no `set` here: a sourced lib must not change its caller's shell options)

_ARM_PIN_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_arm_pin_home() {  # <var> — the operator's home, by the house's own resolver
  local _h=""
  if ! declare -f ymir_home_root >/dev/null 2>&1; then
    [ -r "$_ARM_PIN_LIB_DIR/../vault/hoard-lib.sh" ] && . "$_ARM_PIN_LIB_DIR/../vault/hoard-lib.sh" 2>/dev/null
  fi
  declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root _h 2>/dev/null
  [ -n "$_h" ] || _h="${YMIR_HOME:-}"
  printf -v "$1" '%s' "$_h"
}

arm_pin_dir() {  # <var>
  local _var=${1-} _dir="${YMIR_RUNTIME_DIR:-}" _home="" _conf="" _line=""
  [ -n "$_var" ] || return 2
  if [ -z "$_dir" ]; then
    _arm_pin_home _home
    _conf="${_home:+$_home/config/runtime.env}"
    if [ -n "$_conf" ] && [ -r "$_conf" ]; then
      _line="$(grep -m1 -E '^[[:space:]]*(export[[:space:]]+)?YMIR_RUNTIME_DIR=' "$_conf" 2>/dev/null || true)"
      _dir="${_line#*=}"
      _dir="${_dir%\"}"; _dir="${_dir#\"}"; _dir="${_dir%\'}"; _dir="${_dir#\'}"
      # the file writes "$HOME/ymir-runtime" — expand $HOME and a leading ~, nothing else
      _dir="${_dir//\$\{HOME\}/$HOME}"
      _dir="${_dir//\$HOME/$HOME}"
      case "$_dir" in "~"/*) _dir="$HOME/${_dir#\~/}" ;; esac
    fi
  fi
  # No recorded choice: the one documented default (plan 269), once install has SEATED a checkout there.
  [ -n "$_dir" ] || { [ -d "$HOME/ymir-runtime/.git" ] && _dir="$HOME/ymir-runtime"; }
  printf -v "$_var" '%s' "$_dir"
}

arm_pin_branch() {  # <var> — the branch the pin follows (YMIR_RUNTIME_BRANCH, default main)
  local _var=${1-} _b="${YMIR_RUNTIME_BRANCH:-}" _home="" _conf="" _line=""
  [ -n "$_var" ] || return 2
  if [ -z "$_b" ]; then
    _arm_pin_home _home
    _conf="${_home:+$_home/config/runtime.env}"
    if [ -n "$_conf" ] && [ -r "$_conf" ]; then
      _line="$(grep -m1 -E '^[[:space:]]*(export[[:space:]]+)?YMIR_RUNTIME_BRANCH=' "$_conf" 2>/dev/null || true)"
      _b="${_line#*=}"; _b="${_b%\"}"; _b="${_b#\"}"; _b="${_b%\'}"; _b="${_b#\'}"
    fi
  fi
  printf -v "$_var" '%s' "${_b:-main}"
}

arm_pin_client() {  # <var>
  local _var=${1-} _pin=""
  [ -n "$_var" ] || return 2
  arm_pin_dir _pin
  if [ -n "$_pin" ] && [ -x "$_pin/bin/pi/syn-watch-arm.sh" ]; then
    printf -v "$_var" '%s' "$_pin/bin/pi/syn-watch-arm.sh"
  else
    printf -v "$_var" '%s' ""
  fi
}

arm_code_root() {  # <var>
  local _var=${1-}
  [ -n "$_var" ] || return 2
  printf -v "$_var" '%s' "$(cd "$_ARM_PIN_LIB_DIR/../.." && pwd -P)"
}

_arm_real() { (cd "$1" 2>/dev/null && pwd -P) || printf '%s' "$1"; }

# arm_pin_admit — the H6 gate, ONE grammar for every caller. Returns:
#   0  this code IS the pin (or YMIR_ARM_TREE=1, the loud override) — proceed
#   3  this code is not the pin and the pin's client exists — exec it ($ARM_PIN_CLIENT)
#   1  no usable pin — the caller stands read-only; $ARM_PIN_REASON names why
arm_pin_admit() {
  local _pin="" _code=""
  ARM_PIN_REASON=""; ARM_PIN_CLIENT=""
  if [ "${YMIR_ARM_TREE:-0}" = 1 ]; then
    ARM_PIN_REASON="YMIR_ARM_TREE=1 — the helm runs a working tree by the loud override"
    return 0
  fi
  arm_pin_dir _pin
  arm_code_root _code
  if [ -z "$_pin" ]; then
    ARM_PIN_REASON="no pinned runtime is configured (YMIR_RUNTIME_DIR in <home>/config/runtime.env) (remedy: bin/engine/runtime-deploy.sh)"
    return 1
  fi
  if [ "$(_arm_real "$_pin")" = "$_code" ]; then
    return 0
  fi
  if [ ! -x "$_pin/bin/pi/syn-watch-arm.sh" ]; then
    ARM_PIN_REASON="the pinned runtime $_pin has no bin/pi/syn-watch-arm.sh (remedy: bin/engine/runtime-deploy.sh)"
    return 1
  fi
  ARM_PIN_CLIENT="$_pin/bin/pi/syn-watch-arm.sh"
  return 3
}

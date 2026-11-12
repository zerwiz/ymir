#!/usr/bin/env bash
# runtime-seat.sh — SEAT the pinned runtime: the checkout every Ymir service and app runs from (plan 269).
#
#   bin/engine/runtime-seat.sh            seat (or confirm) the pin, record it, move every unit onto it
#   bin/engine/runtime-seat.sh --check    report only; change nothing
#
# Idempotent and safe on a machine that already has a pin. It does four things, in order:
#   1. clone ~/ymir-runtime from origin/<branch> when no checkout stands there (never a working tree);
#   2. record YMIR_RUNTIME_DIR / YMIR_RUNTIME_BRANCH in <home>/config/runtime.env, ADDING only the keys
#      that are missing — an operator's own line is never rewritten (Rule 06);
#   3. bring its dependency closure (runtime-deploy.sh --no-restart);
#   4. write every unit and launcher against it (units.sh write).
#
# Configuration (Rule 07): YMIR_RUNTIME_DIR · YMIR_RUNTIME_BRANCH · YMIR_RUNTIME_SOURCE (the clone source;
# default: the origin of the tree this script runs from). The Omarchy/Linux layer is first-class; a host
# with no systemd skips the unit step with a named line (Rule 05).
set -uo pipefail
HERE="$(dirname "${BASH_SOURCE[0]}")"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null || dirname "$(dirname "$HERE")")"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
home=""
declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root home 2>/dev/null
[ -n "$home" ] || home="${YMIR_HOME:-}"
[ -n "$home" ] || { printf 'FAIL\tno home to record the pin in\tset YMIR_HOME or run the installer step "home"\n'; exit 1; }
conf="$home/config/runtime.env"

check=0
case "${1:-}" in
  --check) check=1 ;;
  -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "") ;;
  *) printf 'error: unknown option %s\n' "$1" >&2; exit 2 ;;
esac

[ -r "$conf" ] && . "$conf"
PIN="${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}"
BRANCH="${YMIR_RUNTIME_BRANCH:-main}"
SRC="${YMIR_RUNTIME_SOURCE:-$(git -C "$ROOT" remote get-url origin 2>/dev/null)}"

if [ "$check" = 1 ]; then
  if [ -d "$PIN/.git" ]; then
    printf 'seated\t%s\tthe pinned runtime stands (branch %s)\n' "$PIN" "$(git -C "$PIN" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  else
    printf 'ABSENT\t%s\tno pinned runtime yet — runtime-seat.sh clones it from origin/%s\n' "$PIN" "$BRANCH"; exit 1
  fi
  YMIR_RUNTIME_DIR="$PIN" bash "$ROOT/bin/engine/units.sh" check >/dev/null 2>&1 && exit 0
  printf 'STRAY\ta unit or launcher is off the pin or not in the register\trun bin/engine/units.sh check\n'; exit 1
fi

# 1 · the checkout
if [ ! -d "$PIN/.git" ]; then
  if [ -e "$PIN" ] && [ -n "$(ls -A "$PIN" 2>/dev/null)" ]; then
    printf 'FAIL\t%s exists and is not a git checkout\tmove it aside, then run this again\n' "$PIN"; exit 1
  fi
  [ -n "$SRC" ] || { printf 'FAIL\tno clone source\tset YMIR_RUNTIME_SOURCE, or run from a tree that has an origin\n'; exit 1; }
  mkdir -p "$(dirname "$PIN")"
  git clone -q --branch "$BRANCH" "$SRC" "$PIN" 2>/dev/null || {
    printf 'FAIL\tcould not clone %s (branch %s) into %s\tcheck the network, or set YMIR_RUNTIME_SOURCE\n' "$SRC" "$BRANCH" "$PIN"; exit 1; }
  printf 'cloned\t%s\tfrom %s on %s\n' "$PIN" "$SRC" "$BRANCH"
else
  printf 'present\t%s\tan existing pin is kept\n' "$PIN"
fi

# 2 · the record — append only what is missing
mkdir -p "$home/config"
touch "$conf"
if ! grep -Eq '^[[:space:]]*(export[[:space:]]+)?YMIR_RUNTIME_DIR=' "$conf"; then
  case "$PIN" in "$HOME"/*) rec="\$HOME/${PIN#"$HOME"/}" ;; *) rec="$PIN" ;; esac
  printf 'YMIR_RUNTIME_DIR="%s"\n' "$rec" >>"$conf"
fi
grep -Eq '^[[:space:]]*(export[[:space:]]+)?YMIR_RUNTIME_BRANCH=' "$conf" || printf 'YMIR_RUNTIME_BRANCH="%s"\n' "$BRANCH" >>"$conf"
printf 'recorded\t%s\tYMIR_RUNTIME_DIR · YMIR_RUNTIME_BRANCH\n' "$conf"

# 3 · its dependency closure, without restarting anything
if [ -x "$PIN/bin/engine/runtime-deploy.sh" ]; then
  YMIR_RUNTIME_DIR="$PIN" bash "$PIN/bin/engine/runtime-deploy.sh" --no-restart >/dev/null 2>&1 || printf 'WARN\tdependencies did not install\trun bin/engine/runtime-deploy.sh\n'
fi

# 4 · every unit and launcher onto it — the pin's own writer, so what runs is what main ships
if command -v systemctl >/dev/null 2>&1 || [ -n "${YMIR_UNITS_NO_SYSTEMCTL:-}" ]; then
  door="$PIN/bin/engine/units.sh"; [ -x "$door" ] || door="$ROOT/bin/engine/units.sh"
  YMIR_RUNTIME_DIR="$PIN" bash "$door" write; rc=$?
  [ "$rc" = 0 ] || { printf 'FAIL\tunits.sh write reported a problem\trun: bin/engine/units.sh check\n'; exit 1; }
else
  printf 'SKIP\tno systemd on this host\tunits are another platform layer'"'"'s business (Rule 05)\n'
fi
printf 'seated\t%s\tevery Ymir unit and launcher is written against it\n' "$PIN"

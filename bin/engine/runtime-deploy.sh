#!/usr/bin/env bash
# runtime-deploy.sh — move the PINNED runtime checkout to the merged tree, and prove what is running.
#
#   bin/engine/runtime-deploy.sh --check     what the units run, against origin/<branch>; changes nothing
#   bin/engine/runtime-deploy.sh            fetch, move the pinned checkout, install its dependencies,
#                                           restart the units, prove each one, print the commit
#   bin/engine/runtime-deploy.sh --no-restart   fetch, move, install dependencies, then stop (the seat step uses it)
#   bin/engine/runtime-deploy.sh --help
#
# WHY. On 2026-11-02 ten systemd user units were found executing files from the operator's WORKING tree — the
# directory agents check branches out in — so a `git checkout` changed the code the scheduler, the well, the
# model bridge, the MCP face, the warden and the assistant were running, with no approval and no restart
# (RULES/02 §7). This is the door that ends that: the units point at a checkout that only ever stands on the
# default branch, and this verb moves it and proves the result.
#
# Configuration (Rule 07 — resolved, never hardcoded):
#   $YMIR_HOME/config/runtime.env   YMIR_RUNTIME_DIR · YMIR_RUNTIME_UNITS · YMIR_RUNTIME_BRANCH
#   defaults: <home>/ymir-runtime · every unit the register (config/units.yaml) owes this seat · main
#   YMIR_RUNTIME_UNITS is an OVERRIDE only. The units come from the one register (plan 269), so a service
#   that is on no fixed list can never escape the pin.
set -uo pipefail

ROOT="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
home=""
declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root home 2>/dev/null
[ -n "$home" ] || home="${YMIR_HOME:-}"
conf="${home:+$home/config/runtime.env}"
[ -n "$conf" ] && [ -r "$conf" ] && . "$conf"

RUN_DIR="${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}"
BRANCH="${YMIR_RUNTIME_BRANCH:-main}"
UNITS="${YMIR_RUNTIME_UNITS:-}"

action="deploy"
case "${1:-}" in
  -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --check) action="check" ;;
  --no-restart) action="seat" ;;
  ""|--deploy) ;;
  *) printf 'error: unknown action %s\nhelp: runtime-deploy.sh [--check]\n' "$1" >&2; exit 2 ;;
esac

[ -d "$RUN_DIR/.git" ] || {
  printf 'FAIL\tno pinned checkout\tthere is no git checkout at %s — the units are running a working tree\n' "$RUN_DIR"
  printf 'help\tgit clone https://github.com/zerwiz/ymir %s && re-point the units\n' "$RUN_DIR"
  exit 1; }

running=$(git -C "$RUN_DIR" rev-parse --short HEAD 2>/dev/null | tr -d '[:space:]')
git -C "$RUN_DIR" fetch -q origin "$BRANCH" || {
  printf 'FAIL\tthe checkout could not fetch\tgit -C %s fetch origin %s failed\n' "$RUN_DIR" "$BRANCH"; exit 1; }
merged=$(git -C "$RUN_DIR" rev-parse --short "origin/$BRANCH" | tr -d '[:space:]')

if [ "$action" = "check" ]; then
  if [ "$running" = "$merged" ]; then
    printf 'deployed\t%s\t%s\tthe pinned runtime stands on origin/%s\n' "$running" "$merged" "$BRANCH"; exit 0
  fi
  printf 'STALE\trunning=%s merged=%s\trun runtime-deploy.sh\n' "$running" "$merged"; exit 1
fi

# 1. the pinned checkout moves — never a working tree, and never a merge commit of its own
git -C "$RUN_DIR" checkout -q "$BRANCH" && git -C "$RUN_DIR" reset -q --hard "origin/$BRANCH" || {
  printf 'FAIL\tthe checkout could not be moved to origin/%s\n' "$BRANCH"; exit 1; }
now=$(git -C "$RUN_DIR" rev-parse --short HEAD | tr -d '[:space:]')

# 2. its dependency closure, because node-based tools (the calendar reader, the MCP faces) need it and a fresh
#    clone has none — measured 2026-11-02: calendar-watch died on `Cannot find package 'zod'`.
if [ -f "$RUN_DIR/package-lock.json" ] && [ ! -d "$RUN_DIR/node_modules/zod" ]; then
  printf 'deps\tinstalling the runtime dependency closure (npm ci --omit=dev)\n'
  ( cd "$RUN_DIR" && npm ci --omit=dev --no-audit --no-fund >/dev/null 2>&1 ) || {
    printf 'FAIL\tthe dependency closure did not install\trun it by hand: cd %s && npm ci --omit=dev\n' "$RUN_DIR"; exit 1; }
fi

if [ "$action" = "seat" ]; then
  printf 'deployed\t%s\t%s\tthe pinned runtime moved; no unit was touched\n' "$now" "$RUN_DIR"; exit 0
fi

# 2b. the units move onto the pin first (the one writer, from the pin's own register), then restart from
#     the register: a unit that runs a working tree is rewritten, its old line logged.
UNITS_DOOR="$RUN_DIR/bin/engine/units.sh"; [ -x "$UNITS_DOOR" ] || UNITS_DOOR="$ROOT/bin/engine/units.sh"
if [ -x "$UNITS_DOOR" ]; then
  YMIR_RUNTIME_DIR="$RUN_DIR" bash "$UNITS_DOOR" write --no-restart >/dev/null 2>&1 || \
    printf 'WARN\tunits.sh write reported a problem\trun: bin/engine/units.sh check\n'
  [ -n "$UNITS" ] || UNITS="$(YMIR_RUNTIME_DIR="$RUN_DIR" bash "$UNITS_DOOR" list --restart 2>/dev/null | sort -u | tr '\n' ' ')"
fi

# 3. restart, then prove each unit by its own state (a oneshot that exits 0 is `inactive/dead` and CORRECT)
systemctl --user daemon-reload
# a register name carries its suffix (.timer for a clock); an override name is a bare service
unit_name() { case "$1" in *.service|*.timer) printf '%s' "$1" ;; *) printf '%s.service' "$1" ;; esac; }
unit_present() { [ -n "$(systemctl --user list-unit-files "$(unit_name "$1")" --no-legend 2>/dev/null)" ]; }
for u in $UNITS; do
  unit_present "$u" || continue
  systemctl --user restart "$(unit_name "$u")" >/dev/null 2>&1
done
sleep 6

fail=0
for u in $UNITS; do
  unit_present "$u" || continue
  full="$(unit_name "$u")"
  state=$(systemctl --user show -p ActiveState -p SubState --value "$full" 2>/dev/null | paste -sd/ -)
  type=$(systemctl --user show -p Type --value "$full" 2>/dev/null)
  case "$full" in *.timer) type=timer ;; esac
  case "$type:$state" in
    timer:active/waiting|timer:active/running) ok=1 ;;
    oneshot:inactive/dead|oneshot:active/*|simple:active/running|notify:active/running|exec:active/running|forking:active/running) ok=1 ;;
    *) ok=0 ;;
  esac
  printf '%-20s %-10s %-20s %s\n' "$u" "${type:-simple}" "${state:-unknown}" "$([ "$ok" = 1 ] && echo ok || echo FAIL)"
  [ "$ok" = 1 ] || fail=1
done

if [ "$fail" -ne 0 ]; then
  printf 'FAIL\ta unit did not settle after the move\tcommit %s is in place; see: journalctl --user -u <unit> -n 40\n' "$now"
  exit 1
fi
printf 'deployed\t%s\t%s\tthe pinned runtime moved and every unit settled\n' "$now" "$RUN_DIR"

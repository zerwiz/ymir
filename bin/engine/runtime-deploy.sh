#!/usr/bin/env bash
# runtime-deploy.sh — move the PINNED runtime checkout to the merged tree, and prove what is running.
#
#   bin/engine/runtime-deploy.sh --check     what the units run, against origin/<branch>; changes nothing
#   bin/engine/runtime-deploy.sh            fetch, move the pinned checkout, install its dependencies,
#                                           restart the units, prove each one, print the commit
#   bin/engine/runtime-deploy.sh --no-restart   fetch, move, install dependencies, then stop (the seat step uses it)
#   bin/engine/runtime-deploy.sh --help
#
# STABLE (plan 275, 2026-11-12 — S6 and S1):
#   · a DIRTY pin is refused, never wiped: a hand edit on the pin is named, filed as a fault, and left in place
#     (the old `reset --hard` destroyed it silently; Gróa's own check hid the edits for three days)
#   · the commit that was running is recorded first; when a unit does not settle on the new commit, the pin is
#     moved BACK to it and the units restart onto the last good code — the machine is never left broken
#   · every good move writes $YMIR_HOME/state/runtime/last-good (the canary's record, S2); every refusal and
#     every rollback writes a dated fault report under $YMIR_HOME/hodd/state/groa/faults/ (plan 275 step B)
#   YMIR_RUNTIME_NO_ROLLBACK=1 leaves a failed move in place (a person debugging it on purpose).
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
previous=$(git -C "$RUN_DIR" rev-parse HEAD 2>/dev/null | tr -d '[:space:]')

# where the record lives: the home's state (the canary's last-good) and the hoard's fault shelf
STATE_RT="${home:+$home/state/runtime}"; FAULTS="${home:+$home/hodd/state/groa/faults}"
. "$ROOT/bin/time/sol-lib.sh" 2>/dev/null || true
stamp() { if declare -f sol_line >/dev/null 2>&1; then sol_line; else date '+%F %H:%M %Z'; fi; }
fault() {  # <slug> <title> <body…> — one dated report the operator and Gróa's smith can read
  [ -n "$FAULTS" ] || return 0
  mkdir -p "$FAULTS" 2>/dev/null || return 0
  local f="$FAULTS/$(date +%F)-runtime-$1.md"
  { printf '# %s\n\n**When:** %s · **seat:** %s · **pin:** %s\n\n' "$2" "$(stamp)" "$(hostname -s 2>/dev/null)" "$RUN_DIR"
    shift 2; printf '%s\n' "$@"; } > "$f" 2>/dev/null && printf 'fault\t%s\n' "$f"
}
git -C "$RUN_DIR" fetch -q origin "$BRANCH" || {
  printf 'FAIL\tthe checkout could not fetch\tgit -C %s fetch origin %s failed\n' "$RUN_DIR" "$BRANCH"; exit 1; }
merged=$(git -C "$RUN_DIR" rev-parse --short "origin/$BRANCH" | tr -d '[:space:]')

if [ "$action" = "check" ]; then
  if [ "$running" = "$merged" ]; then
    printf 'deployed\t%s\t%s\tthe pinned runtime stands on origin/%s\n' "$running" "$merged" "$BRANCH"; exit 0
  fi
  printf 'STALE\trunning=%s merged=%s\trun runtime-deploy.sh\n' "$running" "$merged"; exit 1
fi

# 0. a dirty pin is refused, never wiped (plan 275 S6): its hand edits are the only copy until they reach the code
dirty=$(git -C "$RUN_DIR" status --porcelain --untracked-files=no 2>/dev/null)
if [ -n "$dirty" ]; then
  printf 'REFUSED\tthe pin carries hand edits — they would be wiped\t%s\n' "$(printf '%s' "$dirty" | awk '{print $2}' | paste -sd' ' -)"
  printf 'help\tcarry them into main by PR, then: git -C %s checkout -- <files>; then run this again\n' "$RUN_DIR"
  fault dirty-pin "The pin carries hand edits" "The update refused to move the pin, because these files differ from the commit it runs:" "" '```' "$dirty" '```' "" "Carry each edit into main by a PR, then restore the files on the pin and run the update again."
  exit 3
fi

# 1. the runtime moves. A pin that is a LINK to a release (plan 275 S9, after `release.sh adopt`) is never touched in
#    place: a new release is built beside it, proved app by app, and the link flips in one rename. Only an old,
#    not-yet-adopted pin is still moved with checkout + reset (the road this plan retires).
RELEASE_DOOR="$ROOT/bin/engine/release.sh"
if [ -L "$RUN_DIR" ] && [ -x "$RELEASE_DOOR" ]; then
  printf 'release\tbuilding origin/%s beside the running release (nothing moves until it is proved)\n' "$BRANCH"
  rel_out="$(bash "$RELEASE_DOOR" build --ref "origin/$BRANCH" --from "$RUN_DIR" 2>&1)"; rel_rc=$?
  printf '%s\n' "$rel_out" | sed 's/^/  /'
  if [ "$rel_rc" != 0 ]; then
    fault release-unproved "The new release did not build or prove" "The running release was left in place." "" '```' "$rel_out" '```'
    printf 'FAIL\tthe new release did not prove — the running one stays\n'; exit 1
  fi
  bash "$RELEASE_DOOR" flip "$(git -C "$RUN_DIR" rev-parse --short=12 "origin/$BRANCH")" | sed 's/^/  /' || {
    printf 'FAIL\tthe flip did not land\n'; exit 1; }
  RELEASED=1
else
  git -C "$RUN_DIR" checkout -q "$BRANCH" && git -C "$RUN_DIR" reset -q --hard "origin/$BRANCH" || {
    printf 'FAIL\tthe checkout could not be moved to origin/%s\n' "$BRANCH"; exit 1; }
  RELEASED=0
fi
now=$(git -C "$RUN_DIR" rev-parse --short HEAD | tr -d '[:space:]')

# 2. its dependency closure, because node-based tools (the calendar reader, the MCP faces) need it and a fresh
#    clone has none — measured 2026-11-02: calendar-watch died on `Cannot find package 'zod'`.
if [ "${RELEASED:-0}" = 0 ] && [ -f "$RUN_DIR/package-lock.json" ] && [ ! -d "$RUN_DIR/node_modules/zod" ]; then
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
  if [ -n "${YMIR_RUNTIME_NO_ROLLBACK:-}" ] || [ -z "$previous" ] || [ "${previous:0:7}" = "${now:0:7}" ]; then
    printf 'FAIL\ta unit did not settle after the move\tcommit %s is in place; see: journalctl --user -u <unit> -n 40\n' "$now"
    fault unsettled "A unit did not settle after the update" "Commit $now is in place (rollback was not possible or was turned off). Read: journalctl --user -u <unit> -n 40"
    exit 1
  fi
  # S1: roll back to the commit that was running, so the machine is never left on code that does not start
  printf 'ROLLBACK\ta unit did not settle on %s — moving the pin back to %s\n' "$now" "${previous:0:8}"
  { if [ "${RELEASED:-0}" = 1 ]; then bash "$RELEASE_DOOR" rollback >/dev/null; else git -C "$RUN_DIR" reset -q --hard "$previous"; fi; } && {
    [ -x "$UNITS_DOOR" ] && YMIR_RUNTIME_DIR="$RUN_DIR" bash "$UNITS_DOOR" write --no-restart >/dev/null 2>&1
    systemctl --user daemon-reload
    for u in $UNITS; do unit_present "$u" && systemctl --user restart "$(unit_name "$u")" >/dev/null 2>&1; done; }
  fault rolled-back "The update was rolled back" "Commit $now did not settle (see the unit table above in the update's output); the pin was moved back to ${previous:0:8}, the last good commit, and the units restarted on it." "Fix the cause in the code; the next update tries again."
  printf 'ROLLED-BACK\t%s\t%s\tthe new commit did not settle; the pin stands on the last good commit\n' "${previous:0:8}" "$RUN_DIR"
  exit 4
fi
if [ -n "$STATE_RT" ] && mkdir -p "$STATE_RT" 2>/dev/null; then
  printf '%s %s %s\n' "$(git -C "$RUN_DIR" rev-parse HEAD)" "$(date -u +%FT%TZ)" "$(hostname -s 2>/dev/null)" > "$STATE_RT/last-good"
fi
printf 'deployed\t%s\t%s\tthe pinned runtime moved and every unit settled\n' "$now" "$RUN_DIR"

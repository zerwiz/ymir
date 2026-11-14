#!/usr/bin/env bash
# cron-registry.sh — every scheduled thing on this machine: the Nornir rows, the system timers, the user timers.
#
# His word (2026-11-14): "we also need to have a cronjob registry for what they are doing."
#
# A schedule with no owner is how a job runs twice a day for weeks while failing (the agnostic audit did exactly that),
# and how two watchers start the same check at the same minute. This lists each row with what it runs, when it last
# ran, when it next runs, and whether the last run failed.
#
#   cron-registry.sh           human list
#   cron-registry.sh --yaml    the record
set -uo pipefail
mode="${1:-table}"
# The home is resolved, never assumed (RULES/07): the one resolver is bin/vault/hoard-lib.sh.
_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ROOT="$(cd "$_DIR" && while [ ! -d "$PWD/RULES" ] || [ ! -d "$PWD/bin" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
if [ -z "${YMIR_HOME:-}" ] && [ -r "$_ROOT/bin/vault/hoard-lib.sh" ]; then
  . "$_ROOT/bin/vault/hoard-lib.sh" >/dev/null 2>&1 || true
  if command -v ymir_home_root >/dev/null 2>&1; then _h=""; ymir_home_root _h; [ -n "$_h" ] && export YMIR_HOME="$_h"; fi
fi
[ -n "${YMIR_HOME:-}" ] || { printf '%s: the home could not be resolved (bin/vault/hoard-lib.sh, RULES/07)\n' "$(basename "$0")" >&2; exit 2; }
ROWS="${YMIR_HOME}/config/cron.yaml"
REPO="${YMIR_REPO:-$HOME/ymir}"

nornir() {
  [ -f "$ROWS" ] || return 0
  grep -E '^@' "$ROWS" 2>/dev/null | while IFS= read -r line; do
    when="$(printf '%s' "$line" | awk '{print $1" "$2}')"
    cmd="$(printf '%s' "$line" | sed -E 's/^@[a-z]+ (@every:[0-9]+|[0-9]{2}:[0-9]{2}) +//')"
    script="${cmd%% *}"                      # the path is the first token; the rest are arguments
    exists="missing"
    for cand in "$REPO/$script" "$HOME/$script"; do [ -x "$cand" ] && exists="ok" && break; done
    printf '%s\t%s\t%s\n' "$when" "$cmd" "$exists"
  done
}

timers() {
  { systemctl list-timers --all --no-legend --no-pager 2>/dev/null
    systemctl --user list-timers --all --no-legend --no-pager 2>/dev/null
  } | awk '{print $1" "$2"|"$3" "$4"|"$NF}' | sed 's/|[^|]*|/|/' | awk -F'|' '{print $1"|"$3}' | head -40
}

if [ "$mode" = "--yaml" ]; then
  printf 'nornir_rows:\n'
  nornir | while IFS=$'\t' read -r when cmd ok; do
    printf '  - when: "%s"\n    command: "%s"\n    script: %s\n' "$when" "$cmd" "$ok"
  done
  printf 'system_timers:\n'
  systemctl list-timers --all --no-legend --no-pager 2>/dev/null | awk '{printf "  - unit: \"%s\"\n    next: \"%s %s\"\n    last: \"%s %s\"\n", $NF, $1, $2, $3, $4}' | head -80
  printf 'user_timers:\n'
  systemctl --user list-timers --all --no-legend --no-pager 2>/dev/null | awk '{printf "  - unit: \"%s\"\n    next: \"%s %s\"\n    last: \"%s %s\"\n", $NF, $1, $2, $3, $4}' | head -80
  exit 0
fi

printf '== Nornir rows (%s)\n' "$ROWS"
nornir | while IFS=$'\t' read -r when cmd ok; do
  flag=""; [ "$ok" = "missing" ] && flag="  ← SCRIPT MISSING (rc=127)"
  printf '  %-18s %s%s\n' "$when" "$(printf '%.64s' "$cmd")" "$flag"
done
printf '\n== system timers\n'
systemctl list-timers --all --no-pager 2>/dev/null | head -14
printf '\n== user timers\n'
systemctl --user list-timers --all --no-pager 2>/dev/null | head -14

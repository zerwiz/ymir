#!/usr/bin/env bash
# builder-budget.sh — how many BUILDERS this machine may hold, and how many stand.
#
# WHY (the Allfather, 2026-11-18): "we can only have one builder at the time. here. … the server can
# handle more builders". The house learned that lesson the hard way on 2026-11-14 — three errands
# dispatched within one minute took an 11 GB box down at load 492 — and the cure written down after
# it bundled two different things into one sentence: ONE HEAVY JOB (a build, a type-check, a gate
# run) and ONE BUILDER (an agent at work). They are not the same cost. An agent is a few hundred
# megabytes and mostly waits; a build is peak RAM and a contended CPU. The heavy jobs are counted by
# `bin/heavy-slot.sh` (one lane each, as many lanes as the machine carries). This door is the other
# half: how many BUILDERS the machine is willing to have standing at once.
#
# THE NUMBER IS THE MACHINE'S, NEVER THE REPO'S (Rule 07 · Rule 25). It is read from this host's own
# row in the home's fleet registry — `hosts.<host>.builders` — where the operator records what the
# box has been measured to carry. Nothing is assumed from a role name, and no second table exists.
#
# WHO COUNTS AS A BUILDER: an agent standing in a Yggdrasil worktree (`…/.yggdrasil/…`), because an
# errand is exactly that — its own worktree, its own seat. The helm sitting in the main hall is not
# an errand, and a machine's own keeper is not one either. The list is `herdr agent list` through
# the ONE reader of it (`bin/seat/herdr-agents.py --tsv`); where that door cannot answer, this door
# says UNKNOWN — never zero, because a green that hides an unmeasured machine is the false green
# this house has paid for twice.
#
#   bin/agents/builder-budget.sh read            the budget, and where the number came from
#   bin/agents/builder-budget.sh status [--json] budget · builders standing · room
#   bin/agents/builder-budget.sh check           exit 0 when there is room, 3 when the budget is full
#
# Exit: 0 room (or read) · 3 full · 4 the budget cannot be read · 2 usage.
set -uo pipefail

BUDGET_VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR/../.." && pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$ROOT/bin/vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi

say()  { printf '%s\n' "$*"; }
die()  { printf '%s\n' "$*" >&2; exit "${2:-2}"; }
HERE="$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')"

usage() {
  printf 'builder-budget — how many builders this machine may hold.\n\n'
  printf '  builder-budget.sh read              the budget and where it came from\n'
  printf '  builder-budget.sh status [--json]   budget · standing · room\n'
  printf '  builder-budget.sh check             exit 0 with room, 3 when full\n\n'
  printf 'The number is `hosts.%s.builders` in the home'"'"'s fleet registry;\n' "$HERE"
  printf 'YMIR_BUILDER_BUDGET overrides it for one command. Exit 4 = the budget cannot be read.\n'
}

# ── the budget: this host's own row, or the documented default ────────────────
registry_budget() {  # → the number, or empty when the registry cannot answer
  local home="" reg="" out=""
  command -v python3 >/dev/null 2>&1 || return 0
  if command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root home 2>/dev/null; fi
  home="${home:-${YMIR_HOME:-}}"
  [ -n "$home" ] || return 0
  reg="${YMIR_FLEET_REGISTRY:-$home/hodd/data/fleet.json}"
  [ -r "$reg" ] || return 0
  out="$(YMIR_THIS_HOST="$HERE" python3 - "$reg" <<'PY' 2>/dev/null
import json, os, sys
try:
    doc = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
row = (doc.get("hosts") or {}).get(os.environ.get("YMIR_THIS_HOST", ""))
if not isinstance(row, dict):
    sys.exit(0)
v = row.get("builders")
if v is None or isinstance(v, bool):
    sys.exit(0)
print(v)
PY
)"
  printf '%s' "$out"
}

BUDGET=""; BUDGET_SRC=""
resolve_budget() {
  local n="" src=""
  if [ -n "${YMIR_BUILDER_BUDGET:-}" ]; then
    n="${YMIR_BUILDER_BUDGET}"; src="env YMIR_BUILDER_BUDGET"
  else
    n="$(registry_budget)"
    src="the fleet registry's own row (hosts.${HERE}.builders)"
  fi
  case "$n" in
    '')                BUDGET=""; BUDGET_SRC="unreadable"; return 1 ;;
    *[!0-9]*)          BUDGET=""; BUDGET_SRC="not a number (${n})"; return 1 ;;
  esac
  [ "$n" -ge 1 ] 2>/dev/null || { BUDGET=""; BUDGET_SRC="not a positive number (${n})"; return 1; }
  BUDGET="$n"; BUDGET_SRC="$src"
  return 0
}

# ── the builders: agents standing in a worktree, from the one reader of seats ─
STANDING=""; STANDING_WHY=""
count_builders() {
  local door="${YMIR_AGENT_LIST_DOOR:-$ROOT/bin/seat/herdr-agents.py}" listing=""
  if [ -x "$door" ]; then
    listing="$("$door" --tsv 2>/dev/null)"
  fi
  if [ -z "$listing" ]; then
    STANDING=""; STANDING_WHY="herdr cannot say — no agent list answered"; return 1
  fi
  STANDING="$(printf '%s\n' "$listing" | awk -F'\t' 'NF>=7 && $7 ~ /\/\.yggdrasil\// {n++} END {print n+0}')"
  STANDING_WHY="agents standing in a Yggdrasil worktree, per herdr agent list"
  return 0
}

rows() {  # the builders, named — a reader can see WHICH seats the count is made of
  local door="${YMIR_AGENT_LIST_DOOR:-$ROOT/bin/seat/herdr-agents.py}"
  [ -x "$door" ] || return 0
  "$door" --tsv 2>/dev/null | awk -F'\t' 'NF>=7 && $7 ~ /\/\.yggdrasil\// {
      n=split($7,p,"/"); er="";
      for (i=1;i<=n;i++) if (p[i]==".yggdrasil" && i<n) er=p[i+1];
      printf "  \"%s\",\"%s\",\"%s\"\n", $1, $2, (er=="" ? p[n] : er) }'
}

# ── verbs ────────────────────────────────────────────────────────────────────
VERB="${1:-status}"; shift || true
JSON_FLAG=0
case "${1-}" in --json) JSON_FLAG=1 ;; esac
case "$VERB" in
  -h|--help|help) usage; exit 0 ;;
  -v|-V|--version) printf 'builder-budget %s\n' "$BUDGET_VERSION"; exit 0 ;;
  read) ;;
  status) ;;
  check) ;;
  *) die "unknown verb $VERB — read | status | check" 2 ;;
esac

if [ "$VERB" = "read" ]; then
  if resolve_budget; then
    say "budget[2]{host,builders}:"
    say "  \"$HERE\",\"$BUDGET\""
    say "source,$BUDGET_SRC"
    exit 0
  fi
  say "budget[2]{host,builders}:"
  say "  \"$HERE\",\"unknown\""
  say "source,$BUDGET_SRC"
  exit 4
fi

resolve_budget || true
count_builders || true

if [ "$JSON_FLAG" = 1 ]; then
  printf '{"host":"%s","budget":%s,"builders":%s,"known":%s}\n' \
    "$HERE" "${BUDGET:-null}" "${STANDING:-null}" \
    "$([ -n "$BUDGET" ] && [ -n "$STANDING" ] && echo true || echo false)"
  [ -n "$BUDGET" ] && [ -n "$STANDING" ] || exit 4
  [ "$STANDING" -lt "$BUDGET" ] && exit 0
  exit 3
fi

say "budget[1]{host,builders,source}:"
say "  \"$HERE\",\"${BUDGET:-unknown}\",\"$BUDGET_SRC\""
if [ -z "$STANDING" ]; then
  say "standing[1]{count,why}:"
  say "  \"unknown\",\"$STANDING_WHY\""
  say "detail,nothing is claimed,a count nobody measured is not a budget"
  exit 4
fi
say "standing[1]{count,why}:"
say "  \"$STANDING\",\"$STANDING_WHY\""
if [ -z "$BUDGET" ]; then
  say "detail,no budget is recorded for this machine,so nothing is judged — say the number (hosts.${HERE}.builders) and it is enforced"
  exit 4
fi
if [ "$STANDING" -gt 0 ]; then
  say "builders[${STANDING}]{pane,state,errand}:"
  rows
fi
room=$((BUDGET - STANDING))
if [ "$room" -gt 0 ]; then
  say "room,$room,this machine may take ${room} more builder(s)"
  exit 0
fi
say "room,$room,the budget of ${BUDGET} builder(s) on this machine is full"
if [ "$room" -eq 0 ]; then
  say "detail,at the budget,a new builder should wait for one to finish, not be seated beside it"
fi
exit 3

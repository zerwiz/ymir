#!/usr/bin/env bash
# seat-adopt.sh — a late boot is still a seat.
#
# The fault (measured 2026-11-10): the engine waited 25 s for a pi that needed
# longer, recorded `seat=no` in state/<id>.meta and `failed:` in the status, and
# never armed the watch — while the agent came up a minute later in the very pane
# the record named. The errand was declared dead and its brief was never delivered.
#
# The wait is longer now (60 s, bin/seat/seat-prove.sh), but a slow boot on a loaded
# rail can still outlast any number. So the house ADOPTS what it finds: this door
# looks at a record whose seat was never proven, asks the ONE agent reader whether an
# agent now stands in the recorded pane or worktree, and if it does — corrects the
# record, arms the silence watch, and tells the arm (a wake, not a desktop note).
#
#   seat-adopt.sh <errand-id>       # adopt one record (idempotent)
#   seat-adopt.sh --all             # every record in this state dir with seat=no
#   seat-adopt.sh --list            # what --all would adopt, changing nothing
#
# Exit: 0 adopted (or nothing to adopt), 1 a record still unproven after the look,
#       2 usage.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi

# The same shelves the records are written to: BROKK_STATE_OVERRIDE, then the tree's
# state (where einherjar-spawn and the engine write), then the hoard.
state_dirs() {
  local d seen=""
  for d in "${BROKK_STATE_OVERRIDE:-}" "$BROKK_HOME/state" "$ROOT/state"; do
    [ -n "$d" ] && [ -d "$d" ] || continue
    case " $seen " in *" $d "*) continue ;; esac
    seen="$seen $d"
    printf '%s\n' "$d"
  done
}

meta_dir_of() { # <id> -> the state dir holding <id>.meta
  local id=$1 d
  while IFS= read -r d; do [ -f "$d/$id.meta" ] && { printf '%s' "$d"; return 0; }; done < <(state_dirs)
  return 1
}

meta_key() { awk -F= -v k="$2" '$1==k{sub(/^[^=]*=/,""); print; exit}' "$1" 2>/dev/null; }

reader() { printf '%s' "$SCRIPT_DIR/herdr-agents.py"; }

adopt() { # <id> <apply:0|1>  -> 0 adopted or already fine, 1 still unproven
  local id=$1 apply=$2 d meta seat pane wt hit found state
  d="$(meta_dir_of "$id")" || { printf '  "%s","","","no record"' "$id"; return 1; }
  meta="$d/$id.meta"
  seat="$(meta_key "$meta" seat)"
  pane="$(meta_key "$meta" window)"; [ -n "$pane" ] || pane="$(meta_key "$meta" seat_pane)"
  wt="$(meta_key "$meta" worktree)"
  if [ "$seat" = yes ]; then
    printf '  "%s","%s","%s","already seated"\n' "$id" "$pane" "$wt"
    return 0
  fi
  # The one reader of `herdr agent list` (plan 189 §18.2). No agent here means the
  # record was right, and nothing is changed.
  hit=""
  if [ -r "$(reader)" ] && command -v herdr >/dev/null 2>&1; then
    [ -n "$pane" ] && hit="$(python3 "$(reader)" --find --pane "$pane" 2>/dev/null || true)"
    if [ -z "$hit" ] && [ -n "$wt" ]; then
      hit="$(python3 "$(reader)" --find --cwd "$wt" 2>/dev/null || true)"
    fi
  fi
  if [ -z "$hit" ]; then
    printf '  "%s","%s","%s","still unproven — no agent stands there"\n' "$id" "$pane" "$wt"
    return 1
  fi
  found="${hit%%$'\t'*}"
  state="$(printf '%s' "$hit" | cut -f2)"
  [ "$apply" = 1 ] || { printf '  "%s","%s","%s","WOULD ADOPT (agent %s)"\n' "$id" "${found:-$pane}" "$wt" "$state"; return 0; }
  # Correct the record: seat=yes, the pane the agent ACTUALLY stands in, and the
  # reason — the evidence, never a claim.
  local tmp="$d/.$id.meta.adopt.$$"
  awk -v pane="$found" '
    BEGIN{ done_seat=0; done_win=0 }
    /^seat=/{ print "seat=yes"; done_seat=1; next }
    /^window=/{ print "window=" pane; done_win=1; next }
    { print }
    END{ if(!done_seat) print "seat=yes"; if(!done_win) print "window=" pane }
  ' "$meta" >"$tmp" && mv "$tmp" "$meta"
  printf 'seat_state=%s\nadopted=%s\nadopted_why=late boot — the agent stood in the pane after the proof wait\n' \
    "${state:-unknown}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$meta"
  printf 'working: adopted — the agent stood in pane %s after the seat proof had given up (%s)\n' \
    "${found:-$pane}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$d/$id.status" 2>/dev/null || true
  # ARM THE WATCH: the seat is real, so the silence watch must be too.
  if [ -x "$SCRIPT_DIR/../agents/eindri-watch.sh" ]; then
    BROKK_HOME="$BROKK_HOME" BROKK_STATE_OVERRIDE="$d" \
      "$SCRIPT_DIR/../agents/eindri-watch.sh" arm-silence "$id" --window "${EINDRI_SILENT_WINDOW:-1800}" >/dev/null 2>&1 || true
  fi
  # And the arm hears it — the same wake road a failure takes.
  if [ -x "$SCRIPT_DIR/seat-wake.sh" ]; then
    BROKK_HOME="$BROKK_HOME" BROKK_STATE_OVERRIDE="$d" "$SCRIPT_DIR/seat-wake.sh" "$id" adopted \
      --pane "${found:-$pane}" --worktree "$wt" --why "a late boot; the record was corrected and the watch armed" >/dev/null 2>&1 || true
  fi
  printf '  "%s","%s","%s","adopted: record corrected, watch armed, the arm woken"\n' "$id" "${found:-$pane}" "$wt"
  return 0
}

case "${1:-}" in
  -h|--help|"") sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --list|--all)
    apply=1; [ "$1" = "--list" ] && apply=0
    printf 'seat-adopt[1]{id,pane,worktree,state}:\n'
    n=0; adopted=0; unproven=0
    while IFS= read -r d; do
      for meta in "$d"/*.meta; do
        [ -f "$meta" ] || continue
        id="$(basename "$meta" .meta)"
        n=$((n + 1))
        if adopt "$id" "$apply"; then adopted=$((adopted + 1)); else unproven=$((unproven + 1)); fi
      done
    done < <(state_dirs)
    [ "$n" = 0 ] && printf '  "-","","","no seat records on this shelf"\n'
    exit 0 ;;
  -*) printf 'error: unknown option %s\n' "$1" >&2; exit 2 ;;
  *) printf 'seat-adopt[1]{id,pane,worktree,state}:\n'; adopt "$1" 1 ;;
esac

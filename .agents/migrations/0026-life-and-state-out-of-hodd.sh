#!/usr/bin/env bash
# 0026-life-and-state-out-of-hodd — the operator's material and runtime state leave the record (plan 331.2).
#
# The home has four shelves (plan 331): `hodd/` is the RECORD, `life/` is the operator's own material,
# `state/` is runtime state written by supervisors, `config/` is settings. Homes made before that rule keep
# `hodd/life/`, `hodd/state/` and `hodd/workspaces/<topic>/` inside the record. This migration moves them:
#
#   hodd/life/*                      -> life/
#   hodd/state/*                     -> state/
#   hodd/workspaces/<topic>/*        -> life/<topic>/   for topic in personal work marketing meetings outreach
#
# and then leaves a ONE-CYCLE COMPATIBILITY SYMLINK (plan 331.7): `hodd/life -> ../life` and
# `hodd/state -> ../state`. Thousands of files still name the old paths; with the link they keep working
# and land in the right shelf, so a writer that still says `hodd/state/garmr` writes into `state/garmr`.
# The links are per machine and git-ignored — never committed, because a pull on another seat could not
# replace a directory that still holds ignored files with a link.
#
# THE LAW (RULES/06, RULES/11):
#   * the record is written FIRST — `hodd/reference/moves/<date>-0026-life-and-state-out-of-hodd.md`
#     lists every planned move before the first one happens, so a crash leaves evidence;
#   * nothing is deleted and nothing is overwritten — a name already present at the destination is kept
#     beside it as `<name>.from-hodd` (then `.from-hodd-2`, …);
#   * tracked files move with `git mv`, so their history follows; untracked and ignored files move with `mv`;
#   * the file count over the shelves it touches is measured before and after, and must be equal;
#   * one line per move, and a final count.
#
# Idempotent: a second run finds nothing to move, sees the links already in place, and says so.
#   bash .agents/migrations/0026-life-and-state-out-of-hodd.sh            # apply
#   bash .agents/migrations/0026-life-and-state-out-of-hodd.sh --dry-run  # name every move, touch nothing
# Exit 0 done or nothing to do · 1 the count did not match (stop, read the record) · 3 deferred.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRY=0
for a in "$@"; do case "$a" in --dry-run|-n) DRY=1 ;; esac; done

# The operator's home, through the ONE resolver (Rule 07).
# shellcheck source=bin/vault/hoard-lib.sh
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
H=""
command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root H
[ -n "$H" ] || H="${YMIR_HOME:-}"
[ -n "$H" ] || { echo "0026: no home resolved — nothing touched"; exit 0; }
[ -f "$H/hodd/memory/runes_audit.md" ] || {
  echo "0026: $H is not a Ymir home (no hodd/memory/runes_audit.md) — nothing touched"; exit 0; }

say() { printf '0026-life-and-state-out-of-hodd: %s\n' "$*"; }
TOPICS="personal work marketing meetings outreach"
IS_GIT=0
git -C "$H" rev-parse --is-inside-work-tree >/dev/null 2>&1 && IS_GIT=1

# ── what is there to do? ───────────────────────────────────────────────────────
# A source counts only when it is a REAL directory: the link this migration leaves behind is the
# finished state, never work.
real_dir() { [ -d "$1" ] && [ ! -L "$1" ]; }
PAIRS=()   # "<source>|<destination>" relative to the home
real_dir "$H/hodd/life"  && PAIRS+=("hodd/life|life")
real_dir "$H/hodd/state" && PAIRS+=("hodd/state|state")
for t in $TOPICS; do
  real_dir "$H/hodd/workspaces/$t" && PAIRS+=("hodd/workspaces/$t|life/$t")
done
NEED_LINK=()
for l in life state; do
  [ -L "$H/hodd/$l" ] || NEED_LINK+=("$l")
done

if [ "${#PAIRS[@]}" -eq 0 ] && [ "${#NEED_LINK[@]}" -eq 0 ]; then
  say "nothing to do — hodd/life and hodd/state are the compatibility links, no topic is left under hodd/workspaces"
  exit 0
fi

# ── the count over every shelf this run touches (never through a link) ─────────
count_files() {
  local n=0 d c
  for d in hodd/life hodd/state hodd/workspaces life state; do
    real_dir "$H/$d" || continue
    c=$(find "$H/$d" -type f 2>/dev/null | wc -l)
    n=$((n + c))
  done
  printf '%s' "$n"
}

if [ "$DRY" = 1 ]; then
  for p in "${PAIRS[@]}"; do say "would move  ${p%%|*}/*  →  ${p#*|}/   ($(find "$H/${p%%|*}" -type f | wc -l) files)"; done
  for l in "${NEED_LINK[@]}"; do say "would link  hodd/$l  →  ../$l   (one-cycle compatibility shim)"; done
  exit 0
fi

BEFORE=$(count_files)
STAMP="$(date -u +%Y-%m-%d)"
REC_DIR="$H/hodd/reference/moves"
REC="$REC_DIR/$STAMP-0026-life-and-state-out-of-hodd.md"
mkdir -p "$REC_DIR"
NEW_REC=1; [ -f "$REC" ] && NEW_REC=0   # decided before the redirect below creates the file

# ── the record FIRST ───────────────────────────────────────────────────────────
{
  [ "$NEW_REC" = 0 ] || printf '# 0026 — the operator'"'"'s material and runtime state leave the record\n\nWritten by `.agents/migrations/0026-life-and-state-out-of-hodd.sh` (plan 331.2) before it moved anything.\nThe rule: `hodd/` is the record, `life/` the operator'"'"'s material, `state/` runtime state, `config/` settings.\n'
  printf '\n## Run %s on %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(hostname 2>/dev/null || echo this-machine)"
  printf 'Files on the touched shelves before the run: **%s**.\n\nPlanned:\n\n' "$BEFORE"
  for p in "${PAIRS[@]}"; do printf -- '- move `%s/*` into `%s/`\n' "${p%%|*}" "${p#*|}"; done
  for l in "${NEED_LINK[@]}"; do printf -- '- link `hodd/%s` → `../%s` (one cycle)\n' "$l" "$l"; done
  printf '\nMoves (a clash keeps the incoming name as `<name>.from-hodd`):\n\n'
} >>"$REC"

MOVED=0; CLASH=0
note() { printf -- '- %s\n' "$*" >>"$REC"; }

tracked() { [ "$IS_GIT" = 1 ] && [ -n "$(git -C "$H" ls-files -- "$1" 2>/dev/null | head -1)" ]; }

# move_one <from-rel> <to-rel> — git mv when it carries tracked files, mv otherwise; never clobbers.
move_one() {
  local from="$1" to="$2"
  mkdir -p "$H/$(dirname "$to")"
  if tracked "$from"; then
    git -C "$H" mv -k -- "$from" "$to" 2>/dev/null
    # git mv moves only what it knows; anything untracked left behind follows by plain mv
    if [ -e "$H/$from" ] && [ ! -e "$H/$to" ]; then mv -- "$H/$from" "$H/$to"; fi
    if [ -d "$H/$from" ] && [ -d "$H/$to" ]; then merge "$from" "$to"; return; fi
  else
    mv -- "$H/$from" "$H/$to"
  fi
}

free_name() {  # <to-rel> -> a name beside it that is not taken
  local base="$1.from-hodd" n=2 cand
  cand="$base"
  while [ -e "$H/$cand" ] || [ -L "$H/$cand" ]; do cand="$base-$n"; n=$((n + 1)); done
  printf '%s' "$cand"
}

# merge <from-rel> <to-rel> — fold a directory in, one entry at a time.
merge() {
  local from="$1" to="$2" e name t alt
  mkdir -p "$H/$to"
  for e in "$H/$from"/* "$H/$from"/.[!.]* "$H/$from"/..?*; do
    [ -e "$e" ] || [ -L "$e" ] || continue
    name="$(basename "$e")"; t="$to/$name"
    if [ ! -e "$H/$t" ] && [ ! -L "$H/$t" ]; then
      move_one "$from/$name" "$t"
      say "move  $from/$name  →  $t"; note "\`$from/$name\` → \`$t\`"; MOVED=$((MOVED + 1))
    elif real_dir "$e" && real_dir "$H/$t"; then
      merge "$from/$name" "$t"
    else
      alt="$(free_name "$t")"
      move_one "$from/$name" "$alt"
      say "keep  $from/$name  →  $alt   ($t already exists)"; note "\`$from/$name\` → \`$alt\` (clash: \`$t\` kept as it was)"
      MOVED=$((MOVED + 1)); CLASH=$((CLASH + 1))
    fi
  done
  rmdir "$H/$from" 2>/dev/null || true
}

for p in "${PAIRS[@]}"; do merge "${p%%|*}" "${p#*|}"; done
# an emptied hodd/workspaces is a shell, not a shelf; anything else in it is left for a person
rmdir "$H/hodd/workspaces" 2>/dev/null || true
if [ -d "$H/hodd/workspaces" ]; then
  left="$(ls -A "$H/hodd/workspaces" | tr '\n' ' ')"
  say "left  hodd/workspaces/{ ${left}}  — not one of the five topics; a person decides where it goes"
  note "left for a person: \`hodd/workspaces/\` still holds: ${left}"
fi

# ── the one-cycle compatibility links ───────────────────────────────────────────
# A supervisor may write into hodd/state between the merge and the link; merge again and retry.
link_shelf() {
  local l="$1" try
  for try in 1 2 3 4 5; do
    [ -L "$H/hodd/$l" ] && return 0
    if real_dir "$H/hodd/$l"; then merge "hodd/$l" "$l"; fi
    [ -e "$H/hodd/$l" ] || ln -s "../$l" "$H/hodd/$l" 2>/dev/null
  done
  [ -L "$H/hodd/$l" ]
}
DEFERRED=0
for l in life state; do
  mkdir -p "$H/$l"
  if [ -L "$H/hodd/$l" ]; then continue; fi
  if link_shelf "$l"; then
    say "link  hodd/$l  →  ../$l   (one cycle; retire with plan 331.7)"; note "linked \`hodd/$l\` → \`../$l\`"
  else
    say "could not link hodd/$l — a writer keeps recreating it; run again when it is quiet"
    note "DEFERRED: \`hodd/$l\` could not be replaced by its link"; DEFERRED=1
  fi
done

# the links are per machine: git-ignored, never committed
if [ "$IS_GIT" = 1 ]; then
  for l in life state; do
    grep -qxF "/hodd/$l" "$H/.gitignore" 2>/dev/null || {
      printf '%s\n' "# 0026: the one-cycle compatibility link (plan 331.7) — per machine, never committed" "/hodd/$l" >>"$H/.gitignore"
      say "ignore /hodd/$l  (the link is per machine)"; }
  done
fi

AFTER=$(count_files)
printf '\nAfter: **%s** files (before **%s**); %s entries moved, %s kept beside a clash.\n' \
  "$AFTER" "$BEFORE" "$MOVED" "$CLASH" >>"$REC"
say "count  before $BEFORE  after $AFTER  · moved $MOVED · clashes $CLASH · record ${REC#"$H"/}"
if [ "$AFTER" != "$BEFORE" ]; then
  say "THE COUNT DID NOT MATCH — stop and read the record; nothing further runs"
  printf '\n**The count did not match.** A person must look before anything else moves.\n' >>"$REC"
  exit 1
fi
[ "$DEFERRED" = 1 ] && exit 3
[ "$IS_GIT" = 1 ] && say "stage and ship by name: bin/vault/home-sync.sh ship \"<msg>\" .gitignore ${REC#"$H"/} <the moved paths>"
exit 0

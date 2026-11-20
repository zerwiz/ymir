#!/usr/bin/env bash
# home-sync.sh — the one door for editing the home: pull first, ship right after (RULES/50).
#
# The home ($YMIR_HOME, a private git repo) is written by every seat in the fleet and by
# their crons. A seat that edits on a stale tree, or commits and leaves the commit local,
# is how 1,077 conflicts and three plan-number collisions happened in one hour on
# 2026-11-10. So every edit is a short window: BEGIN (fetch + merge origin) → edit →
# SHIP (commit named paths, merge origin again, push, retry on a lost race).
#
#   home-sync.sh begin                   # fetch + merge origin/main; refuse on a real conflict
#   home-sync.sh ship "<msg>" <path>…    # begin, stage NAMED paths, commit, push (retries)
#   home-sync.sh ship --dry-run "<msg>" <path>…   # show what would be staged; touch nothing
#   home-sync.sh status                  # ahead / behind / dirty, one TOON row
#   home-sync.sh setup                   # seat the merge drivers and the mail redaction filter
#   home-sync.sh filter-check <path>…    # does this seat redact every named path? (exit 1 when not)
#
# Laws carried here, each from an older rule:
#   - named paths only, never `git add -A` (Rule 04 staging discipline)
#   - never delete a tracked file (Rule 11) and never force-push (Rule 45)
#   - append-only records merge by UNION through .gitattributes (Rule 06) — never by hand
#   - a real conflict is refused with the names, never resolved silently
#   - the mail spine is REDACTED by a clean filter, and git config does not travel: `setup` seats
#     it and `ship` REFUSES the spine on a seat without it (plan 116 §18, RULES/24)
#
# Env: YMIR_HOME (via hoard-lib) · HOME_SYNC_REMOTE (origin) · HOME_SYNC_BRANCH (main)
#      HOME_SYNC_TRIES (5) · YMIR_OFFLINE=1 (a stated skip of the fetch, Rule 25)
# Exit: 0 ok · 1 failed · 2 usage · 3 conflict refused (the tree is left as it was)
set -uo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REMOTE="${HOME_SYNC_REMOTE:-origin}"
BRANCH="${HOME_SYNC_BRANCH:-main}"
TRIES="${HOME_SYNC_TRIES:-5}"

usage() { sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; }
case "${1-}" in "") usage >&2; exit 2 ;; -h|--help) usage; exit 0 ;; -v|--version) echo "$VERSION"; exit 0 ;; esac

hoard="$(bash "$ROOT/bin/vault/hodd.sh" path 2>/dev/null || true)"
[ -n "$hoard" ] || { echo "home-sync: no home (YMIR_HOME unresolved)" >&2; exit 1; }
HOME_DIR="$(dirname "$hoard")"
g() { git -C "$HOME_DIR" "$@"; }
g rev-parse --git-dir >/dev/null 2>&1 || { echo "home-sync: $HOME_DIR is not a git repo" >&2; exit 1; }

setup() {
  # `merge=ours` is not built in; it needs a driver per clone. union is built in.
  [ "$(g config --get merge.ours.driver 2>/dev/null)" = "true" ] || g config merge.ours.driver true
  seat_redaction
}

# ── the redaction filter is SEATED, not remembered (2026-11-20, plan 116 §18) ────────────────────
# The mail spine travels with the home (the Allfather, 2026-11-20), so a credential is kept out of
# git by a CLEAN FILTER: `.gitattributes` says `hodd/memory/mail/messages.jsonl filter=gna-redact`,
# and the filter is `hodd/bin/mail-redact.py`. Git config does NOT travel with a clone, so a seat
# that only pulled the home had the attribute, no filter, and would have committed RAW mail with
# passwords in it — the filter was seated by hand on one machine and nowhere else. It is seated
# here, in the same door that already seats the merge driver, and `ship` refuses the spine on a
# seat where it is not configured (check_filtered).
REDACT_NAME="gna-redact"
REDACT_SCRIPT="hodd/bin/mail-redact.py"
seat_redaction() {
  [ -f "$HOME_DIR/$REDACT_SCRIPT" ] || return 0
  local want="python3 $REDACT_SCRIPT"
  [ "$(g config --get "filter.$REDACT_NAME.clean" 2>/dev/null)" = "$want" ] \
    || g config "filter.$REDACT_NAME.clean" "$want"
  [ "$(g config --get "filter.$REDACT_NAME.smudge" 2>/dev/null)" = "cat" ] \
    || g config "filter.$REDACT_NAME.smudge" cat
  # `required` is the half that matters: without it git commits the file UNFILTERED when the
  # script fails, which is the accident this door exists to make impossible.
  [ "$(g config --get "filter.$REDACT_NAME.required" 2>/dev/null)" = "true" ] \
    || g config "filter.$REDACT_NAME.required" true
}

# check_filtered <path>… — print each named path this seat would commit UNREDACTED.
# The attribute is read from .gitattributes by git itself (`check-attr`), never from a list here,
# so a newly filtered path is covered the day its attribute is added.
check_filtered() {
  local p f
  for p in "$@"; do
    f="$(g check-attr filter -- "$p" 2>/dev/null | sed 's/.*: //')"
    case "$f" in ''|unspecified|unset) continue ;; esac
    if [ -z "$(g config --get "filter.$f.clean" 2>/dev/null)" ]; then
      printf '  %s — filter.%s.clean is not configured\n' "$p" "$f"; continue
    fi
    [ "$(g config --get "filter.$f.required" 2>/dev/null)" = true ] \
      || printf '  %s — filter.%s.required is not true (git would commit it unfiltered on a failure)\n' "$p" "$f"
  done
}

fetch() {
  if [ "${YMIR_OFFLINE:-0}" = 1 ]; then echo "home-sync: YMIR_OFFLINE=1 — base UNVERIFIED (skip fetch)" >&2; return 0; fi
  g fetch -q "$REMOTE" "$BRANCH" 2>/dev/null || { echo "home-sync: fetch failed — base UNVERIFIED" >&2; return 1; }
}

merge_origin() {
  # One merge, not a rebase: a rebase replays every local commit and can hit the same
  # append-only file N times; a merge resolves it once, and union attributes make most
  # of those resolutions automatic.
  local behind; behind="$(g rev-list --count "HEAD..$REMOTE/$BRANCH" 2>/dev/null || echo 0)"
  [ "$behind" -gt 0 ] || return 0
  if ! g merge -q --no-edit "$REMOTE/$BRANCH" >/dev/null 2>&1; then
    local conflicted; conflicted="$(g diff --name-only --diff-filter=U 2>/dev/null)"
    if [ -n "$conflicted" ]; then
      g merge --abort >/dev/null 2>&1 || true
      printf 'home-sync[conflict]{file}:\n' >&2
      printf '%s\n' "$conflicted" | sed 's/^/  "/;s/$/"/' >&2
      printf 'home-sync: %s behind and the merge conflicts — refused, tree unchanged. Resolve by the conflict law (union append-only, regenerate generated, renumber numbers) and retry.\n' "$behind" >&2
      return 3
    fi
    echo "home-sync: merge of $REMOTE/$BRANCH failed (a dirty file overlaps the incoming change?)" >&2
    g merge --abort >/dev/null 2>&1 || true
    return 1
  fi
}

begin() { setup; fetch || true; merge_origin; }

status() {
  fetch >/dev/null 2>&1 || true
  local a b d
  a="$(g rev-list --count "$REMOTE/$BRANCH..HEAD" 2>/dev/null || echo '?')"
  b="$(g rev-list --count "HEAD..$REMOTE/$BRANCH" 2>/dev/null || echo '?')"
  d="$(g status --porcelain --untracked-files=no | wc -l | tr -d ' ')"
  printf 'home-sync[1]{home,ahead,behind,dirty_tracked}:\n  "%s",%s,%s,%s\n' "$HOME_DIR" "$a" "$b" "$d"
}

ship() {
  if [ "${1-}" = "--dry-run" ]; then
    shift; local m="${1:-}"; shift || true
    [ -n "$m" ] && [ $# -gt 0 ] || { echo 'usage: home-sync.sh ship --dry-run "<message>" <path> [path…]' >&2; exit 2; }
    printf 'dry run — nothing staged, nothing committed, nothing pushed.\n  home: %s\n  message: %s\n  paths:\n' "$HOME_DIR" "$m"
    printf '    %s\n' "$@"
    printf '  what git would stage:\n'; g status --porcelain -- "$@" | sed 's/^/    /'
    local raw; raw="$(check_filtered "$@")"
    if [ -n "$raw" ]; then
      printf '  WARNING — a filtered path with no filter on this seat:\n%s\n' "$raw"
      printf '  a real ship would REFUSE (run home-sync.sh setup first)\n'
    fi
    return 0
  fi
  local msg="${1:-}"; shift || true
  [ -n "$msg" ] && [ $# -gt 0 ] || { echo 'usage: home-sync.sh ship "<message>" <path> [path…]' >&2; exit 2; }
  local p
  for p in "$@"; do
    if [ ! -e "$HOME_DIR/$p" ] && g ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
      echo "home-sync: refusing to delete tracked $p (Rule 11 — retire by moving)" >&2; exit 1
    fi
  done
  # A FILTERED PATH ON A SEAT WITH NO FILTER IS RAW DATA IN GIT. Refuse before staging anything.
  local raw; raw="$(check_filtered "$@")"
  if [ -n "$raw" ]; then
    printf 'home-sync: refusing to stage a path this seat cannot redact — raw mail would travel:\n%s\n' "$raw" >&2
    printf 'help: run `home-sync.sh setup` (it seats filter.%s from %s), then ship again\n' "$REDACT_NAME" "$REDACT_SCRIPT" >&2
    exit 1
  fi
  begin; local rc=$?; [ "$rc" = 0 ] || exit "$rc"
  g add -- "$@" || { echo "home-sync: git add failed" >&2; exit 1; }
  if g diff --cached --quiet; then echo "home-sync: nothing staged in the named paths"; else
    g commit -q -m "$msg" || { echo "home-sync: commit refused (a guard?) — see above" >&2; exit 1; }
  fi
  local i=1
  while [ "$i" -le "$TRIES" ]; do
    if g push -q "$REMOTE" "HEAD:$BRANCH" 2>/dev/null; then
      printf 'home-sync: shipped %s path(s) to %s/%s (try %s)\n' "$#" "$REMOTE" "$BRANCH" "$i"
      # a shipped plan's card follows it onto the board (plan 335); paths that are not plans are ignored there
      ( cd "$HOME_DIR" && YMIR_HOME="$HOME_DIR" bash "$ROOT/bin/boards/plan-card-after.sh" "$@" ) 2>/dev/null || true
      return 0
    fi
    # Lost the race: another seat pushed between our fetch and our push. Merge, retry.
    sleep "$(( (RANDOM % 3) + i ))"
    fetch || true
    merge_origin; rc=$?; [ "$rc" = 0 ] || exit "$rc"
    i=$((i+1))
  done
  echo "home-sync: push still rejected after $TRIES tries — the commit is local; run 'home-sync.sh ship' again" >&2
  exit 1
}

cmd="$1"; shift
case "$cmd" in
  begin)  begin; exit $? ;;
  ship)   ship "$@" ;;
  status) status ;;
  setup)  setup; echo "home-sync: merge.ours.driver and filter.$REDACT_NAME seated in $HOME_DIR" ;;
  filter-check)
    [ $# -gt 0 ] || { echo 'usage: home-sync.sh filter-check <path> [path…]' >&2; exit 2; }
    raw="$(check_filtered "$@")"
    if [ -n "$raw" ]; then printf 'home-sync[unfiltered]{path}:' ; printf '\n'; printf '%s\n' "$raw"; exit 1; fi
    echo "home-sync: every named path is filtered on this seat" ;;
  *) echo "error: unknown action $cmd" >&2; usage >&2; exit 2 ;;
esac

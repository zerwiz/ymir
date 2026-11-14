#!/usr/bin/env bash
# saga-land-warnings.sh — Sága's eye on work that finished and never landed.
#
# WHY (plan 293 part 3, 2026-11-14). The audit of 36 agent panes found 22 worker branches pushed,
# clean, with fix notes, and only four merged: nothing gathered them and nothing closed the panes.
# A branch is safe the moment it is on origin, but a pushed branch no PR carries is work nobody
# will ever review — it rots while it waits, and the older ones were 41 to 65 commits behind within
# hours. And one machine's own local `main` held 19 commits that existed on NO remote at all: a
# seat's work could go with the disk. Neither fact was anywhere in the session start.
#
# So the digest asks three questions, measured against origin and never against a local branch:
#
#   no-pr      is a worker branch pushed, older than a few hours, and carrying no pull request —
#              or a PR that was closed without a merge? It is named, with its age.
#   in-pr      is it riding INSIDE an open pull request? The gather merges a batch's branches into
#              one batch branch, so an errand's own head has no PR of its own; naming that as lost
#              work is a false alarm (measured live 2026-11-14, four branches). It is named with
#              the PR that carries it, and nothing is asked of the helm.
#   unpushed   does any local branch (main included) hold commits on no remote? They are counted
#              and the branches are named, so a hand can push them before they are lost.
#
# READ-ONLY AND CHEAP. Nothing is fetched, pushed or written; the remote-tracking refs are read as
# they stand, and each measurement is time-bounded. Offline is a clean sentence, never a hang and
# never a false green: `gh` is asked ONCE, with a deadline, for every branch's PR state.
#
# Usage: bin/time/saga-land-warnings.sh            # the digest's rows (a section body)
#        bin/time/saga-land-warnings.sh --check    # the same rows; always exit 0 (a warning is not a fault)
#
# Env (all optional):
#   SAGA_LAND_REPO            the checkout to measure (default: this tree's MAIN checkout)
#   SAGA_LAND_REMOTE          the remote (default origin)
#   SAGA_LAND_BASE            the base branch (default main)
#   SAGA_LAND_MIN_AGE_HOURS   "a few hours" (default 4)
#   SAGA_LAND_BRANCHES        the worker prefixes, space separated (default: eindri agent claude)
#   SAGA_LAND_GH              the gh door (default gh); point it at a missing name to prove the offline path
#   SAGA_LAND_BOUND           seconds any one measurement may take (default 12)
#   SAGA_LAND_ROWS            rows per finding before it says how many it folded (default 6)
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERE="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"

case "${1-}" in
  -h|--help) sed -n '2,44p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
esac

REMOTE="${SAGA_LAND_REMOTE:-origin}"
BASE="${SAGA_LAND_BASE:-main}"
MIN_HOURS="${SAGA_LAND_MIN_AGE_HOURS:-4}"
PREFIXES="${SAGA_LAND_BRANCHES:-eindri agent claude}"
GH_CMD="${SAGA_LAND_GH:-gh}"
BOUND="${SAGA_LAND_BOUND:-12}"
ROWS_MAX="${SAGA_LAND_ROWS:-6}"

# A worktree shares its refs with its main checkout; measure the main checkout, and let a test
# name its own fixture instead.
COMMON="$(git -C "$HERE" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
REPO="${SAGA_LAND_REPO:-$( [ -n "$COMMON" ] && dirname "$COMMON" || printf '%s' "$HERE" )}"

# `timeout` is not on every platform (Rule 05: a GNU-only caller may FALL, never rise). Where it is
# absent the measurement still runs; the bound is then the tool's own.
HAVE_TIMEOUT=0
command -v timeout >/dev/null 2>&1 && HAVE_TIMEOUT=1
bounded() { # <seconds> <command...>
  local secs=$1; shift
  if [ "$HAVE_TIMEOUT" = 1 ]; then timeout "$secs" "$@"; else "$@"; fi
}

now="$(date +%s)"
case "$now" in ''|*[!0-9]*) now=0 ;; esac
carried_reach=""
trap '[ -n "${carried_reach:-}" ] && rm -f "$carried_reach"' EXIT

row() { printf '  "%s","%s","%s"\n' "$1" "$(clean "$2")" "$(clean "$3")"; }
clean() { printf '%s' "$1" | tr '\n\t' '  ' | tr -d '"' | sed 's/  */ /g; s/^ //; s/ $//'; }
q() { git -C "$REPO" "$@"; }

# ── can anything be measured at all ──────────────────────────────────────────
if ! q rev-parse --git-dir >/dev/null 2>&1; then
  printf 'landing[1]{what,detail,action}:\n'
  row unknown "not a git checkout: this tree cannot see a repository" "nothing measured, nothing claimed"
  exit 0
fi
if ! q rev-parse --verify -q "refs/remotes/$REMOTE/$BASE" >/dev/null 2>&1; then
  printf 'landing[1]{what,detail,action}:\n'
  row unknown "$REMOTE/$BASE is not in this checkout" "fetch once and the next session start will see what landed"
  exit 0
fi

# ── (a) worker branches pushed, older than a few hours, with no PR ───────────
# Two single reads, so the filter costs nothing per branch: every remote ref with its tip's date and
# sha (the age, and the identity the PR question needs), and every branch already merged into the base.
refs_all="$(bounded "$BOUND" git -C "$REPO" for-each-ref \
  --format='%(refname:lstrip=3)%09%(committerdate:unix)%09%(objectname)' "refs/remotes/$REMOTE" 2>/dev/null)"
merged_refs="
$(q for-each-ref --merged="refs/remotes/$REMOTE/$BASE" --format='%(refname:lstrip=3)' "refs/remotes/$REMOTE" 2>/dev/null)
"
tip_of() { # <branch> — its tip sha, from the ONE read
  printf '%s\n' "$refs_all" | awk -F'\t' -v b="$1" '$1==b { print $3; exit }'
}

old_list=""
worker_n=0
young=0
while IFS='	' read -r name ts sha; do
  [ -n "$name" ] || continue
  keep=0
  for p in $PREFIXES; do
    case "$name" in "$p"/*) keep=1; break ;; esac
  done
  [ "$keep" = 1 ] || continue
  worker_n=$((worker_n + 1))
  case "$ts" in ''|*[!0-9]*) ts=0 ;; esac
  age_h=$(( now > ts ? (now - ts) / 3600 : 0 ))
  if [ "$age_h" -lt "$MIN_HOURS" ]; then young=$((young + 1)); continue; fi
  case "$merged_refs" in *"
$name
"*) continue ;; esac          # already merged through some other road
  old_list="${old_list}${name}	${age_h}
"
done <<EOF
$refs_all
EOF

# The PR state of every branch in ONE question, with a deadline. A door that cannot answer is said
# out loud; a branch is never called PR-less on the strength of a failed call.
pr_map=""
pr_state="unknown"
pr_note=""
if [ -n "$old_list" ]; then
  slug="$(q remote get-url "$REMOTE" 2>/dev/null | sed -E 's#.*github\.com[:/]##; s#\.git$##')"
  if [ -z "$slug" ]; then
    pr_note="no GitHub slug for $REMOTE"
  elif ! command -v "$GH_CMD" >/dev/null 2>&1; then
    pr_note="$GH_CMD is not installed here"
  else
    pr_out="$(bounded "$BOUND" "$GH_CMD" pr list -R "$slug" --state all --limit 500 \
                --json headRefName,state,number \
                --jq '.[] | "\(.headRefName)\t\(.state)\t\(.number)"' 2>/dev/null)"
    if [ -n "$pr_out" ]; then
      pr_map="$pr_out"; pr_state="known"
    elif bounded "$BOUND" "$GH_CMD" pr list -R "$slug" --state all --limit 1 --json number >/dev/null 2>&1; then
      pr_state="known"           # it answered, and there is no pull request at all
    else
      pr_note="$GH_CMD did not answer (offline, or not signed in)"
    fi
  fi
fi

pr_field() { # <branch> <state|number> — from the one answer, never a second call
  printf '%s\n' "$pr_map" | awk -F'\t' -v b="$1" -v f="$2" '$1==b { print (f=="number" ? $3 : $2); exit }'
}

# A BRANCH CARRIED INSIDE AN OPEN PULL REQUEST IS NOT WAITING (measured live 2026-11-14). The gather
# merges a batch's branches into ONE batch branch, so an errand's own head carries no PR and read as
# lost work — four branches were named "pushed, no PR" while riding inside gathered PRs. The
# reachable set of every OPEN head is computed ONCE, so a candidate costs one lookup; which PR
# carries it is asked only of the few that do, with one `--contains` read each.
open_heads=""        # "<head><TAB>#<number>"
if [ "$pr_state" = known ] && [ -n "$pr_map" ]; then
  open_heads="$(printf '%s\n' "$pr_map" | awk -F'\t' '$2=="OPEN" { print $1 "\t#" $3 }')"
fi
if [ -n "$open_heads" ]; then
  shas=""
  while IFS='	' read -r head num; do
    [ -n "$head" ] || continue
    head_sha="$(tip_of "$head")"
    [ -n "$head_sha" ] && shas="$shas $head_sha"
  done <<EOF
$open_heads
EOF
  if [ -n "$shas" ]; then
    carried_reach="$(mktemp)"
    bounded 20 git -C "$REPO" rev-list $shas >"$carried_reach" 2>/dev/null || : >"$carried_reach"
  fi
fi
carried_pr() { # <branch> — the open PR that carries it, or nothing
  [ -n "$carried_reach" ] && [ -s "$carried_reach" ] || return 0
  local tip h n
  tip="$(tip_of "$1")"
  [ -n "$tip" ] || return 0
  grep -qxF "$tip" "$carried_reach" 2>/dev/null || return 0
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    n="$(printf '%s\n' "$open_heads" | awk -F'\t' -v h="$h" '$1==h { print $2; exit }')"
    [ -n "$n" ] && { printf '%s' "$n"; return 0; }
  done <<EOF
$(bounded "$BOUND" git -C "$REPO" for-each-ref --contains "$tip" --format='%(refname:lstrip=3)' "refs/remotes/$REMOTE" 2>/dev/null)
EOF
  return 0
}

waiting=""
w_n=0
c_n=0
while IFS='	' read -r name age_h; do
  [ -n "$name" ] || continue
  st="$(pr_field "$name" state)"
  case "$st" in
    OPEN|MERGED) continue ;;            # a pull request exists: it is the heart's to read, not a loss
  esac
  if [ "$age_h" -ge 48 ]; then age="$((age_h / 24))d"; else age="${age_h}h"; fi
  kind="no-pr"
  if [ "$pr_state" != known ]; then     # never call a branch PR-less on a question nobody answered
    verdict="pushed, not merged, PR state unread"
    action="read its PR first: gh pr list --head $name --state all"
  else
    case "$st" in
      CLOSED) verdict="PR #$(pr_field "$name" number) CLOSED, not merged"
              action="decide: gather it as a new PR (bin/forge/gather.sh ${name#*/}) or delete the branch" ;;
      '')     carrier="$(carried_pr "$name")"
              if [ -n "$carrier" ]; then
                kind="in-pr"
                verdict="in batch PR $carrier, not merged yet"
                action="nothing to gather — that PR carries this branch, and it lands when $carrier merges"
              else
                verdict="pushed, no PR, not merged"
                action="gather it: bin/forge/gather.sh ${name#*/}"
              fi ;;
      *)      verdict="pushed, unexpected PR state $st, not merged"
              action="read its PR: gh pr list --head $name --state all" ;;
    esac
  fi
  waiting="${waiting}${kind}	${name}	${age}	${verdict}	${action}
"
  case "$kind" in in-pr) c_n=$((c_n + 1)) ;; *) w_n=$((w_n + 1)) ;; esac
done <<EOF
$old_list
EOF

# ── (b) commits that exist on no remote, on any local branch ─────────────────
# A branch whose tip a remote can reach cannot hold a stranded commit (its ancestors are reachable
# too), so the stranded tips name the branches — one read, one join, then a count per such branch.
sha_file="$(mktemp)"; heads_file="$(mktemp)"
trap '[ -n "${carried_reach:-}" ] && rm -f "$carried_reach"; rm -f "$sha_file" "$heads_file"' EXIT
stranded_total=0
stranded_rows=""
if stranded_shas="$(bounded 20 git -C "$REPO" rev-list --branches --not --remotes 2>/dev/null)"; then
  stranded_total="$(printf '%s\n' "$stranded_shas" | grep -c . || true)"
  case "$stranded_total" in ''|*[!0-9]*) stranded_total=0 ;; esac
  if [ "$stranded_total" -gt 0 ]; then
    printf '%s\n' "$stranded_shas" | sed '/^$/d' | sort >"$sha_file"
    q for-each-ref --format='%(objectname) %(refname:short)' refs/heads 2>/dev/null | sort >"$heads_file"
    stranded_rows="$(join -j 1 -o 2.2 "$sha_file" "$heads_file" 2>/dev/null)"
    out=""
    while IFS= read -r br; do
      [ -n "$br" ] || continue
      c="$(bounded 10 git -C "$REPO" rev-list --count "$br" --not --remotes 2>/dev/null)"
      case "$c" in ''|*[!0-9]*) continue ;; esac
      [ "$c" -gt 0 ] || continue
      out="${out}${c}	${br}
"
    done <<EOF
$stranded_rows
EOF
    stranded_rows="$(printf '%s' "$out" | sort -rn | awk -F'\t' 'NF==2')"
    unset out
  fi
fi

# ── the rows ─────────────────────────────────────────────────────────────────
n_rows=0
ROWS=""
add() { # <what> <detail> <action> — buffered, because the header carries the count
  n_rows=$((n_rows + 1))
  ROWS="${ROWS}$(row "$1" "$2" "$3")
"
}

emit_kind() { # <kind> <count> <folded wording>
  local kind=$1 total=$2 i=0 k name age verdict action
  [ "$total" -gt 0 ] || return 0
  while IFS='	' read -r k name age verdict action; do
    [ "$k" = "$kind" ] || continue
    i=$((i + 1))
    [ "$i" -le "$ROWS_MAX" ] || continue
    add "$kind" "$name — $age: $verdict" "$action"
  done <<EOF
$waiting
EOF
  [ "$total" -le "$ROWS_MAX" ] || add "$kind" "$((total - ROWS_MAX)) $3" \
    "SAGA_LAND_ROWS=$((total + 1)) bin/time/saga-land-warnings.sh names them all"
}

emit_kind no-pr "$w_n" "more pushed branch(es) are waiting with no PR"
emit_kind in-pr "$c_n" "more branch(es) ride inside an open pull request"
if [ "$w_n" -gt 0 ] || [ "$c_n" -gt 0 ]; then
  case "$pr_state" in
    known) ;;
    *) [ -n "$pr_note" ] && add "note" "the pull-request state was not read: $pr_note" "a branch above may already have a PR — the note says the row is incomplete, not the branch lost" ;;
  esac
fi

if [ "$stranded_total" -gt 0 ]; then
  names="$(printf '%s' "$stranded_rows" | awk -F'\t' -v max="$ROWS_MAX" \
    'NF==2 { n++; if (n<=max) printf "%s%s (%s)", (n>1?", ":""), $2, $1 } END { if (n>max) printf " and %d more branch(es)", n-max }')"
  add "unpushed" "$stranded_total commit(s) exist on no remote: $names" \
    "push them to a BRANCH (never to main) — a commit on one disk is a commit nobody can merge"
fi

if [ "$n_rows" = 0 ]; then
  add "clean" "nothing is waiting: every worker branch older than ${MIN_HOURS}h has a PR or is merged, and no local commit is stranded" \
    "checked $worker_n worker branch(es) against $REMOTE/$BASE ($young younger than ${MIN_HOURS}h, not judged yet)"
fi

printf 'landing[%s]{what,detail,action}:\n' "$n_rows"
printf '%s' "$ROWS"
exit 0

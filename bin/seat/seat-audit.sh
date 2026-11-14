#!/usr/bin/env bash
# seat-audit.sh — one line per agent pane: is its work safe, landed, and correct?
#
# The fault this door answers (measured 2026-11-14): 36 agent panes stood on one
# machine and almost all of them were finished, but nothing could say WHICH. The
# reaper saw only the `eindri-*` workspaces the spawner raises, so a worker seated
# by hand as a tab was invisible to it; and the helm measured the hall by hand, in
# a loop pasted into a pane, once. A measurement that lives in a pane dies with the
# pane. This is that measurement, shipped, so the next hand asks instead of guessing.
#
# It answers the runbook's four checks for every agent pane in every workspace and
# tab, and it answers them the same way every time:
#
#   1  its folder is clean                    dirty=<count of uncommitted entries>
#   2  its commits are on origin              unpushed=<commits no remote holds>
#   3  its work landed                        in_main=<yes|no> · pr=<#n STATE>
#   4  its work was right                     verdict=… and the branch, for the helm
#
# Check 4 is never finished by this door: it names what a person must read (the
# branch, the fix note, the report). See hodd/docs/runbooks/retiring-finished-agents.md.
#
# Two measurements are deliberately NOT taken here:
#   * `git merge-tree` — it hung for 30s+ on this repository with no CPU use. The
#     mergeability of a pull request is asked of GitHub (`--json mergeable`), the
#     service that already knows, because it is the only side that can answer.
#   * a `git fetch` per pane — the sweep runs at every session start and a fetch
#     per pane is a network round trip per pane. Without a fetch, `origin/<branch>`
#     can only UNDERSTATE what the remote holds, so a stale read refuses to close a
#     pane rather than closing one too early. `--fetch` takes the truthful count.
#
# Skip the caller's own pane (HERDR_PANE_ID) and any repository's main checkout: a
# seat is not an errand, and the hall is never an errand's work.
#
# Usage: seat-audit.sh [--pane <id>] [--tsv] [--no-pr] [--fetch]
#   --pane <id>  measure only that pane
#   --tsv        the machine face: pane, status, agent, tab, workspace, focused,
#                folder, branch, dirty, unpushed, in_main, pr, mergeable, verdict,
#                why, report — tab-separated, `-` for a field that has no value
#                (never an empty field: tab is whitespace to `read`, so an empty
#                field would shift every field after it)
#   --no-pr      do not ask GitHub (offline, or a test that plants its own answer)
#                (even without it, a dirty, unpushed or working pane is not asked:
#                 it is refused before its pull request matters, and a network call
#                 per candidate is a cost this door pays at every session start)
#   --fetch      fetch origin before measuring unpushed (truthful, slower)
#
# Env: BROKK_HOME / BROKK_STATE_OVERRIDE / BROKK_ROOT_OVERRIDE (as seat-reap.sh).
# Exit: 0 measured (a refusal is a ROW, never a failed run), 2 usage.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"

# The errand records live on whichever shelf the caller named — the same three
# shelves seat-reap.sh asks, in the same order, so the two doors cannot disagree
# about whether a recon errand filed its report.
state_dirs() {
  local d seen=""
  for d in "${BROKK_STATE_OVERRIDE:-}" "$BROKK_HOME/state" "$ROOT/state"; do
    [ -n "$d" ] && [ -d "$d" ] || continue
    case " $seen " in *" $d "*) continue ;; esac
    seen="$seen $d"
    printf '%s\n' "$d"
  done
}

# report_for <id> -> the recon report's path when one exists, or - (a sentinel, so a
# machine field is never empty)
report_for() {
  local id=$1 d
  [ -n "$id" ] || { printf '%s' '-'; return 0; }
  while IFS= read -r d; do
    if [ -f "$d/eindri-reports/$id.md" ]; then printf '%s' "$d/eindri-reports/$id.md"; return 0; fi
  done < <(state_dirs)
  printf '%s' '-'
}

# ── options ───────────────────────────────────────────────────────────────────
ONLY_PANE=""
FACE=toon
AUDIT_PR=1
AUDIT_FETCH=0
while [ $# -gt 0 ]; do
  case "$1" in
    --pane) ONLY_PANE="${2:-}"; shift 2 ;;
    --tsv)  FACE=tsv; shift ;;
    --no-pr) AUDIT_PR=0; shift ;;
    --fetch) AUDIT_FETCH=1; shift ;;
    -h|--help|help) sed -n '2,50p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'seat-audit: unknown option %s\n' "$1" >&2; exit 2 ;;
  esac
done

HAVE_HERDR=0
command -v herdr >/dev/null 2>&1 && HAVE_HERDR=1
HAVE_GH=0
command -v gh >/dev/null 2>&1 && HAVE_GH=1

skip_all() {  # <why> — nothing was measurable; the reason is the answer
  printf 'seat-audit[0]{state}:\n  "%s"\n' "$1"
  exit 0
}
[ "$HAVE_HERDR" = 1 ] || skip_all "no herdr on this host — no agent pane to audit (a clean skip)"

AGENTS="$SCRIPT_DIR/herdr-agents.py"
[ -x "$AGENTS" ] || skip_all "the one herdr reader is missing ($AGENTS)"

# ── git readers ───────────────────────────────────────────────────────────────
# A linked worktree is an errand's tree; the repository's own checkout is a seat's.
# Same test seat-reap.sh's `--verify` uses, so both doors agree on what a worktree is.
is_linked_worktree() {  # <path>
  local p=${1:-.} common own
  common="$(git -C "$p" rev-parse --git-common-dir 2>/dev/null)" || return 1
  own="$(git -C "$p" rev-parse --git-dir 2>/dev/null)" || return 1
  [ -n "$common" ] && [ -n "$own" ] || return 1
  [ "$(CDPATH='' cd "$p" && CDPATH='' cd "$common" 2>/dev/null && pwd -P)" \
    = "$(CDPATH='' cd "$p" && CDPATH='' cd "$own" 2>/dev/null && pwd -P)" ] && return 1
  return 0
}

# The `.pi/extensions` deletion is migration 0019's fault, not work — the same
# exclusion seat-reap.sh's worktree_guard makes, or every seat reads dirty forever.
dirty_count() {
  git -C "$1" status --porcelain 2>/dev/null \
    | grep -vE '^.{0,1}D[[:space:]]+\.pi/extensions/' | wc -l | tr -d ' '
}

has_ref() { git -C "$1" rev-parse --verify -q "$2" >/dev/null 2>&1; }

remote_ref() {  # <path> <branch> -> refs/remotes/origin/<branch>, when it exists
  has_ref "$1" "refs/remotes/origin/$2" && printf '%s' "refs/remotes/origin/$2"
}

in_main() {  # <path> -> yes|no|unknown (measured against origin/main, never local main)
  local p=$1
  has_ref "$p" refs/remotes/origin/main || { printf '%s' unknown; return 0; }
  if git -C "$p" merge-base --is-ancestor HEAD refs/remotes/origin/main 2>/dev/null; then
    printf '%s' yes
  else
    printf '%s' no
  fi
}

# is_recon <path> <branch> -> yes when this seat made no commit of its own.
#
# The tempting test — `origin/main..HEAD` is empty — is WRONG: it is empty for
# every branch that has already been merged, so every landed seat would read as a
# recon (measured on the planted fixture, 2026-11-14). The honest test is two
# facts together: origin/main already contains this HEAD, AND the branch exists on
# no remote — so nothing of this seat ever left the machine. A branch that was
# pushed and merged has a remote branch, and is a landing rather than a recon.
is_recon() {  # <path> <branch>
  local p=$1 br=$2
  has_ref "$p" refs/remotes/origin/main || { printf '%s' no; return 0; }
  git -C "$p" merge-base --is-ancestor HEAD refs/remotes/origin/main 2>/dev/null || { printf '%s' no; return 0; }
  [ "$(printf '%s' "$br")" != '(detached)' ] || br=''
  if [ -n "$br" ] && has_ref "$p" "refs/remotes/origin/$br"; then printf '%s' no; return 0; fi
  printf '%s' yes
}

unpushed_count() {  # <path> <branch> -> commits on no remote
  local p=$1 br=$2 ref
  if [ "$br" != "(detached)" ] && ref="$(remote_ref "$p" "$br")"; then
    git -C "$p" rev-list --count "$ref..HEAD" 2>/dev/null || printf '%s' '-'
    return 0
  fi
  # No remote branch: measure what no remote ref at all holds. Conservative on a
  # stale read, which is the only safe direction for a door that closes things.
  git -C "$p" rev-list --count HEAD --not --remotes 2>/dev/null || printf '%s' '-'
}

repo_slug() {  # <path> -> owner/repo for a GitHub remote, or - (never an empty field)
  local url
  url="$(git -C "$1" remote get-url origin 2>/dev/null)" || { printf '%s' '-'; return 0; }
  case "$url" in
    *github.com*) printf '%s' "$(printf '%s' "$url" | sed -E 's#.*github\.com(:[0-9]+)?[:/]##; s#\.git$##')" ;;
    *) printf '%s' '-' ;;
  esac
}

# ── the PR face: GitHub is asked, `git merge-tree` never is ───────────────────
# One `gh pr list` per repository, indexed by head branch; a branch the batch did
# not carry is asked for exactly (`--head`), which is the command the runbook names.
# A test plants its answers by stubbing `gh` on PATH; nothing here re-derives them.
PR_CACHE="$(mktemp -d 2>/dev/null || true)"
pr_cache_dir() { [ -n "$PR_CACHE" ] && printf '%s' "$PR_CACHE"; }

pr_batch() {  # <slug> -> path to `<branch>\t<number>\t<state>\t<mergeable>` lines
  local slug=$1 dir f
  dir="$(pr_cache_dir)" || return 1
  f="$dir/$(printf '%s' "$slug" | tr '/' '_')"
  [ -f "$f" ] && { printf '%s' "$f"; return 0; }
  # The batch is COMPLETE when GitHub returned fewer rows than the limit. A branch
  # missing from a complete batch has no PR — a fact, and no second question is owed.
  # A truncated batch may hide the branch, so the exact `--head` question is asked.
  gh pr list -R "$slug" --state all --limit 1000 \
     --json number,state,mergeable,headRefName 2>/dev/null \
    | python3 -c '
import json,sys
try: prs=json.load(sys.stdin)
except Exception: raise SystemExit(0)
print("#complete" if len(prs) < 1000 else "#truncated")
for p in prs:
    print("%s\t%s\t%s\t%s" % (p.get("headRefName") or "", p.get("number") or "",
                              p.get("state") or "", p.get("mergeable") or "UNKNOWN"))
' >"$f" 2>/dev/null
  printf '%s' "$f"
}

# pr_lookup <repo> <branch> -> sets PR_N, PR_STATE, PR_MERGEABLE.
# `none` means GitHub answered and knows of no PR; `?` means GitHub could not
# answer. The two are never conflated: a door that closes seats must be able to
# read "no PR exists" as a fact and "I could not ask" as a refusal.
pr_lookup() {
  local slug=$1 br=$2 f hit="" n="" st="" mg="" out rc=0
  PR_N='-'; PR_STATE='-'; PR_MERGEABLE='-'
  [ "$AUDIT_PR" = 1 ] || return 0
  [ "$HAVE_GH" = 1 ] || { PR_N='?'; PR_MERGEABLE='?'; return 0; }
  { [ "$slug" != '-' ] && [ "$br" != '(detached)' ]; } || { PR_N='?'; PR_MERGEABLE='?'; return 0; }
  f="$(pr_batch "$slug" 2>/dev/null || true)"
  local complete=0
  if [ -n "$f" ] && [ -f "$f" ]; then
    hit="$(awk -F'\t' -v b="$br" '$1==b' "$f" 2>/dev/null | tail -1)"
    grep -qx '#complete' "$f" 2>/dev/null && complete=1
  fi
  if [ -z "$hit" ] && [ "$complete" = 1 ]; then
    PR_N='none'; return 0
  fi
  if [ -z "$hit" ]; then
    # The exact question the runbook names, for a branch the 300-row batch missed.
    out="$(gh pr list -R "$slug" --head "$br" --state all \
            --json number,state,mergeable 2>/dev/null)"
    rc=$?
    [ "$rc" = 0 ] || { PR_N='?'; PR_MERGEABLE='?'; return 0; }
    hit="$(printf '%s' "$out" | python3 -c '
import json,sys
try: prs=json.load(sys.stdin)
except Exception: raise SystemExit(0)
for p in prs:
    print("%s\t%s\t%s" % (p.get("number") or "", p.get("state") or "",
                          p.get("mergeable") or "UNKNOWN"))
' 2>/dev/null | tail -1)"
    [ -n "$hit" ] || { PR_N='none'; return 0; }
  fi
  if [ "$(printf '%s' "$hit" | cut -f1)" = "$br" ]; then
    n="$(printf '%s' "$hit" | cut -f2)"; st="$(printf '%s' "$hit" | cut -f3)"
    mg="$(printf '%s' "$hit" | cut -f4)"
  else
    n="$(printf '%s' "$hit" | cut -f1)"; st="$(printf '%s' "$hit" | cut -f2)"
    mg="$(printf '%s' "$hit" | cut -f3)"
  fi
  PR_N="#${n:-?}"; PR_STATE="${st:-?}"; PR_MERGEABLE="${mg:-UNKNOWN}"
}

# ── the verdict: the runbook's table, in one place ────────────────────────────
# Every branch below is a row in hodd/docs/runbooks/retiring-finished-agents.md's
# "what to do with each verdict" table. The reaper acts on this word and on nothing
# else it invents, so the table has exactly one implementation.
verdict_for() {  # <status> <dirty> <unpushed> <in_main> <pr_state> <mergeable> <recon> <report> <branch>
  local status=$1 dirty=$2 unp=$3 im=$4 pr=$5 mg=$6 recon=$7 rep=$8 br=$9
  case "$status" in working|busy) printf '%s' working; return 0 ;; esac
  [ "${dirty:-0}" -gt 0 ] 2>/dev/null && { printf '%s' dirty; return 0; }
  [ "${unp:-0}" -gt 0 ] 2>/dev/null && { printf '%s' unpushed; return 0; }
  # A seat that made no commit of its own is a RECON errand: its HEAD is the base
  # it was seated on. Asked BEFORE "is it in main?" because its HEAD always is —
  # and "in main" would then credit the hall with work this seat never made.
  if [ "$recon" = yes ]; then
    [ "$rep" != '-' ] && printf '%s' recon-with-report || printf '%s' recon-no-report
    return 0
  fi
  [ "$im" = yes ] && { printf '%s' landed; return 0; }
  case "$pr" in
    *MERGED*) printf '%s' landed; return 0 ;;
    *OPEN*)   if [ "$mg" = CONFLICTING ]; then printf '%s' open-pr-conflict
              else printf '%s' open-pr; fi; return 0 ;;
    *CLOSED*) printf '%s' pr-closed; return 0 ;;
  esac
  if [ "$im" = unknown ]; then printf '%s' no-origin-main; return 0; fi
  printf '%s' unmerged
}

# ── measure one pane ──────────────────────────────────────────────────────────
# Globals rather than a subshell: a pane costs ~8 git calls and this runs at every
# session start over every pane in the hall.
R_PANE="" R_STATUS="" R_AGENT="" R_TAB="" R_WS="" R_FOC="" R_FOLDER="" R_BRANCH=""
R_DIRTY="-" R_UNP="-" R_INMAIN="-" R_PR="-" R_MG="-" R_VERDICT="-" R_WHY="-" R_REPORT="-"
# pr_lookup fills these; a pane that is never asked keeps them at `-`.
PR_N='-' PR_STATE='-' PR_MERGEABLE='-'
R_SKIP=0

measure_pane() {  # <pane> <status> <agent> <tab> <workspace> <focused> <cwd>
  R_PANE=$1; R_STATUS=$2; R_AGENT=$3; R_TAB=$4; R_WS=$5; R_FOC=$6
  R_SKIP=0 R_WHY='-' R_REPORT='-' R_DIRTY='-' R_UNP='-' R_INMAIN='-' R_PR='-' R_MG='-' R_VERDICT='-'
  local cwd=$7 br slug
  [ -n "$R_TAB" ] || R_TAB='-'
  [ -n "$R_WS" ]  || R_WS='-'
  R_FOLDER="${cwd:--}"
  R_BRANCH='-'

  # Never the caller's own pane: it is the audit, not a candidate.
  if [ -n "${HERDR_PANE_ID:-}" ] && [ "$R_PANE" = "$HERDR_PANE_ID" ]; then
    R_VERDICT=skip; R_WHY="the caller's own pane"; R_SKIP=1; return 0
  fi
  [ -n "$cwd" ] || { R_VERDICT=skip; R_WHY='the pane reports no folder'; R_SKIP=1; return 0; }
  [ -d "$cwd" ] || { R_VERDICT=skip; R_WHY='the pane folder does not exist'; R_SKIP=1; return 0; }

  if ! git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    R_VERDICT=no-git; R_WHY='not a git repository — nothing to measure'; return 0
  fi
  # A repository's own checkout is a seat's, never an errand's. Skipped by shape,
  # not by branch name: a worker belongs in a worktree.
  if ! is_linked_worktree "$cwd"; then
    R_VERDICT=skip; R_WHY='a repository main checkout — a seat, not an errand'; R_SKIP=1; return 0
  fi

  br="$(git -C "$cwd" branch --show-current 2>/dev/null)"
  [ -n "$br" ] || br='(detached)'
  R_BRANCH="$br"
  [ "$AUDIT_FETCH" = 1 ] && git -C "$cwd" fetch -q origin "$br" 2>/dev/null

  R_DIRTY="$(dirty_count "$cwd")"
  R_UNP="$(unpushed_count "$cwd" "$br")"
  R_INMAIN="$(in_main "$cwd")"
  # GitHub is asked only about a pane that COULD close: clean, pushed, and not
  # working. A dirty, unpushed or busy seat is refused before its pull request
  # matters, and asking is a network round trip on a door that runs at every
  # session start. The column then reads `-`, which is the same word `--no-pr`
  # uses: this pane's pull request was not consulted, and the verdict says why.
  if [ "$R_STATUS" = working ] || [ "${R_DIRTY:-0}" -gt 0 ] || [ "${R_UNP:-0}" -gt 0 ]; then
    :
  else
    pr_lookup "$(repo_slug "$cwd")" "$br"
    R_PR="$PR_N"; R_MG="$PR_MERGEABLE"
  fi
  local id; id="$(basename "$cwd")"
  R_REPORT="$(report_for "$id")"
  R_VERDICT="$(verdict_for "$R_STATUS" "$R_DIRTY" "$R_UNP" "$R_INMAIN" "$PR_STATE" \
                          "$PR_MERGEABLE" "$(is_recon "$cwd" "$br")" "$R_REPORT" "$br")"
  # A short why, for the reading face only.
  case "$R_VERDICT" in
    landed)            if [ "$R_INMAIN" = yes ]; then R_WHY='HEAD is in origin/main'
                       else R_WHY="PR $R_PR"; fi ;;
    open-pr)           R_WHY="PR $R_PR waiting for the heart ($R_MG)" ;;
    open-pr-conflict)  R_WHY="PR $R_PR reads CONFLICTING — rework" ;;
    pr-closed)         R_WHY="PR $R_PR closed without a merge — the heart decides" ;;
    unmerged)          R_WHY='pushed, no PR, not in origin/main — gather it' ;;
    recon-with-report) R_WHY='no commit of its own, report filed' ;;
    recon-no-report)   R_WHY='no commit of its own and no report filed' ;;
    dirty)             R_WHY="$R_DIRTY uncommitted — never closed" ;;
    unpushed)          R_WHY="$R_UNP commit(s) on no remote — never closed" ;;
    no-origin-main)    R_WHY='origin/main is not fetched here — unmeasurable' ;;
    working)           R_WHY='an agent is working here — never touched' ;;
  esac
  return 0
}

# ── the hall ──────────────────────────────────────────────────────────────────
rows=() skip_rows=() tsv_rows=() tsv_skips=()
while IFS=$'\t' read -r pane status agent tab ws foc cwd; do
  [ -n "$pane" ] || continue
  [ -z "$ONLY_PANE" ] || [ "$pane" = "$ONLY_PANE" ] || continue
  measure_pane "$pane" "$status" "$agent" "$tab" "$ws" "$foc" "$cwd"
  if [ "$R_SKIP" = 1 ]; then
    skip_rows+=("$(printf '  "%s","%s"' "$R_PANE" "$R_WHY")")
    tsv_skips+=("$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tskip\t%s\t-' \
      "$R_PANE" "$R_STATUS" "$R_AGENT" "$R_TAB" "$R_WS" "$R_FOC" "$R_FOLDER" "$R_BRANCH" \
      '-' '-' '-' '-' '-' "$R_WHY")")
    continue
  fi
  tsv_rows+=("$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' \
    "$R_PANE" "$R_STATUS" "$R_AGENT" "$R_TAB" "$R_WS" "$R_FOC" "$R_FOLDER" "$R_BRANCH" \
    "$R_DIRTY" "$R_UNP" "$R_INMAIN" "$R_PR" "$R_MG" "$R_VERDICT" "$R_WHY" "$R_REPORT")")
  rows+=("$(printf '  "%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"' \
    "$R_PANE" "$R_STATUS" "$R_AGENT" "$(printf '%s' "$R_FOLDER" | tr '"' "'")" \
    "$(printf '%s' "$R_BRANCH" | tr '"' "'")" \
    "$R_DIRTY" "$R_UNP" "$R_INMAIN" "$R_PR" "$R_MG" "$R_VERDICT")")
done < <(python3 "$AGENTS" --tsv 2>/dev/null)

[ -n "$PR_CACHE" ] && rm -rf "$PR_CACHE" 2>/dev/null

if [ "$FACE" = tsv ]; then
  [ "${#tsv_rows[@]}" -gt 0 ] && printf '%s\n' "${tsv_rows[@]}"
  [ "${#tsv_skips[@]}" -gt 0 ] && printf '%s\n' "${tsv_skips[@]}"
  exit 0
fi

if [ "${#rows[@]}" = 0 ]; then
  printf 'seat-audit[0]{state}:\n  "no agent pane matches — nothing to measure"\n'
  if [ "${#skip_rows[@]}" -gt 0 ]; then
    printf 'skipped[%s]{pane,why}:\n' "${#skip_rows[@]}"
    printf '%s\n' "${skip_rows[@]}"
  fi
  exit 0
fi
printf 'seat-audit[%s]{pane,status,agent,folder,branch,dirty,unpushed,in_main,pr,mergeable,verdict}:\n' "${#rows[@]}"
printf '%s\n' "${rows[@]}"
if [ "${#skip_rows[@]}" -gt 0 ]; then
  printf 'skipped[%s]{pane,why}:\n' "${#skip_rows[@]}"
  printf '%s\n' "${skip_rows[@]}"
fi
exit 0

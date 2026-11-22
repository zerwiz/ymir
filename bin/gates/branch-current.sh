#!/usr/bin/env bash
# branch-current.sh — a branch is based on CURRENT main before it is offered.
#
# The fault this answers (2026-10-18): a branch was cut, main moved six commits
# ahead — including three new numbered RULES — and the push went out anyway. The PR
# then arrived with a conflict and a rule number that already existed. The Allfather
# asked one question — "did you pull latest before pushing the pr" — and the answer
# was no. This makes the answer structural.
#
#   branch-current.sh [check|warn] [--base <ref>] [--max-behind <n>]
#
# Exit: 0 current (or not applicable) · 1 behind the base · 2 usage.
#
# Why it is a WARNING-capable gate: refusing every push on a long-lived branch would
# block a hotfix for a reason that is not this push's. So `check` refuses (the pre-push
# default) and `warn` only reports; and the refusal has the house's loud escape:
#
#   YMIR_ALLOW_STALE_BRANCH="why, in one line" git push
#
# It never fetches (a hook must not depend on the network): it compares against the
# refs that are already on disk, so the remedy it prints is `git fetch && git rebase`.
set -u

VERSION="1.0.0"
# It judges the repository it is RUN IN — that is the one being pushed (a hook runs
# inside the pushed worktree), and it makes the ward testable against throwaway repos.
TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || { printf 'branch-current[1]{check,result}:\n  "not a git checkout","skip"\n'; exit 0; }
cd "$TOP" || exit 2

MODE="check"; BASE=""; MAX=0
while [ $# -gt 0 ]; do
  case "$1" in
    check|warn)        MODE="$1"; shift ;;
    --base)            BASE="${2:?--base needs a ref}"; shift 2 ;;
    --max-behind)      MAX="${2:?--max-behind needs a number}"; shift 2 ;;
    -v|-V|--version)   printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help)         sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)                 printf 'error: unknown flag %s\nhelp: branch-current.sh [check|warn] [--base ref] [--max-behind n]\n' "$1" >&2; exit 2 ;;
  esac
done

git rev-parse --git-dir >/dev/null 2>&1 || { printf 'branch-current[1]{check,result}:\n  "not a git repository","skip"\n'; exit 0; }

# The base: what was asked for, else the remote's main, else local main.
if [ -z "$BASE" ]; then
  for b in origin/main origin/master main master; do
    git rev-parse --verify --quiet "$b" >/dev/null 2>&1 && { BASE="$b"; break; }
  done
fi
if [ -z "$BASE" ]; then
  printf 'branch-current[1]{check,result}:\n  "no base ref reachable","skip"\n'
  exit 0
fi

# THE BASE IS FETCHED FIRST (appended 2026-11-22, the operator: "there should always be a check that we push to the
# latest main — main moves and we push onto an old main and get conflicts"). The first version never fetched, so it
# measured against whatever origin/main was on disk, and a main that moved an hour ago read as "current". Now a remote
# base is fetched with a short limit (BRANCH_CURRENT_FETCH_TIMEOUT, default 15 s); offline, the ward judges the refs on
# disk and SAYS so, never silently. BRANCH_CURRENT_NO_FETCH=1 keeps the old behaviour (a test, a sandbox).
FETCHED="on-disk"
case "$BASE" in
  */*)
    if [ "${BRANCH_CURRENT_NO_FETCH:-0}" != 1 ]; then
      _remote="${BASE%%/*}"; _ref="${BASE#*/}"
      if timeout "${BRANCH_CURRENT_FETCH_TIMEOUT:-15}" git fetch -q "$_remote" "$_ref" 2>/dev/null; then
        FETCHED="fetched"
      else
        printf 'branch-current: could not fetch %s — judging the copy on disk, which may be old\n' "$BASE" >&2
      fi
    fi ;;
esac

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'HEAD')"
case "$BRANCH" in
  main|master|HEAD)
    printf 'branch-current[1]{branch,base,result}:\n  "%s","%s","not a branch to rebase"\n' "$BRANCH" "$BASE"
    exit 0 ;;
esac

BEHIND="$(git rev-list --count "HEAD..$BASE" 2>/dev/null || printf '0')"
AHEAD="$(git rev-list --count "$BASE..HEAD" 2>/dev/null || printf '0')"
TIP="$(git rev-parse --short "$BASE" 2>/dev/null || printf '?')"

if [ "${BEHIND:-0}" -le "$MAX" ]; then
  printf 'branch-current[1]{branch,base,behind,ahead,result,base_ref}:\n  "%s","%s",%s,%s,"current","%s"\n' "$BRANCH" "$BASE" "$BEHIND" "$AHEAD" "$FETCHED"
  exit 0
fi

if [ -n "${YMIR_ALLOW_STALE_BRANCH:-}" ]; then
  printf 'branch-current[1]{branch,base,behind,result,reason}:\n  "%s","%s",%s,"ALLOWED on purpose","%s"\n' \
    "$BRANCH" "$BASE" "$BEHIND" "${YMIR_ALLOW_STALE_BRANCH//\"/\'}"
  exit 0
fi

printf 'branch-current[1]{branch,base,behind,ahead,tip}:\n  "%s","%s",%s,%s,"%s"\n' "$BRANCH" "$BASE" "$BEHIND" "$AHEAD" "$TIP"
printf 'branch-current: %s is %s commit(s) behind %s — a PR from here arrives with conflicts and stale numbers\n' "$BRANCH" "$BEHIND" "$BASE" >&2
printf 'help: git fetch && git rebase %s   (or, if it is genuinely intended: YMIR_ALLOW_STALE_BRANCH="why" git push)\n' "$BASE" >&2
[ "$MODE" = "warn" ] && exit 0
exit 1

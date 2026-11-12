#!/usr/bin/env bash
# gather-merge-guard.sh — a gathered batch keeps its history (plan 272, fault 9).
#
# A gathered batch is one PR that carries several errands' commits. Merged with a SQUASH, those commits become one
# and each errand's history is gone: #692, #693, #694 and #695 each landed that way.
#
# WHAT CAN AND CANNOT BE ENFORCED — said plainly:
#   * GitHub decides the merge method at the moment of the click, from the repository's settings. No check on the PR
#     can see which button will be pressed, so no PR-time check can refuse a squash. A required check that "fails
#     a squash" cannot exist.
#   * What CAN be enforced is the record AFTER the fact: this guard reads a commit on the default branch and says
#     whether it is a gathered batch that arrived as ONE parent (a squash, or a rebase of a one-commit branch). The
#     workflow `gather-merge.yml` runs it on every push to main, so a squashed batch turns that run red and names the PR.
#   * What stops it BEFORE the click is a repository setting only the owner can change: turn "Allow squash merging"
#     OFF (Settings → General → Pull Requests). That is the one lever, and it is the Allfather's to pull.
#   * The PR itself carries the instruction in its first line ("Merge with a merge commit, not squash.") — gather.sh.
#
#   gather-merge-guard.sh check [<rev>]     judge one commit (default HEAD)
#   gather-merge-guard.sh range <A..B>      judge every commit in the range
#
# A commit is "a gathered batch" when its subject starts with `gather:` or names `gather-<YYYYMMDD>-<HHMMSS>`.
# Exit: 0 fine (not a batch, or a batch with a merge commit) · 1 a batch landed as a single parent · 2 usage.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
GIT=(git -C "${GATHER_GUARD_REPO:-$ROOT}")

case "${1-}" in
  --version|-v) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
CMD="$1"; ARG="${2:-}"

is_batch() { printf '%s' "$1" | grep -qE '^gather:|gather-[0-9]{8}-[0-9]{6}'; }

judge() {  # <sha> → prints a finding, returns 1 when a batch arrived as one parent
  local sha=$1 subj parents n
  subj="$("${GIT[@]}" log -1 --format=%s "$sha" 2>/dev/null)" || return 0
  is_batch "$subj" || return 0
  parents="$("${GIT[@]}" log -1 --format=%P "$sha")"
  n=$(printf '%s\n' "$parents" | wc -w | tr -d ' ')
  if [ "$n" -lt 2 ]; then
    printf 'gather-merge[1]{commit,parents,subject,finding}:\n  "%s","%s","%s","a gathered batch landed as ONE parent — the errands'"'"' history was squashed away"\n' "${sha:0:12}" "$n" "$subj"
    printf 'help: turn "Allow squash merging" off in the repository settings (the owner'"'"'s lever); merge batches with a merge commit\n' >&2
    return 1
  fi
  return 0
}

case "$CMD" in
  check) judge "${ARG:-HEAD}"; exit $? ;;
  range)
    [ -n "$ARG" ] || { printf 'usage: gather-merge-guard.sh range A..B\n' >&2; exit 2; }
    rc=0
    while IFS= read -r sha; do [ -n "$sha" ] && { judge "$sha" || rc=1; }; done < <("${GIT[@]}" rev-list "$ARG")
    [ "$rc" = 0 ] && printf 'gather-merge[1]{state}:\n  "clean — no gathered batch in %s landed as a single parent"\n' "$ARG"
    exit "$rc" ;;
  *) printf 'error: unknown command %s\nhelp: gather-merge-guard.sh [check|range]\n' "$CMD" >&2; exit 2 ;;
esac

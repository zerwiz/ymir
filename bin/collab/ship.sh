#!/usr/bin/env bash
# ship.sh — the house's git discipline as one door: branch, commit named paths, merge to the base, push.
#
#   ship.sh --repo PATH --branch NAME --message "..." --path P [--path P ...]
#           [--base main] [--no-push] [--dry-run]
#
# Never `git add -A`: only the paths named are staged, so a scratch file written seconds earlier cannot be
# swept into a commit. Everything else in the working tree is reported and left alone.
#
# Exit: 0 shipped · 1 refused · 2 usage.
set -euo pipefail

repo="" branch="" message="" base="main"; push=1; dry=0; paths=()
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="${2-}"; shift 2 ;;
    --branch) branch="${2-}"; shift 2 ;;
    --message) message="${2-}"; shift 2 ;;
    --path) paths+=("${2-}"); shift 2 ;;
    --base) base="${2-}"; shift 2 ;;
    --no-push) push=0; shift ;;
    --dry-run) dry=1; shift ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'ship: unknown option %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ -n "$repo" ] && [ -n "$branch" ] && [ -n "$message" ] && [ ${#paths[@]} -gt 0 ] || {
  printf 'ship: --repo, --branch, --message and at least one --path are required\n' >&2; exit 2; }
[ -d "$repo" ] || { printf 'ship: no such repository: %s\n' "$repo" >&2; exit 1; }
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { printf 'ship: not a git repository: %s\n' "$repo" >&2; exit 1; }
[ -z "$(git -C "$repo" status --porcelain -- "${paths[@]}")" ] && {
  printf 'ship: nothing to ship at the named path(s)\n' >&2; exit 1; }

others="$(git -C "$repo" status --porcelain | awk '{ $1=""; sub(/^ /,""); print }' | grep -vxF -f <(printf '%s\n' "${paths[@]}") || true)"
start="$(git -C "$repo" rev-parse --abbrev-ref HEAD)"

printf 'collab[6]{field,value}:\n'
printf '  "repo","%s"\n' "$repo"
printf '  "branch","%s (from %s)"\n' "$branch" "$start"
printf '  "base","%s"\n' "$base"
printf '  "paths","%s"\n' "${paths[*]}"
printf '  "left_alone","%s"\n' "${others:-nothing}"
printf '  "push","%s"\n' "$([ "$push" = 1 ] && echo yes || echo no)"

if [ "$dry" = 1 ]; then
  printf 'state[1]{field,value}:\n  "state","dry run — nothing committed, nothing merged"\n'
  exit 0
fi

git -C "$repo" checkout -q -b "$branch"
git -C "$repo" add -- "${paths[@]}"
git -C "$repo" commit -q -m "$message"
git -C "$repo" checkout -q "$base"
git -C "$repo" merge -q --no-ff -m "merge: $branch — $message" "$branch"

head_sha="$(git -C "$repo" rev-parse --short HEAD)"
if [ "$push" = 1 ]; then
  git -C "$repo" push -q origin "$base"
  printf 'state[2]{field,value}:\n  "merged","%s into %s at %s"\n  "pushed","origin/%s"\n' "$branch" "$base" "$head_sha" "$base"
else
  printf 'state[2]{field,value}:\n  "merged","%s into %s at %s"\n  "pushed","no (--no-push)"\n' "$branch" "$base" "$head_sha"
fi

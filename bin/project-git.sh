#!/usr/bin/env bash
# project-git.sh — resolve a project's GitHub block from the master registry
# (`workspace/projects.yaml`). The runtime consumes this instead of guessing a
# remote. Auth is a REFERENCE (app|pat|ssh|gh), never a value.
#
# Usage:
#   project-git.sh <project-id> [--field host|owner|repo|remote|default_branch|auth]
#   project-git.sh list
#   project-git.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REG="${PROJECTS_YAML:-$ROOT/workspace/projects.yaml}"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ID="${1-}"; shift || true
FIELD=""
while [ $# -gt 0 ]; do case "$1" in --field) FIELD=${2-}; shift 2 ;; *) shift ;; esac; done
[ -f "$REG" ] || { printf 'error: registry not found: %s\nhelp: run bin/ymir-install.sh\n' "$REG" >&2; exit 1; }

if [ "$ID" = "list" ]; then
  n=$(grep -cE '^\s*-\s+id:' "$REG" 2>/dev/null || echo 0)
  printf 'projects[%s]{id}:\n' "$n"
  grep -E '^\s*-\s+id:' "$REG" | sed -E 's/^\s*-\s+id:\s*/  "/; s/\s*$/" /'
  exit 0
fi
[ -n "$ID" ] || { printf 'error: needs a project id\nhelp: bin/project-git.sh <project-id> [--field owner]\n' >&2; exit 2; }

block="$(awk -v id="$ID" '
  $0 ~ "^[[:space:]]*-[[:space:]]+id:[[:space:]]*"id"[[:space:]]*$" {f=1; next}
  f && /^[[:space:]]*-[[:space:]]+id:/ {exit}
  f {print}
' "$REG")"
[ -n "$block" ] || { printf 'error: project not found: %s\nhelp: bin/project-git.sh list\n' "$ID" >&2; exit 1; }

gitline="$(printf '%s\n' "$block" | grep -m1 'git:')"
val() { printf '%s' "$gitline" | sed -nE "s/.*[ {,]?$1:[[:space:]]*([^,}]+).*/\1/p" | tr -d ' '; }

host="$(val host)"; owner="$(val owner)"; repo="$(val repo)"; remote="$(val remote)"; br="$(val default_branch)"; auth="$(val auth)"
if [ -n "$FIELD" ]; then
  case "$FIELD" in
    host) printf '%s\n' "$host" ;; owner) printf '%s\n' "$owner" ;; repo) printf '%s\n' "$repo" ;;
    remote) printf '%s\n' "$remote" ;; default_branch) printf '%s\n' "$br" ;; auth) printf '%s\n' "$auth" ;;
    *) printf 'error: unknown field %s\n' "$FIELD" >&2; exit 2 ;;
  esac
  exit 0
fi
printf 'project[1]{id,host,owner,repo,remote,default_branch,auth}:\n'
printf '  "%s","%s","%s","%s","%s","%s","%s"\n' "$ID" "$host" "$owner" "$repo" "$remote" "$br" "$auth"

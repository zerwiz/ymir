#!/usr/bin/env bash
# repo-scrub.sh — purge private paths from ALL git history before going public.
#
#   bin/repo-scrub.sh --dry-run          # list what history still holds
#   bin/repo-scrub.sh --yes              # back up, then rewrite history
#   bin/repo-scrub.sh --yes <path> ...   # add extra paths to purge
#
# Rewrites every commit. A mirror backup is written to /tmp first. git-filter-repo
# drops the `origin` remote, so re-add it after. ALWAYS rotate any exposed key
# first — history rewriting does not un-leak a secret.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_PATHS=(assets/reference/state workspace/memory)

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

MODE=dry; PATHS=()
for a in "$@"; do
  case "$a" in
    --yes) MODE=yes ;;
    --dry-run) MODE=dry ;;
    -*) printf 'error: unknown flag %s\n' "$a" >&2; exit 2 ;;
    *) PATHS+=("$a") ;;
  esac
done
[ "${#PATHS[@]}" -gt 0 ] || PATHS=("${DEFAULT_PATHS[@]}")

git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || { printf 'error: not a git repo: %s\n' "$ROOT" >&2; exit 1; }

if [ "$MODE" = dry ]; then
  printf 'repo-scrub[%d]{path,files_in_history}:\n' "${#PATHS[@]}"
  for p in "${PATHS[@]}"; do
    n="$(git -C "$ROOT" log --all --name-only --pretty=format: -- "$p" 2>/dev/null | grep -c . || true)"
    printf '  "%s",%s\n' "$p" "${n:-0}"
  done
  printf 'help: bin/repo-scrub.sh --yes  (backs up to /tmp, then rewrites history)\n'
  exit 0
fi

command -v git-filter-repo >/dev/null 2>&1 || { printf 'error: git-filter-repo not installed\nhelp: pipx install git-filter-repo  (or pacman -S git-filter-repo)\n' >&2; exit 1; }
[ -z "$(git -C "$ROOT" status --porcelain)" ] || { printf 'error: working tree not clean — commit or stash first\n' >&2; exit 1; }

backup="/tmp/ymir-scrub-backup-$(date +%Y%m%d-%H%M%S).git"
git clone --mirror "$ROOT" "$backup" >/dev/null 2>&1 || { printf 'error: backup clone failed\n' >&2; exit 1; }

args=(); for p in "${PATHS[@]}"; do args+=(--path "$p"); done
git -C "$ROOT" filter-repo --invert-paths "${args[@]}" --force || { printf 'error: filter-repo failed; backup at %s\n' "$backup" >&2; exit 1; }

printf 'repo-scrub[1]{action,backup,remote}:\n  "purged","%s","origin removed — re-add it"\n' "$backup"
printf 'next[4]{step,command}:\n'
printf '  "re-add remote","git remote add origin <url>"\n'
printf '  "force-push","git push --force --all && git push --force --tags"\n'
printf '  "re-verify","bin/secret-guard.sh --all"\n'
printf '  "rotate key","rotate sk-LJcx… and any other exposed credential NOW"\n'

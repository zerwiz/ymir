#!/usr/bin/env bash
# skill-vendor-sync.sh — keep imported third-party skill packs current.
#
# The Allfather's rule: SYNC, never absorb. A vendor pack keeps its upstream
# layout and its upstream names, so its fixes and new skills flow in; only the
# provenance file (`.source`) and a copy of the tree live in the home. This is
# the reason the finder had to learn to walk an arbitrary layout: a synced tree
# cannot be reshaped to suit us.
#
# Each pack is a directory under $YMIR_HOME/.agents/skills/vendor/<name>/ with a
# `.source` file carrying: url, branch, licence, and the commit last synced.
#
# Usage:
#   skill-vendor-sync.sh                 # sync every vendor pack
#   skill-vendor-sync.sh mattpocock-skills
#   skill-vendor-sync.sh --check         # report packs whose upstream moved
#   skill-vendor-sync.sh --list          # the packs and their provenance
set -uo pipefail

_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}
ROOT="$(_root)"
# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
if command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root YMIR_HOME; fi
HOME_ROOT="${YMIR_HOME:-$ROOT}"
VENDOR="$HOME_ROOT/.agents/skills/vendor"

BOLD=$'\033[1m'; DIM=$'\033[2m'; GRN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'; OFF=$'\033[0m'

src_field() { sed -n "s/^$2:[[:space:]]*//p" "$1" | head -1; }

list_packs() {
  [ -d "$VENDOR" ] || return 0
  for s in "$VENDOR"/*/.source; do
    [ -f "$s" ] || continue
    basename "$(dirname "$s")"
  done
}

# latest_commit <url> <branch>
latest_commit() {
  git ls-remote --heads "$1" "refs/heads/${2:-main}" 2>/dev/null | awk 'NR==1{print $1}'
}

sync_one() {
  local name="$1" dir="$VENDOR/$1" src="$VENDOR/$1/.source"
  [ -f "$src" ] || { printf '%snot a vendor pack: %s%s\n' "$RED" "$name" "$OFF" >&2; return 1; }
  local url branch old new want
  url="$(src_field "$src" url)"; branch="$(src_field "$src" branch)"; old="$(src_field "$src" commit)"
  [ -n "$url" ] || { printf '%s%s has no url in .source%s\n' "$RED" "$name" "$OFF" >&2; return 1; }
  want="$(latest_commit "$url" "$branch")"
  if [ -n "$old" ] && [ "$want" = "$old" ]; then
    printf '%s%s%s up to date @ %s\n' "$DIM" "$name" "$OFF" "${old:0:12}"
    return 0
  fi
  local tmp; tmp="$(mktemp -d)"
  git clone --quiet --depth 1 --branch "$branch" "$url" "$tmp/tree" 2>/dev/null || { rm -rf "$tmp"; printf '%sfailed to clone %s%s\n' "$RED" "$url" "$OFF" >&2; return 1; }
  new="$(git -C "$tmp/tree" rev-parse HEAD)"
  # replace the tree, keep .source, refresh provenance
  find "$dir" -mindepth 1 ! -name '.source' -exec rm -rf {} + 2>/dev/null || true
  tar -C "$tmp/tree" --exclude='.git' --exclude='node_modules' -cf - . | tar -C "$dir" -xf -
  rm -rf "$tmp"
  # read provenance BEFORE the redirect below truncates the file it lives in
  local lic lic_file layout ver
  lic="$(src_field "$src" license)"; lic_file="$(src_field "$src" license_file)"; layout="$(src_field "$src" layout)"
  ver="$(grep -m1 '"version"' "$dir/package.json" 2>/dev/null | sed 's/[^0-9.]//g')"
  {
    printf '# vendor provenance — synced, never absorbed.\n'
    printf 'name: %s\n' "$name"
    printf 'url: %s\n' "$url"
    printf 'branch: %s\n' "$branch"
    printf 'commit: %s\n' "$new"
    [ -n "$ver" ] && printf 'version: %s\n' "$ver"
    printf 'license: %s\n' "$lic"
    printf 'license_file: %s\n' "$lic_file"
    printf 'synced: %s\n' "$(date -Iseconds)"
    printf 'layout: %s\n' "$layout"
    printf 'skills: %s\n' "$(find "$dir" -name SKILL.md | wc -l)"
  } > "$src"
  printf '%s%s%s synced %s -> %s\n' "$GRN" "$name" "$OFF" "${old:0:12}" "${new:0:12}"
}

case "${1:-}" in
  --list)
    list_packs | while read -r n; do
      s="$VENDOR/$n/.source"
      printf '%s %-24s %s @ %s\n' "$DIM" "$n" "$(src_field "$s" url)" "$(src_field "$s" commit | cut -c1-12)"
    done; printf '%s' "$OFF"
    ;;
  --check)
    rc=0
    list_packs | while read -r n; do
      s="$VENDOR/$n/.source"; url="$(src_field "$s" url)"; br="$(src_field "$s" branch)"; old="$(src_field "$s" commit)"
      want="$(latest_commit "$url" "$br")"
      if [ "$want" != "$old" ]; then printf '%s%s upstream moved: %s -> %s%s\n' "$YEL" "$n" "${old:0:12}" "${want:0:12}" "$OFF"
      else printf '%s%s current @ %s%s\n' "$DIM" "$n" "${old:0:12}" "$OFF"; fi
    done
    ;;
  "")
    list_packs | while read -r n; do sync_one "$n"; done
    # the index must not go stale behind a sync
    [ -x "$ROOT/bin/agents/skill-index.sh" ] && "$ROOT/bin/agents/skill-index.sh" >/dev/null 2>&1 && printf '%sindex refreshed%s\n' "$DIM" "$OFF"
    ;;
  *) sync_one "$1" && [ -x "$ROOT/bin/agents/skill-index.sh" ] && "$ROOT/bin/agents/skill-index.sh" >/dev/null 2>&1 ;;
esac

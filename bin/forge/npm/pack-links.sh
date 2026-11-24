#!/usr/bin/env bash
# pack-links.sh — make the tarball carry what the tree's symlinks point at.
#
# `npm pack` drops every symlink, and this tree has ~125 (`config -> .agents/config`, the harness
# agent links, …). An installed package then has no `config/`, and `bin/apps/apps.sh list` dies on a
# missing `config/app-repos.yaml`. So `prepack` calls `stage` (each in-tree symlink is replaced by a
# real copy of its target) and `postpack` calls `restore` (the symlinks come back as they were).
#
#   bin/forge/npm/pack-links.sh stage      replace symlinks with copies; write the manifest
#   bin/forge/npm/pack-links.sh restore    put the symlinks back (safe to run twice)
#   bin/forge/npm/pack-links.sh status     how many links are staged
#
# Only links whose target lies inside the tree are staged; node_modules, .git and .yggdrasil are never
# touched. PACK_LINKS_MANIFEST overrides where the manifest is kept.
set -uo pipefail
HERE="$(dirname "${BASH_SOURCE[0]}")"
ROOT="$(realpath "$HERE/../../..")"
MANIFEST="${PACK_LINKS_MANIFEST:-$ROOT/.pack-links.manifest}"

links() {
  find "$ROOT" \( -name node_modules -o -name .git -o -name .yggdrasil \) -prune -o -type l -print | sort
}

restore() {
  [ -f "$MANIFEST" ] || { echo "pack-links: nothing staged"; return 0; }
  local n=0 l t
  while IFS=$'\t' read -r l t; do
    [ -n "$l" ] || continue
    rm -rf "$l" && ln -s "$t" "$l" && n=$((n+1))
  done < <(sort -r "$MANIFEST")
  rm -f "$MANIFEST"
  echo "pack-links: restored $n symlink(s)"
}

stage() {
  if [ -s "$MANIFEST" ]; then
    echo "pack-links: already staged ($MANIFEST) — run restore first" >&2
    exit 1
  fi
  : > "$MANIFEST"
  local n=0 l t r
  while IFS= read -r l; do
    t="$(readlink "$l")"
    r="$(realpath -e "$l" 2>/dev/null)" || continue          # dangling: leave it
    case "$r" in "$ROOT"/*) ;; *) continue ;; esac           # target outside the tree: leave it
    printf '%s\t%s\n' "$l" "$t" >> "$MANIFEST"
    if ! { rm "$l" && cp -aL "$r" "$l"; }; then
      echo "pack-links: could not stage $l" >&2
      restore
      exit 1
    fi
    n=$((n+1))
  done < <(links)
  echo "pack-links: staged $n symlink(s) as real copies"
}

case "${1:-}" in
  stage) stage ;;
  restore) restore ;;
  status) if [ -f "$MANIFEST" ]; then echo "staged: $(wc -l < "$MANIFEST")"; else echo "staged: 0"; fi ;;
  *) echo "usage: pack-links.sh stage|restore|status" >&2; exit 2 ;;
esac

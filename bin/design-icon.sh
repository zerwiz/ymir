#!/usr/bin/env bash
# design-icon.sh — every app wears its own rune.
#
# The icon set is runecoded (midgard/design-system/icons.md): an Elder Futhark
# rune, stroked at the chisel bevel, tinted by the app's HOUSE colour. Not a
# generic globe, not an emoji, not a screenshot of a UI.
#
#   bin/design-icon.sh list                 # the app -> rune -> house mapping
#   bin/design-icon.sh mint [app]           # write <app>/public/icon.svg (+ the link hint)
#   bin/design-icon.sh mint --all
#
# The tile is stone (--ymir-bg-0) with the rune in the house tint; the SVG is
# self-contained, so a favicon needs no build step and no raster asset.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ICONS="$ROOT/midgard/design-system/icons"
STONE="#0e0c09"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="${1:-list}"; shift || true

# app-dir | glyph | house tint | what the rune says
APPS=(
  "apps/hlidskjalf|ehwaz|#c9973f|the seat — Hlidskjalf, the high seat of the control plane"
  "apps/odrerir|valhalla|#c9973f|the hall — Óðrerir, the Live Hall"
  "apps/sessrumnir|sowilo|#8b5cf6|the sun — Sessrúmnir, the seat that shows the cloth"
  "apps/smidja-factory/apps/visualizer|ansuz|#f59e0b|Odin's breath — Smíðja, the forge"
  "apps/hlidskjalf-mobile|ehwaz|#c9973f|the seat, carried — Hlidskjalf on a phone"
)

list() {
  printf 'app_icons[%d]{app,rune,tint,says}:\n' "${#APPS[@]}"
  for row in "${APPS[@]}"; do
    IFS='|' read -r dir glyph tint says <<<"$row"
    printf '  "%s","%s","%s","%s"\n' "$(basename "$dir")" "$glyph" "$tint" "$says"
  done
  printf 'runes[6]{glyph,name,meaning}:\n'
  printf '  "algiz","ᛉ","the Ymir emblem — the platform itself"\n'
  printf '  "ehwaz","ᛖ","horse/journey — the seat and its transit"\n'
  printf '  "ansuz","ᚨ","Odin'"'"'s breath — the forge"\n'
  printf '  "sowilo","ᛊ","sun — light on the tree"\n'
  printf '  "valhalla","ᚹ","the hall"\n'
  printf '  "gjallarhorn","ᚷ","the horn — the tunnel"\n'
}

mint() {  # <app-dir> <glyph> <tint> <label>
  local dir=$1 glyph=$2 tint=$3 label=$4
  local g="$ICONS/$glyph.svg"
  [ -r "$g" ] || { printf 'error: no glyph %s in midgard/design-system/icons/\nhelp: bin/design-icon.sh list\n' "$glyph" >&2; return 1; }
  local path
  path="$(sed -n 's/.*<path d="\([^"]*\)".*/\1/p' "$g" | head -1)"
  [ -n "$path" ] || { printf 'error: %s carries no <path> to reuse\n' "$glyph" >&2; return 1; }
  local outdir="$ROOT/$dir/public"
  [ -d "$(dirname "$outdir")" ] || { printf '  "%s","SKIP (no such app)"\n' "$dir"; return 0; }
  mkdir -p "$outdir"
  {
    printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32" role="img" aria-label="%s">\n' "$label"
    printf '  <title>%s</title>\n' "$label"
    printf '  <rect width="32" height="32" rx="7" fill="%s"/>\n' "$STONE"
    printf '  <g transform="translate(4 4) scale(1.0)" fill="none" stroke="%s" stroke-width="1.8" stroke-linecap="square" stroke-linejoin="miter">\n' "$tint"
    printf '    <path d="%s"/>\n' "$path"
    printf '  </g>\n</svg>\n'
  } >"$outdir/icon.svg"
  printf '  "%s","%s","%s","<link rel=\\"icon\\" href=\\"/icon.svg\\" type=\\"image/svg+xml\\">"\n' \
    "$(basename "$dir")" "$glyph" "${outdir#"$ROOT"/}/icon.svg"
}

case "$ACTION" in
  list) list ;;
  mint)
    if [ "${1:-}" = "--all" ]; then
      printf 'minted[%d]{app,rune,file,link}:\n' "${#APPS[@]}"
      for row in "${APPS[@]}"; do IFS='|' read -r d g t l <<<"$row"; mint "$d" "$g" "$t" "$l"; done
    else
      want="${1:-}"; found=0
      printf 'minted[1]{app,rune,file,link}:\n'
      for row in "${APPS[@]}"; do
        IFS='|' read -r d g t l <<<"$row"
        case "$(basename "$d")" in "$want") mint "$d" "$g" "$t" "$l"; found=1 ;; esac
      done
      [ "$found" = 1 ] || { printf 'error: unknown app %s\nhelp: bin/design-icon.sh list\n' "$want" >&2; exit 2; }
    fi ;;
  *) printf 'error: unknown action %s\nhelp: bin/design-icon.sh [list|mint] [app|--all]\n' "$ACTION" >&2; exit 2 ;;
esac

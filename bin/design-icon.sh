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


# ── install into the user's system ───────────────────────────────────────────
# An icon that only exists in the checkout is an icon the operator cannot pin.
# This writes the rune into the user's icon theme and a .desktop entry per app,
# rendered with THIS machine's root (never a hardcoded home), so every app is
# dockable and carries the house mark. Idempotent.
# The DESKTOP the operator actually sees, not whatever a session happened to
# export: an agent harness may set XDG_DATA_HOME to a sandbox (this one does),
# and an icon written there is an icon nobody can pin. YMIR_DESKTOP_DATA_HOME
# exists for a test that genuinely wants a throwaway target.
data_home="${YMIR_DESKTOP_DATA_HOME:-$HOME/.local/share}"
icons_dir="$data_home/icons/hicolor/scalable/apps"
apps_dir="$data_home/applications"
# app | entry name | Exec | StartupWMClass
ENTRIES=(
  "hlidskjalf|Ymir · Hlidskjalf|scripts/electron.sh start --view hlidskjalf|ymir-hlidskjalf"
  "odrerir|Ymir · Óðrerir|scripts/electron.sh start --view odrerir|ymir-odrerir"
  "sessrumnir|Ymir · Sessrúmnir|bin/sessrumnir.sh start|ymir-sessrumnir"
  "visualizer|Ymir · Smíðja|scripts/electron.sh start --view smidja|ymir-smidja"
  "hlidskjalf-mobile|Ymir · Hlidskjalf Mobile|scripts/electron.sh start --view hlidskjalf|ymir-hlidskjalf-mobile"
)
install_all() {
  mkdir -p "$icons_dir" "$apps_dir" || { printf 'error: cannot write %s / %s\n' "$icons_dir" "$apps_dir" >&2; exit 1; }
  printf 'installed[%d]{app,icon,entry}:
' "${#ENTRIES[@]}"
  local row app label exec klass src icon dest entry
  for row in "${ENTRIES[@]}"; do
    IFS='|' read -r app label exec klass <<<"$row"
    src="$ROOT/apps/$app/icon.svg"
    [ -f "$src" ] || src="$ROOT/apps/$app/public/icon.svg"          # the visualizer keeps its icon under public/
    [ -f "$src" ] || src="$ROOT/apps/hlidskjalf/public/icon.svg"    # mobile borrows the seat's rune until it earns its own
    icon="ymir-$app"
    cp -f "$src" "$icons_dir/$icon.svg" || { printf '  "%s","-","-"\n' "$app"; continue; }
    entry="$apps_dir/$icon.desktop"
    {
      printf '[Desktop Entry]\nType=Application\nVersion=1.0\n'
      printf 'Name=%s\n' "$label"
      printf 'Comment=Ymir — the agent operating system\n'
      printf 'Exec=bash %s/%s\n' "$ROOT" "$exec"
      printf 'Icon=%s\n' "$icon"
      printf 'Terminal=false\nCategories=Development;Utility;\n'
      printf 'StartupWMClass=%s\nStartupNotify=true\n' "$klass"
    } >"$entry"
    printf '  "%s","%s.svg","%s.desktop"\n' "$app" "$icon" "$icon"
  done
  # the Smidja shelf's older entry name is folded into the rune's own
  [ -f "$apps_dir/ymir-visualizer.desktop" ] && rm -f "$apps_dir/ymir-smidja.desktop"
  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$apps_dir" >/dev/null 2>&1 || true
}

case "$ACTION" in
  list) list ;;
  install) install_all ;;
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

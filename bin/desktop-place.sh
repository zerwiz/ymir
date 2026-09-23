#!/usr/bin/env bash
# desktop-place.sh — put the Ymir apps on their own Hyprland desktops.
#
# On Omarchy the numbered **desktops** (1 2 3 4 5 …) are the "screens" an
# operator switches between, not physical monitors. Both Ymir apps should open
# on their OWN desktop, preferring an EMPTY one, so they are separated and
# reachable with Super+<n> instead of stacking on whatever is active.
#
# This writes a Hyprland user rule (Omarchy's own idiom:
#   o.window("<class>", { workspace = "<n>" })  ) and applies it live where a
# dispatcher is available. It never edits /usr/share/omarchy/.
#
# Usage:
#   bin/desktop-place.sh plan              # show which desktop each app would take
#   bin/desktop-place.sh apply [--dry-run] # write the rules + reload Hyprland
#   bin/desktop-place.sh status
#   bin/desktop-place.sh --version
set -u

# --- portability shim: bin/ymir-platform.sh --------------------------------
if [ -z "${YMIR_PLATFORM_LOADED:-}" ]; then
  _ymir_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  for _ymir_c in "$_ymir_dir/ymir-platform.sh" "$(dirname "$_ymir_dir")/bin/ymir-platform.sh"; do
    [ -r "$_ymir_c" ] && { . "$_ymir_c"; YMIR_PLATFORM_LOADED=1; break; }
  done
  unset _ymir_dir _ymir_c
fi

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Where an app lives: apps/<surface> in a clone, node_modules/@zerwiz/<pkg> in an
# npm install — both shapes, one resolver (bin/app-lib.sh).
if [ -z "${YMIR_APP_LIB_LOADED:-}" ]; then
  _ya="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yac in "$_ya/app-lib.sh" "$(dirname "$_ya")/bin/app-lib.sh"; do
    [ -r "$_yac" ] && { . "$_yac"; YMIR_APP_LIB_LOADED=1; break; }
  done
  unset _ya _yac
fi
app_dir hlidskjalf APP_HLIDSKJALF || APP_HLIDSKJALF=""
app_dir sessrumnir APP_SESSRUMNIR || APP_SESSRUMNIR=""
app_dir odrerir APP_ODRERIR || APP_ODRERIR=""

HYPR_DIR="$HOME/.config/hypr"
RULE_FILE="$HYPR_DIR/ymir-desktops.lua"
# The three Ymir surfaces, in the order they should claim desktops.
APPS=(hlidskjalf smidja sessrumnir odrerir)
CLASS_hlidskjalf="ymir-hlidskjalf"
CLASS_smidja="ymir-smidja"
CLASS_sessrumnir="sessrumnir"
CLASS_odrerir="ymir-odrerir"

# ── launcher entries (ANY Linux desktop — GNOME, KDE, Hyprland) ──────────────
# Two halves live in this file, and they are not the same kind of thing:
#   · the WINDOW RULES are Hyprland's (Omarchy) — numbered desktops, a Lua rule;
#   · the LAUNCHER ENTRIES and the app icons are the freedesktop standard, which
#     GNOME, KDE and Hyprland all read from the same place.
# A GNOME operator gets entries and icons and no window rules, which is the
# correct answer — and the reason a packaged install on GNOME had no icons at
# all, because both halves lived behind the Omarchy gate.
#
# The .desktop files are templates (__YMIR_ROOT__, not an absolute path), because
# where this checkout lives is a fact about the machine, not about Ymir.
install_entries() {
  local dst="$HOME/.local/share/applications" n=0
  local dirs=("$APP_HLIDSKJALF/electron" "$APP_SESSRUMNIR/resources" "$APP_ODRERIR/electron")
  if [ "$(ymir_os)" != linux ] && [ "$(ymir_os)" != wsl ]; then
    printf 'skip: desktop entries are Omarchy/Linux-shaped; this host is %s\n' "$(ymir_os)" >&2
    return 0
  fi
  # Which root runs the launchers? The npm package when the ymir CLI resolves
  # into one (its node_modules/@zerwiz/ymir has the scripts and bin), else this
  # repo — the answer to "the apps run from the npm installation".
  local root="$ROOT" cli cliReal pkgRoot
  cli="$(command -v ymir 2>/dev/null || true)"
  if [ -n "$cli" ]; then
    cliReal="$(realpath "$cli" 2>/dev/null || echo "$cli")"
    pkgRoot="$(dirname "$(dirname "$cliReal")")"
    if [ -n "$pkgRoot" ] && [ -d "$pkgRoot/scripts" ] && [ "$pkgRoot" != "$ROOT" ]; then root="$pkgRoot"; fi
  fi
  mkdir -p "$dst" || return 1
  local src found=0
  for src in "${dirs[@]}"; do
    [ -d "$src" ] || continue
    found=1
    for f in "$src"/*.desktop.in; do
      [ -e "$f" ] || continue
      sed -e "s|__YMIR_ROOT__|$root|g" "$f" >"$dst/$(basename "$f" .in)" && n=$((n+1))
    done
  done
  [ "$found" = 1 ] || { printf 'error: no launcher templates found\n' >&2; return 1; }
  printf 'entries[%s]{installed_to}\:\n  "%s","%s"\n' "$n" "$n" "$dst"
}

have() { command -v "$1" >/dev/null 2>&1; }
is_omarchy() { [ -d /usr/share/omarchy ]; }

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="${1:-plan}"; shift || true
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

# An occupied desktop holds at least one window. Everything else in 1..N is free.
occupied_desktops() {
  hyprctl workspaces -j 2>/dev/null | python3 -c '
import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for w in d:
    if w.get("windows", 0) > 0:
        print(w.get("id"))
' 2>/dev/null | sort -n
}

plan_desktops() {
  local n="${YMIR_DESKTOP_POOL:-10}"
  local occ; occ="$(occupied_desktops | tr '\n' ' ')"
  python3 - "$n" "$occ" "${APPS[@]}" <<'PY'
import sys
pool = int(sys.argv[1])
occupied = {int(x) for x in sys.argv[2].split() if x.isdigit()}
apps = sys.argv[3:]
free = [d for d in range(1, pool + 1) if d not in occupied]
# Prefer EMPTY desktops; fall back to the lowest free numbers if none are empty.
chosen = []
for i, app in enumerate(apps):
    if i < len(free):
        chosen.append((app, free[i]))
    else:
        chosen.append((app, i + 1))
for app, d in chosen:
    print(f"{app}\t{d}")
PY
}

write_rules() {
  local plan="$1"
  local out=""
  out+="-- Ymir desktop placement (generated by bin/desktop-place.sh)."$'\n'
  out+="-- On Omarchy the numbered desktops are the operator's \"screens\"."$'\n'
  out+="-- Each Ymir app opens on its own desktop, preferring an EMPTY one."$'\n'
  out+="-- Regenerate with: bin/desktop-place.sh apply"$'\n\n'
  while IFS=$'\t' read -r app d; do
    [ -n "$app" ] || continue
    local cls
    case "$app" in
      hlidskjalf) cls="$CLASS_hlidskjalf" ;;
      smidja)     cls="$CLASS_smidja" ;;
      sessrumnir) cls="$CLASS_sessrumnir" ;;
      odrerir)     cls="$CLASS_odrerir" ;;
      *)          cls="$app" ;;
    esac
    out+="o.window({ class = \"^${cls}\$\" }, { workspace = \"${d}\" })"$'\n'
  done <<<"$plan"
  if [ "$DRY" = 1 ]; then
    printf '%s' "$out"
    return 0
  fi
  mkdir -p "$HYPR_DIR"
  printf '%s' "$out" >"$RULE_FILE"
}

include_rule_file() {
  # Make hyprland.lua require our file, once. Never touch /usr/share/omarchy.
  local main="$HYPR_DIR/hyprland.lua"
  local line='require("hypr.ymir-desktops")'
  [ -f "$main" ] || return 0
  grep -qxF "$line" "$main" && return 0
  [ "$DRY" = 1 ] && { printf 'would add to %s: %s\n' "$main" "$line"; return 0; }
  printf '\n-- Ymir: place the desktop apps on their own desktops.\n%s\n' "$line" >>"$main"
}

reload_hypr() {
  [ "$DRY" = 1 ] && return 0
  have hyprctl || return 0
  hyprctl reload >/dev/null 2>&1 || true
}

# ── speed-starts: one key per Ymir app ───────────────────────────────────────
# An Omarchy user otherwise reaches the apps only through the launcher menu. The
# binds live in their own file because editor-place.sh regenerates the desktop
# rules file and preserves only window rules.
write_launchers() {
  local file="$HYPR_DIR/ymir-launchers.lua" out=""
  out+="-- Ymir speed-starts (generated by bin/desktop-place.sh)."$'\n'
  out+="-- One key raises each app; the placement rules send it to its own desktop."$'\n'
  out+="-- Regenerate with: bin/desktop-place.sh apply"$'\n\n'
  out+="o.bind(\"SUPER + Y\", \"Ymir Hlidskjalf\", \"bash $ROOT/scripts/electron.sh start --view hlidskjalf\")"$'\n'
  out+="o.bind(\"SUPER + M\", \"Ymir Smiðja\", \"bash $ROOT/scripts/electron.sh start --view smidja\")"$'\n'
  out+="o.bind(\"SUPER + B\", \"Ymir Sessrúmnir\", \"bash $ROOT/bin/sessrumnir.sh start\")"$'\n'
  out+="o.bind(\"SUPER + O\", \"Ymir Óðrerir\", \"bash $ROOT/scripts/electron.sh start --view odrerir\")"$'\n'
  if [ "$DRY" = 1 ]; then printf '%s' "$out"; return 0; fi
  if [ -f "$file" ] && [ "$(cat "$file")" = "$out" ]; then return 0; fi
  mkdir -p "$HYPR_DIR"
  printf '%s' "$out" >"$file"
}

include_launchers_file() {
  local main="$HYPR_DIR/hyprland.lua" line='require("hypr.ymir-launchers")'
  [ -f "$main" ] || return 0
  grep -qxF "$line" "$main" && return 0
  [ "$DRY" = 1 ] && { printf 'would add to %s: %s\n' "$main" "$line"; return 0; }
  printf '\n-- Ymir: one key per Ymir app (SUPER+Y Hlidskjalf, SUPER+M Smiðja, SUPER+B Sessrúmnir).\n%s\n' "$line" >>"$main"
}

case "$ACTION" in
  entries)
    # The launcher half on its own: any Linux desktop, no Hyprland required.
    install_entries
    if command -v update-desktop-database >/dev/null 2>&1; then
      update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
    fi
    if command -v gtk-update-icon-cache >/dev/null 2>&1 && [ -d "$HOME/.local/share/icons/hicolor" ]; then
      gtk-update-icon-cache -q -t -f "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
    fi
    ;;
  plan)
    plan="$(plan_desktops)"
    printf 'desktop-place[%d]{app,desktop}:\n' "$(printf '%s\n' "$plan" | grep -c .)"
    while IFS=$'\t' read -r app d; do
      [ -n "$app" ] || continue
      printf '  "%s",%s\n' "$app" "$d"
    done <<<"$plan"
    ;;
  apply)
    is_omarchy || { printf 'desktop-place[1]{state,detail}:\n  "skipped","not an Omarchy host"\n'; exit 0; }
    plan="$(plan_desktops)"
    write_rules "$plan"
    include_rule_file
    write_launchers
    include_launchers_file
    reload_hypr
    # The launcher entries are part of the same desktop integration: render the
    # templates (they hold __YMIR_ROOT__, not an absolute path) into the user's
    # applications directory.
    [ "$DRY" = 1 ] || install_entries >/dev/null 2>&1 || true
    if [ "$DRY" = 1 ]; then
      printf 'desktop-place[1]{state,file}:\n  "dry-run","%s"\n' "$RULE_FILE"
    else
      printf 'desktop-place[1]{state,file}:\n  "written","%s"\n' "$RULE_FILE"
    fi
    while IFS=$'\t' read -r app d; do
      [ -n "$app" ] || continue
      printf '  "%s","desktop %s"\n' "$app" "$d"
    done <<<"$plan"
    ;;
  status)
    if [ -f "$RULE_FILE" ]; then
      printf 'desktop-place[1]{state,file}:\n  "present","%s"\n' "$RULE_FILE"
      grep -E 'workspace' "$RULE_FILE" 2>/dev/null | sed 's/^/  /' || true
    else
      printf 'desktop-place[1]{state,file}:\n  "absent","%s"\n' "$RULE_FILE"
    fi
    ;;
  *) printf 'error: unknown action %s\nhelp: bin/desktop-place.sh [plan|apply|status]\n' "$ACTION" >&2; exit 2 ;;
esac

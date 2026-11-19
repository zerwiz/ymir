#!/usr/bin/env bash
# activate.sh — seat the launcher entry for the LIVE release (Ymir's apps.sh runs it after every flip and rollback).
# With Ymir: `ymir-app odrerir` (its shell finds this home). Without: this home's current/start.sh.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
link="${YMIR_APPS_HOME:-$data/ymir-apps}/odrerir/current"; [ -L "$link" ] || link="$HERE"
[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] || [ -d "$data/applications" ] || { printf 'odrerir: no desktop here — no launcher\n'; exit 0; }
yapp="${YMIR_SHORTCUT_BIN:-$HOME/.local/bin}/ymir-app"
mkdir -p "$data/applications" "$data/icons/hicolor/256x256/apps"
if [ -x "$yapp" ]; then sed -e "s|__YMIR_APP__|$yapp|g" "$HERE/electron/ymir-odrerir.desktop.in"
else sed -e "s|^Exec=.*|Exec=$link/start.sh|" "$HERE/electron/ymir-odrerir.desktop.in"; fi > "$data/applications/ymir-odrerir.desktop"
cp -f "$HERE/electron/icon.png" "$data/icons/hicolor/256x256/apps/ymir-odrerir.png"
printf 'odrerir: launcher entry seated\n'

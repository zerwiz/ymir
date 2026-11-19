#!/usr/bin/env bash
# activate.sh — seat the launcher entry for the LIVE release; Ymir's apps.sh runs it after every flip and rollback.
# With Ymir: Exec is Ymir's `ymir-app sessrumnir` (its launcher finds this home). Without: this home's current/start.sh.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
link="${YMIR_APPS_HOME:-$data/ymir-apps}/sessrumnir/current"; [ -L "$link" ] || link="$HERE"
tpl="$HERE/resources/ymir-sessrumnir.desktop.in"
[ -f "$tpl" ] || { printf 'sessrumnir: no launcher template\n'; exit 0; }
[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] || [ -d "$data/applications" ] || { printf 'sessrumnir: no desktop here — no launcher\n'; exit 0; }
yapp="${YMIR_SHORTCUT_BIN:-$HOME/.local/bin}/ymir-app"
if [ -x "$yapp" ]; then exec_line="$yapp sessrumnir"; else exec_line="$link/start.sh"; fi
mkdir -p "$data/applications" "$data/icons/hicolor/256x256/apps"
sed -e '/^Exec=/d' -e '/^TryExec=/d' "$tpl" | sed "1a Exec=$exec_line" > "$data/applications/ymir-sessrumnir.desktop"
cp -f "$HERE/resources/icons/icon-256.png" "$data/icons/hicolor/256x256/apps/ymir-sessrumnir.png" 2>/dev/null || true
printf 'sessrumnir: launcher entry seated (%s)\n' "$exec_line"

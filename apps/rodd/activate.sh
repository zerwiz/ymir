#!/usr/bin/env bash
# activate.sh — seat what names the LIVE release; Ymir's apps.sh runs it after every flip and rollback.
#   the launcher entry (rodd.desktop: Ymir's `ymir-app rodd`) and the unit ymir-rodd.service, both rendered from this
#   repo's own templates with the window's folder as the apps home's `current` link, which follows every update.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/scripts/ymir-root.sh"
YROOT=""; ymir_root YROOT || { printf 'rodd: Ymir is not installed here — no voice, so no launcher and no unit\n' >&2; exit 0; }
link="${YMIR_APPS_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/ymir-apps}/rodd/current"
[ -L "$link" ] && appdir="$link" || appdir="$HERE"
data="${XDG_DATA_HOME:-$HOME/.local/share}"; units="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] || [ -d "$data/applications" ]; then
  mkdir -p "$data/applications" "$data/icons/hicolor/256x256/apps"
  sed -e "s|__YMIR_APP__|${YMIR_SHORTCUT_BIN:-$HOME/.local/bin}/ymir-app|g" -e "s|__YMIR_ROOT__|$YROOT|g" \
    "$HERE/electron/rodd.desktop.in" > "$data/applications/rodd.desktop"
  cp -f "$HERE/electron/icon.png" "$data/icons/hicolor/256x256/apps/ymir-rodd.png"
  printf 'rodd: launcher entry seated\n'
fi
mkdir -p "$units"
sed -e "s|__YMIR_RUNTIME__|$YROOT|g" -e "s|__APP_DIR__|$appdir|g" "$HERE/electron/ymir-rodd.service.in" > "$units/ymir-rodd.service"
systemctl --user daemon-reload >/dev/null 2>&1 || true
printf 'rodd: unit ymir-rodd.service names %s\n' "$appdir"

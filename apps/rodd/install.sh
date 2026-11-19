#!/usr/bin/env bash
# install.sh — build this release of the voice window in place (the app contract; Ymir's bin/apps/apps.sh runs it).
#
#   install.sh          the window's own Electron (npm ci, the runtime placed by Ymir's electron-lib when npm will
#                       not), then setup.sh: the engine's face fetched at its pinned tag, dressed as Rödd's
#   install.sh --check  change nothing; exit 1 naming what is not right
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"
case "$HERE" in */ymir-runtime/apps/*|*/ymir/apps/*)
  printf 'error: refusing to build inside a Ymir tree (%s) — an installed app has its own home\n' "$HERE" >&2; exit 1 ;;
esac
. "$HERE/scripts/ymir-root.sh"
YROOT=""; ymir_root YROOT || YROOT=""

if [ "${1-}" = --check ]; then
  bad=0
  [ -n "$YROOT" ] || { printf 'error: her voice comes from Ymir, and Ymir is not installed here (bin/voice/voice-door.sh)\n' >&2; bad=1; }
  face="$(bash "$HERE/setup.sh" --check 2>/dev/null || true)"
  [ "$face" = present ] || { printf 'error: the face is %s — run ./install.sh\n' "${face:-missing}" >&2; bad=1; }
  [ -x "$HERE/node_modules/electron/dist/electron" ] || { printf 'error: the window has no Electron (node_modules/electron) — run ./install.sh\n' >&2; bad=1; }
  grep -q "ymir-rodd" "$HERE/electron/rodd.desktop.in" || { printf 'error: the launcher does not declare its class ymir-rodd\n' >&2; bad=1; }
  [ "$bad" = 0 ] && printf 'rodd: ready (Ymir at %s, the face present, Electron in place)\n' "$YROOT"
  exit "$bad"
fi

npm ci --no-audit --no-fund >/dev/null 2>&1 || npm ci --ignore-scripts --no-audit --no-fund >/dev/null
if [ ! -x "$HERE/node_modules/electron/dist/electron" ] && [ -n "$YROOT" ] && [ -r "$YROOT/bin/desktop/electron-lib.sh" ]; then
  ( . "$YROOT/bin/desktop/electron-lib.sh"; electron_fetch_runtime "$HERE" "$HERE" ) >/dev/null 2>&1 || true
fi
bash "$HERE/setup.sh"
printf 'rodd: built — ./activate.sh seats the launcher and the unit\n'

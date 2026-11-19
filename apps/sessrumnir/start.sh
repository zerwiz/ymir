#!/usr/bin/env bash
# start.sh — open Sessrúmnir from this release (its own Electron, its own build), on loopback, with the platform's
# frame decision. With Ymir installed, Ymir's launcher (bin/desktop/sessrumnir-launch.sh) does the same and more.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1-}" in
  --stop|stop) pkill -f "$HERE/node_modules/electron/dist/electron $HERE" 2>/dev/null && printf 'sessrumnir: stopped\n' || printf 'sessrumnir: not running\n'; exit 0 ;;
esac
[ -f "$HERE/out/main/index.js" ] || { printf 'error: not built — run ./install.sh\n' >&2; exit 1; }
export YMIR_WINDOW_BUTTONS="${YMIR_WINDOW_BUTTONS:-on}"
port="${YMIR_DEVTOOLS_PORT:-9316}"
nohup "$HERE/node_modules/electron/dist/electron" --remote-debugging-port="$port" "$HERE" "$@" >/dev/null 2>&1 &
printf 'sessrumnir: opening (DevTools on 127.0.0.1:%s)\n' "$port"

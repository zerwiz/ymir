#!/usr/bin/env bash
# start.sh — open Sessrúmnir from this release (its own Electron, its own build), on loopback, with the platform's
# frame decision. With Ymir installed, Ymir's launcher (bin/desktop/sessrumnir-launch.sh) does the same and more.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1-}" in
  --stop|stop)
    # By this release's OWN Electron binary (its path, link or real), never by a loose pattern: flags such as
    # --remote-debugging-port sit between the binary and the app path, and a loose match would also hit the shell
    # that asked. The main process goes first; its renderers and zygote follow it.
    real="$(cd "$HERE" && pwd -P)"; found=0
    for pid in $(pgrep -x electron 2>/dev/null); do
      exe="$(readlink "/proc/$pid/exe" 2>/dev/null || true)"
      case "$exe" in "$HERE"/node_modules/electron/dist/electron|"$real"/node_modules/electron/dist/electron)
        tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q -- '--type=' || { kill "$pid" 2>/dev/null && found=1; } ;;
      esac
    done
    [ "$found" = 1 ] && printf 'sessrumnir: stopped\n' || printf 'sessrumnir: not running\n'; exit 0 ;;
esac
[ -f "$HERE/out/main/index.js" ] || { printf 'error: not built — run ./install.sh\n' >&2; exit 1; }
export YMIR_WINDOW_BUTTONS="${YMIR_WINDOW_BUTTONS:-on}"
port="${YMIR_DEVTOOLS_PORT:-9316}"
nohup "$HERE/node_modules/electron/dist/electron" --remote-debugging-port="$port" "$HERE" "$@" >/dev/null 2>&1 &
printf 'sessrumnir: opening (DevTools on 127.0.0.1:%s)\n' "$port"

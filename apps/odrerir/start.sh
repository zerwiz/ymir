#!/usr/bin/env bash
# start.sh — serve the Live Hall from this release on loopback (vite preview of dist/), and open its window through
# Ymir's desktop shell when Ymir is here; without Ymir, open the URL in any browser.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${ODRERIR_PORT:-4322}"
RUN="${XDG_STATE_HOME:-$HOME/.local/state}/odrerir"; mkdir -p "$RUN"
case "${1-}" in
  --stop|stop)
    pid="$(cat "$RUN/hall.pid" 2>/dev/null || true)"
    [ -n "$pid" ] && kill "$pid" 2>/dev/null && rm -f "$RUN/hall.pid" && printf 'odrerir: lowered\n' || printf 'odrerir: not running\n'
    exit 0 ;;
esac
[ -f "$HERE/dist/index.html" ] || { printf 'error: not built — run ./install.sh\n' >&2; exit 1; }
if ! curl -s -o /dev/null "http://127.0.0.1:$PORT/"; then
  ( cd "$HERE" && nohup npx --no-install vite preview --port "$PORT" --strictPort >"$RUN/hall.log" 2>&1 & echo $! > "$RUN/hall.pid" )
  for _ in $(seq 1 40); do curl -s -o /dev/null "http://127.0.0.1:$PORT/" && break; sleep 0.5; done
fi
curl -s -o /dev/null "http://127.0.0.1:$PORT/" || { printf 'error: the hall did not answer on :%s — see %s\n' "$PORT" "$RUN/hall.log" >&2; exit 1; }
printf 'odrerir: the Live Hall is up at http://127.0.0.1:%s/\n' "$PORT"
[ "${ODRERIR_NO_WINDOW:-0}" = 1 ] && exit 0
yapp="${YMIR_SHORTCUT_BIN:-$HOME/.local/bin}/ymir-app"
if [ -x "$yapp" ]; then exec "$yapp" odrerir; fi
command -v xdg-open >/dev/null 2>&1 && xdg-open "http://127.0.0.1:$PORT/" >/dev/null 2>&1 || true

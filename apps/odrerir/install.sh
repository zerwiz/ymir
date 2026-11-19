#!/usr/bin/env bash
# install.sh — build this release of the Live Hall in place (the app contract; Ymir's bin/apps/apps.sh runs it).
#   install.sh          dependencies, the build (dist/), and the live board linked to its state
#   install.sh --check  change nothing; exit 1 naming what is not right
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"
case "$HERE" in */ymir-runtime/apps/*|*/ymir/apps/*)
  printf 'error: refusing to build inside a Ymir tree (%s) — an installed app has its own home\n' "$HERE" >&2; exit 1 ;;
esac
STATE="${YMIR_APP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/odrerir}"
BOARD="$STATE/livehall.json"

if [ "${1-}" = --check ]; then
  bad=0
  [ -d node_modules ] || { printf 'error: dependencies are not installed — run ./install.sh\n' >&2; bad=1; }
  [ -f dist/index.html ] || { printf 'error: the hall is not built (dist/)\n' >&2; bad=1; }
  for f in public/livehall.json dist/livehall.json; do
    [ "$(readlink "$f" 2>/dev/null)" = "$BOARD" ] || { printf 'error: %s is not linked to the board in its state (%s)\n' "$f" "$BOARD" >&2; bad=1; }
  done
  grep -q "allow: \['\.'\]" vite.config.ts || { printf 'error: vite serves outside the app (fault 1 of 2026-09-18)\n' >&2; bad=1; }
  [ "$bad" = 0 ] && printf 'odrerir: ready (built; the board is %s)\n' "$BOARD"
  exit "$bad"
fi

if [ -f package-lock.json ]; then npm ci --no-audit --no-fund; else npm install --no-audit --no-fund; fi
# npm may gate install scripts, so esbuild's own binary (which vite builds with) is placed by its installer
[ -f node_modules/esbuild/install.js ] && ( cd node_modules/esbuild && node install.js ) >/dev/null 2>&1 || true
npm run build
# The board is state, never part of a release: written nightly by Ymir's hall-snapshot job, through these links
# (it writes with a plain redirect, which follows a link and creates the target on its first run).
mkdir -p "$STATE"
for f in public/livehall.json dist/livehall.json; do ln -sfn "$BOARD" "$f"; done
printf 'odrerir: built — ./start.sh serves it on :%s; ./activate.sh seats the launcher\n' "${ODRERIR_PORT:-4322}"

#!/usr/bin/env bash
# install.sh — build this release of the hall in place (the app contract; Ymir's bin/apps/apps.sh runs it).
#
#   install.sh          setup.sh (the data home linked, Nanna's soul rendered from the home, the managed .env
#                       block, dependencies from the lock file) without the launcher, then the web face and the
#                       server built (web/dist, server/dist) so no start pays a build
#   install.sh --check  change nothing; exit 1 naming what is not right
#
# The launcher entry is seated by activate.sh, after the flip, so it names the live release.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"
case "$HERE" in */ymir-runtime/apps/*|*/ymir/apps/*)
  printf 'error: refusing to build inside a Ymir tree (%s) — an installed app has its own home\n' "$HERE" >&2; exit 1 ;;
esac

if [ "${1-}" = --check ]; then
  bad=0
  BILSKIRNIR_DESKTOP=0 bash "$HERE/setup.sh" --check >/dev/null 2>&1 \
    || { printf 'error: setup.sh --check is not current — run ./install.sh (or ./setup.sh to see which part)\n' >&2; bad=1; }
  [ -f web/dist/index.html ] || { printf 'error: the web face is not built (web/dist)\n' >&2; bad=1; }
  [ -f server/dist/index.js ] || { printf 'error: the server is not built (server/dist)\n' >&2; bad=1; }
  grep -q 'ymir-bilskirnir' electron/main.cjs electron/main.js 2>/dev/null \
    || grep -rqs 'ymir-bilskirnir' electron/ || { printf 'error: the window does not declare its class ymir-bilskirnir\n' >&2; bad=1; }
  [ "$bad" = 0 ] && printf 'bilskirnir: ready (setup current, web/dist and server/dist built)\n'
  exit "$bad"
fi

BILSKIRNIR_DESKTOP=0 bash "$HERE/setup.sh"
npm run build -w web >/dev/null
(cd server && npx tsc -p tsconfig.json >/dev/null)
printf 'bilskirnir: built — ./activate.sh seats the launcher; ./start.sh raises the hall\n'

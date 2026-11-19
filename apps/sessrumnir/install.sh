#!/usr/bin/env bash
# install.sh — build this release of Sessrúmnir in place (the app contract; Ymir's bin/apps/apps.sh runs it).
#
#   install.sh          dependencies (npm ci from package-lock.json), the Electron runtime, the build (out/)
#   install.sh --check  change nothing; exit 1 naming what is not right
#
# Piped from curl (`curl -fsSL …/sessrumnir/main/install.sh | bash`) there is no checkout to build, so it hands
# over to scripts/quick-install.sh, which downloads a packaged release — what this file did before the split.
set -euo pipefail
SELF="${BASH_SOURCE[0]:-}"
if [ -z "$SELF" ] || [ ! -f "$SELF" ] || [ ! -f "$(dirname "$SELF")/package.json" ]; then
  exec bash -c "$(curl -fsSL "https://raw.githubusercontent.com/${SESSRUMNIR_REPO:-zerwiz/sessrumnir}/main/scripts/quick-install.sh")" "$@"
fi
HERE="$(cd "$(dirname "$SELF")" && pwd)"
cd "$HERE"
case "$HERE" in */ymir-runtime/apps/*|*/ymir/apps/*)
  printf 'error: refusing to build inside a Ymir tree (%s) — an installed app has its own home\n' "$HERE" >&2; exit 1 ;;
esac
ELECTRON="$HERE/node_modules/electron/dist/electron"

check() {
  local bad=0
  [ -d node_modules ] || { printf 'error: dependencies are not installed — run ./install.sh\n' >&2; bad=1; }
  [ -x "$ELECTRON" ] && "$ELECTRON" --version >/dev/null 2>&1 || { printf 'error: the Electron runtime is missing (node_modules/electron)\n' >&2; bad=1; }
  [ -f out/main/index.js ] || { printf 'error: the app is not built (out/main/index.js)\n' >&2; bad=1; }
  # Fault 5 of 2026-09-18: the fork renamed itself "Pi Desktop". The window's name and class are declared here.
  grep -q "app.setName('Sessrúmnir')" src/main/index.ts && grep -q "'class', 'ymir-sessrumnir'" src/main/index.ts \
    || { printf 'error: the window does not name itself Sessrúmnir (ymir-sessrumnir) — the fork renamed it\n' >&2; bad=1; }
  if [ -f out/main/index.js ] && grep -q '"Pi Desktop"\|productName.*Pi Desktop' package.json 2>/dev/null; then
    printf 'error: package.json carries the upstream product name\n' >&2; bad=1
  fi
  # node-pty is the terminal: it must be built for THIS Electron, or the terminal panel dies at first use
  [ -d node_modules/node-pty ] || { printf 'error: node-pty is not installed\n' >&2; bad=1; }
  [ "$bad" = 0 ] && printf 'sessrumnir: ready (built, Electron %s, named Sessrúmnir)\n' "$("$ELECTRON" --version 2>/dev/null)"
  return "$bad"
}

if [ "${1-}" = --check ]; then check; exit $?; fi

command -v npm >/dev/null 2>&1 || { printf 'error: npm is required (node 22+)\n' >&2; exit 1; }
if [ -f package-lock.json ]; then npm ci --no-audit --no-fund; else npm install --no-audit --no-fund; fi
if ! { [ -x "$ELECTRON" ] && "$ELECTRON" --version >/dev/null 2>&1; }; then
  # npm gates install scripts, so Electron's own download may not have run (the same mend Ymir's electron-lib does)
  ( cd node_modules/electron && node install.js ) >/dev/null 2>&1 || true
fi
npx --no-install electron-builder install-app-deps >/dev/null 2>&1 || true   # node-pty for this Electron
npm run build
printf 'sessrumnir: built — ./start.sh opens it; ./activate.sh seats the launcher\n'

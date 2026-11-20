#!/usr/bin/env bash
# sessrumnir-ensure.sh — ensure the Sessrúmnir desktop GUI is present and runnable.
#
# **Sessrúmnir** is the seat-hall where the Allfather converses with the
# machine: a vendored, re-themed fork of the Apache-2.0 **pi-desktop** project
# (github.com/FaqFirebase/pi-desktop, v0.1.7-alpha) living at apps/sessrumnir.
# The external engine keeps its product name; the GUI the user sees is
# Sessrúmnir. Dependencies are never committed — this script installs them on
# first run, exactly as scripts/electron.sh does for the other desktop apps.
#
# Usage:
#   sessrumnir-ensure.sh status
#   sessrumnir-ensure.sh ensure [--install]
#   sessrumnir-ensure.sh install
#   sessrumnir-ensure.sh --version
#
# Exit: 0 ready (or made ready), 1 not ready, 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Where an app lives: apps/<surface> in a clone, node_modules/@zerwiz/<pkg> in an
# npm install — both shapes, one resolver (bin/app-lib.sh).
if [ -z "${YMIR_APP_LIB_LOADED:-}" ]; then
  _ya="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yac in "$_ya/app-lib.sh" "$(dirname "$_ya")/bin/app-lib.sh"; do
    [ -r "$_yac" ] && { . "$_yac"; YMIR_APP_LIB_LOADED=1; break; }
  done
  unset _ya _yac
fi
app_dir sessrumnir APP_SESSRUMNIR || APP_SESSRUMNIR=""
# The runtime resolver — one shape-aware answer, never an app-local hardcode (P1).
if [ -z "${YMIR_ELECTRON_LIB_LOADED:-}" ]; then
  for _ec in "$SCRIPT_DIR/electron-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/electron-lib.sh"; do
    [ -r "$_ec" ] && { . "$_ec"; YMIR_ELECTRON_LIB_LOADED=1; break; }
  done
  unset _ec
fi

APP="$APP_SESSRUMNIR"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
CMD="${1-}"; shift || true
DO_INSTALL=0
case "$CMD" in ensure) ;; status|install) ;; *) printf 'error: unknown command %s\nhelp: bin/sessrumnir-ensure.sh [status|ensure|install]\n' "$CMD" >&2; exit 2 ;; esac
while [ $# -gt 0 ]; do case "$1" in --install) DO_INSTALL=1; shift ;; *) shift ;; esac; done
[ "$CMD" = install ] && DO_INSTALL=1

app_dir() { [ -d "$APP" ] && [ -f "$APP/package.json" ]; }
deps_present() { [ -d "$APP/node_modules" ] && [ -x "$APP/node_modules/.bin/electron" ]; }
built_present() { [ -f "$APP/out/main/index.js" ]; }

status() {
  local dir deps built electron state
  if app_dir; then dir="$APP"; else dir="absent"; fi
  if deps_present; then deps="yes"; else deps="no"; fi
  if built_present; then built="yes"; else built="no"; fi
  # The runtime answer comes from the resolver: app-local, workspace-hoisted,
  # or sibling package — not a single hardcoded path (P1, 2026-09-24).
  state="$(electron_runtime_state "$APP" "$ROOT" sessrumnir 2>/dev/null || echo absent)"
  case "$state" in ok) electron="yes" ;; partial) electron="partial" ;; *) electron="no" ;; esac
  printf 'sessrumnir[1]{dir,deps,built,electron}:\n'
  printf '  "%s","%s","%s","%s"\n' "$dir" "$deps" "$built" "$electron"
  [ "$dir" = "absent" ] || [ "$deps" = "no" ] && return 1
  [ "$electron" = "yes" ] || return 1
  return 0
}

npm_install() {
  command -v npm >/dev/null 2>&1 || { printf 'error: npm not found — cannot install Sessrúmnir deps\nhelp: install node/npm\n' >&2; return 1; }
  printf 'sessrumnir: installing dependencies (first run)…\n' >&2
  # P3 (2026-09-24): a workspace member's deps HOIST to the workspace root — an
  # install inside the member reconciles the tree and REMOVES its node_modules.
  # Install at the root when a member, app-local only for a standalone app.
  local installd
  if electron_is_workspace_member "$APP" "$ROOT"; then installd="$ROOT"; else installd="$APP"; fi
  ( cd "$installd" && npm install ) >/dev/null 2>&1 || return 1
}

# npm 11+ gates postinstall scripts (allowScripts), so Electron's binary is
# often never downloaded even though the package installed. Heal that here —
# the same remedy scripts/electron.sh uses: run the package's own postinstall,
# then extract from the already-cached zip and write path.txt.
# P2 (2026-09-24): absence is NEVER success. The old guard returned 0 when the
# runtime was absent — a `return 0` on the absent branch must not return.
ensure_electron_binary() {
  local bin edir zip
  bin="$(electron_bin "$APP" "$ROOT" sessrumnir 2>/dev/null || true)"
  [ -n "$bin" ] && [ -x "$bin" ] && "$bin" --version >/dev/null 2>&1 && return 0
  edir="$(electron_pkg_dir "$APP" "$ROOT" sessrumnir 2>/dev/null || true)"
  [ -n "$edir" ] || return 1
  if [ -f "$edir/install.js" ]; then
    ( cd "$edir" && node install.js ) >/dev/null 2>&1 || true
  fi
  bin="$(electron_bin "$APP" "$ROOT" sessrumnir 2>/dev/null || true)"
  [ -n "$bin" ] && [ -x "$bin" ] && return 0
  zip="$(ls "$HOME"/.cache/electron/*/electron-v*-linux-*.zip 2>/dev/null | head -1)"
  if [ -n "$zip" ] && command -v unzip >/dev/null 2>&1; then
    mkdir -p "$edir/dist"
    unzip -q -o "$zip" -d "$edir/dist" >/dev/null 2>&1 && printf 'electron' >"$edir/path.txt"
  fi
  bin="$(electron_bin "$APP" "$ROOT" sessrumnir 2>/dev/null || true)"
  [ -n "$bin" ] && [ -x "$bin" ]
}

build_app() {
  printf 'sessrumnir: building the app (npm run build)…\n' >&2
  ( cd "$APP" && npm run build ) >/dev/null 2>&1 || return 1
}

case "$CMD" in
  status) status; exit $? ;;
  install)
    npm_install || { printf 'error: npm install failed — see apps/sessrumnir\n' >&2; exit 1; }
    ensure_electron_binary || { printf 'error: Electron binary missing — run: cd apps/sessrumnir && node node_modules/electron/install.js\n' >&2; exit 1; }
    build_app || { printf 'error: build failed — run: cd apps/sessrumnir && npm run build\n' >&2; exit 1; }
    status; exit $? ;;
  ensure)
    if status >/dev/null 2>&1; then status; exit 0; fi
    if [ "$DO_INSTALL" = 1 ]; then
      npm_install || true
      ensure_electron_binary || true
      built_present || build_app || true
      status
      exit $?
    fi
    status
    printf 'sessrumnir: not ready — run `bin/sessrumnir-ensure.sh install`\n' >&2
    exit 1 ;;
esac
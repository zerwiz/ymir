#!/usr/bin/env bash
# test_electron_home_app.sh — an app in its own home finds the house's Electron (2026-11-19, the split).
#
# Óðrerir's window is the house's desktop shell: the app ships no Electron of its own. Installed in its
# own home (~/.local/share/ymir-apps/odrerir/current), it no longer sits under the Ymir tree, so the
# climb in electron_bin never reached the root's node_modules and the window could not open.
#
# A throwaway tree and a throwaway apps home, both under one temp dir (nothing real is read or moved):
#
#   · electron_bin finds the ROOT's runtime for an app in a home outside the tree
#   · electron_pkg_dir names the same package dir
#   · an app that DECLARES another Electron major is still refused the house's runtime
#   · with no runtime at the root, the answer is still a refusal (exit 1), never a guess
#
# Exit: 0 every case held · 1 a case failed.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ymir-electron-home.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
# shellcheck source=../bin/desktop/electron-lib.sh
. "$ROOT/bin/desktop/electron-lib.sh"

exe="$(_electron_exe)"
tree="$TMP/tree"; app="$TMP/apps-home/odrerir/releases/abc123"
mkdir -p "$tree/node_modules/electron/dist/$(dirname "$exe")" "$app"
printf '{"name":"@zerwiz/ymir","workspaces":["apps/*"]}\n' >"$tree/package.json"
# one key per line, as npm writes it: the major is read from a line that starts with "version"
printf '{\n  "name": "electron",\n  "version": "43.8.9"\n}\n' >"$tree/node_modules/electron/package.json"
printf '#!/bin/sh\n' >"$tree/node_modules/electron/dist/$exe"; chmod +x "$tree/node_modules/electron/dist/$exe"
printf '{"name":"@zerwiz/odrerir","main":"electron/main.cjs"}\n' >"$app/package.json"

fail=0
ok()  { printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }

got="$(electron_bin "$app" "$tree" odrerir 2>/dev/null)" && [ "$got" = "$tree/node_modules/electron/dist/$exe" ] \
  && ok "an app in its own home finds the house's runtime" || bad "electron_bin gave '${got:-nothing}'"

got="$(electron_pkg_dir "$app" "$tree" odrerir 2>/dev/null)" && [ "$got" = "$tree/node_modules/electron" ] \
  && ok "electron_pkg_dir names the same package" || bad "electron_pkg_dir gave '${got:-nothing}'"

printf '{"name":"@zerwiz/odrerir","devDependencies":{"electron":"^39.0.0"}}\n' >"$app/package.json"
electron_bin "$app" "$tree" odrerir >/dev/null 2>&1 \
  && bad "an app declaring Electron 39 was handed the house's 43" || ok "a declared other major is still refused"

printf '{"name":"@zerwiz/odrerir"}\n' >"$app/package.json"
rm -rf "$tree/node_modules"
electron_bin "$app" "$tree" odrerir >/dev/null 2>&1 \
  && bad "no runtime anywhere, yet a binary was named" || ok "no runtime at the root is a refusal"

exit "$fail"

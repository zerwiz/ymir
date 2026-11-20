#!/usr/bin/env bash
# test_app_kind.sh — the drawer door opens the window KIND the app declares (2026-11-20, the Óðrerir Tauri spike).
#
# app.yaml may say `kind: electron` or `kind: tauri`, per platform, and name a launcher per platform under
# `launch: tauri:`. bin/desktop/ymir-app reads it through bin/apps/app-kind.sh, so a Tauri window is opened by
# the same door as an Electron one. Fenced: a throwaway pin and a throwaway app home under one temp dir; the
# real runtime, the real home and the desktop are never touched (YMIR_APP_FOLLOW=0, fake scripts/electron.sh).
#
#   · the scalar `kind: electron` and the per-platform map both read back, with `default:` as the fallback
#   · YMIR_APP_KIND_<APP> overrides for one launch; an unknown kind is a refusal
#   · the launcher resolves per platform, relative to the app's home; a missing one is a refusal
#   · ymir-app execs the Tauri launcher (with the caller's args) when the kind is tauri, and the Electron
#     shell when it is electron — and refuses (exit 1) when tauri is declared but no launcher exists
#
# Exit: 0 every case held · 1 a case failed.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ymir-app-kind.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

fail=0
ok()  { printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }

# shellcheck source=../bin/apps/app-kind.sh
. "$ROOT/bin/apps/app-kind.sh"

app="$TMP/home/toy"; mkdir -p "$app/tauri"
printf 'name: toy\nkind: electron   # a comment\nwindow_class: ymir-toy\n' >"$app/app.yaml"
[ "$(app_kind toy "$app")" = electron ] && ok "a scalar kind reads back" || bad "scalar kind"
[ "$(app_window_class "$app")" = ymir-toy ] && ok "window_class reads back" || bad "window_class"
[ "$(YMIR_APP_KIND_TOY=tauri app_kind toy "$app")" = tauri ] && ok "YMIR_APP_KIND_<APP> overrides" || bad "override"
YMIR_APP_KIND_TOY=wayland app_kind toy "$app" >/dev/null 2>&1 && bad "an unknown kind was accepted" || ok "an unknown kind is refused"

cat >"$app/app.yaml" <<'YAML'
name: toy
kind: { default: electron, linux: tauri }
launch:
  electron: ymir-app
  tauri:
    linux: tauri/launch.sh
    windows: tauri/launch.ps1
window_class: ymir-toy
YAML
printf '#!/usr/bin/env bash\nprintf "tauri-launched %%s\\n" "$*"\n' >"$app/tauri/launch.sh"; chmod +x "$app/tauri/launch.sh"
[ "$(YMIR_APP_PLATFORM=linux app_kind toy "$app")" = tauri ] && ok "the platform's kind wins" || bad "per-platform kind"
[ "$(YMIR_APP_PLATFORM=macos app_kind toy "$app")" = electron ] && ok "default: is the fallback" || bad "default fallback"
[ "$(YMIR_APP_PLATFORM=linux app_launcher "$app" tauri)" = "$app/tauri/launch.sh" ] \
  && ok "the launcher resolves in the app's home" || bad "launcher path"
YMIR_APP_PLATFORM=windows app_launcher "$app" tauri >/dev/null 2>&1 && bad "a missing launcher file was accepted" \
  || ok "a launcher that is not there is refused"
YMIR_APP_PLATFORM=macos app_launcher "$app" tauri >/dev/null 2>&1 && bad "an undeclared platform was accepted" \
  || ok "a platform with no launcher is refused"

# The door itself, over a throwaway pin. The app is given on the dev road (YMIR_APP_<NAME>_DIR).
pin="$TMP/pin"; mkdir -p "$pin/apps" "$pin/bin/apps" "$pin/bin/desktop" "$pin/scripts"
cp "$ROOT/bin/apps/app-path.sh" "$ROOT/bin/apps/app-kind.sh" "$pin/bin/apps/"
cp "$ROOT/bin/desktop/ymir-app" "$pin/bin/desktop/"
printf '#!/usr/bin/env bash\nprintf "electron-launched %%s\\n" "$*"\n' >"$pin/scripts/electron.sh"
door() { env -u HYPRLAND_INSTANCE_SIGNATURE YMIR_RUNTIME_DIR="$pin" YMIR_APP_FOLLOW=0 YMIR_WINDOW_BUTTONS=off \
  YMIR_APP_ODRERIR_DIR="$app" "$@" bash "$pin/bin/desktop/ymir-app" odrerir --probe 2>&1; }

sed -i 's/^name: toy/name: odrerir/' "$app/app.yaml"
out="$(door env YMIR_APP_PLATFORM=linux)"
[ "$out" = "tauri-launched --probe" ] && ok "ymir-app opens a tauri kind through its launcher" || bad "door tauri: '$out'"
out="$(door env YMIR_APP_PLATFORM=macos)"
[ "$out" = "electron-launched start --view odrerir --probe" ] && ok "ymir-app keeps the Electron road for an electron kind" \
  || bad "door electron: '$out'"
out="$(door env YMIR_APP_PLATFORM=macos YMIR_APP_KIND_ODRERIR=tauri)"
case "$out" in *"names no tauri launcher"*) ok "a tauri kind with no launcher here is refused, not guessed" ;;
  *) bad "door missing launcher: '$out'" ;; esac

exit "$fail"

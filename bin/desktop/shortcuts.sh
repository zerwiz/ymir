#!/usr/bin/env bash
# shortcuts.sh — every Ymir app gets its shortcut on every platform, at install and at every update (plan 275 S11–S12).
#
#   bin/desktop/shortcuts.sh            write them: ~/.local/bin/ymir-app, the Linux entries and icons, and the
#                                       platform's own (Windows Start menu from WSL; macOS ~/Applications)
#   bin/desktop/shortcuts.sh --check    report what exists and what is owed; changes nothing (exit 1 when owed)
#   bin/desktop/shortcuts.sh --remove   take every Ymir shortcut away (an uninstall)
#
# Every shortcut runs ONE command, `ymir-app <name>`, which finds the pinned runtime when it runs — so no shortcut
# ever names a tree (the faults of 2026-10-22 and 2026-11-09). Names are always "Ymir · <App>".
#
# Platforms (RULES/05: one core, a layer per platform, a clean skip elsewhere):
#   linux    XDG entries in $XDG_DATA_HOME/applications and icons in the hicolor theme (Omarchy, GNOME, KDE, …)
#   wsl      the Linux entries, PLUS real Windows shortcuts in the Start menu folder "Ymir", written from inside WSL
#            with powershell.exe; each runs `wslg.exe -d <distro> -- ~/.local/bin/ymir-app <name>` (wsl.exe when
#            WSLg's launcher is absent). WSLg's own mirroring is NOT relied on: it reads the system applications
#            folder, not the user's, and is reported to drop entries (microsoft/wslg#45).
#   macos    a small ~/Applications/Ymir <App>.app per app, whose executable runs ymir-app
# Settings (RULES/07): XDG_DATA_HOME, YMIR_SHORTCUT_BIN (~/.local/bin), YMIR_WSL_DISTRO ($WSL_DISTRO_NAME).
set -u
SELF="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SELF/../.." && pwd)"
BIN="${YMIR_SHORTCUT_BIN:-$HOME/.local/bin}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
APPS_DIR="$DATA/applications"
ICONS="$DATA/icons/hicolor/256x256/apps"
MODE=write
case "${1:-}" in --check) MODE=check ;; --remove) MODE=remove ;; "") ;; -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; *) echo "unknown option $1" >&2; exit 2 ;; esac

platform() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    Linux) if grep -qi microsoft /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; then echo wsl; else echo linux; fi ;;
    *) echo other ;;
  esac
}
PLAT="$(platform)"

# name · template (the source of Name, Comment, Categories, WMClass) · icon · entry file name
catalog() {
  printf '%s\t%s\t%s\t%s\n' \
    hlidskjalf apps/hlidskjalf/electron/ymir-hlidskjalf.desktop.in apps/hlidskjalf/electron/icon.png ymir-hlidskjalf.desktop \
    smidja     apps/hlidskjalf/electron/ymir-smidja.desktop.in     apps/hlidskjalf/electron/smidja-icon.png ymir-smidja.desktop \
    odrerir    apps/odrerir/electron/ymir-odrerir.desktop.in       apps/odrerir/electron/icon.png ymir-odrerir.desktop \
    sessrumnir apps/sessrumnir/resources/ymir-sessrumnir.desktop.in apps/sessrumnir/resources/icons/icon-256.png ymir-sessrumnir.desktop \
    bilskirnir apps/bilskirnir/electron/ymir-bilskirnir.desktop.in apps/bilskirnir/electron/icon.png ymir-bilskirnir.desktop \
    rodd       apps/rodd/electron/rodd.desktop.in                   apps/rodd/electron/icon.png rodd.desktop
}
title() {  # the one display name: "Ymir · <App>"
  case "$1" in
    hlidskjalf) echo "Ymir · Hlidskjalf" ;; smidja) echo "Ymir · Smíðja" ;; odrerir) echo "Ymir · Óðrerir" ;;
    sessrumnir) echo "Ymir · Sessrúmnir" ;; bilskirnir) echo "Ymir · Bilskirnir" ;; rodd) echo "Ymir · Rödd" ;;
  esac
}
icon_src() {  # the app's icon: the declared one, else any png beside the template, else none
  local i="$ROOT/$1" t="$ROOT/$2"
  [ -f "$i" ] && { echo "$i"; return; }
  ls "$(dirname "$t")"/*.png 2>/dev/null | head -1
}

owed=0
row() { printf '  "%s","%s","%s"\n' "$1" "$2" "$3"; }

# ── linux: the XDG entries (every Linux, and WSL as the base) ──────────────────────────────────────────────────
linux_entries() {
  local name tpl ico file out want i
  [ "$MODE" = write ] && { mkdir -p "$APPS_DIR" "$ICONS" "$BIN"; install -m 755 "$SELF/ymir-app" "$BIN/ymir-app"; }
  [ "$MODE" = remove ] && rm -f "$BIN/ymir-app"
  [ -x "$BIN/ymir-app" ] && row ymir-app ok "$BIN/ymir-app" || { [ "$MODE" = remove ] || { row ymir-app OWED "$BIN/ymir-app is missing"; owed=1; }; }
  while IFS=$'\t' read -r name tpl ico file; do
    [ -f "$ROOT/$tpl" ] || { row "$name" skip "no template in this tree"; continue; }
    out="$APPS_DIR/$file"
    if [ "$MODE" = remove ]; then rm -f "$out" "$ICONS/ymir-$name.png" "$DATA/icons/hicolor/scalable/apps/ymir-$name.svg"; row "$name" removed "$out"; continue; fi
    # the template supplies the words; Exec, Icon, Name and Path are the house's, the same on every machine
    want="$(sed -e '/^Exec=/d' -e '/^Icon=/d' -e '/^Name=/d' -e '/^Path=/d' -e '/^TryExec=/d' "$ROOT/$tpl" \
      | sed "1a Name=$(title "$name")\nExec=$BIN/ymir-app $name\nIcon=ymir-$name")"
    if [ "$MODE" = check ]; then
      if [ -f "$out" ] && grep -qx "Exec=$BIN/ymir-app $name" "$out"; then row "$name" ok "$out"
      elif [ -f "$out" ]; then row "$name" OWED "$out runs $(sed -n 's/^Exec=//p' "$out" | head -1)"; owed=1
      else row "$name" OWED "no entry at $out"; owed=1; fi
      continue
    fi
    i="$(icon_src "$ico" "$tpl")"
    case "$i" in
      *.svg) mkdir -p "$DATA/icons/hicolor/scalable/apps"; install -m 644 "$i" "$DATA/icons/hicolor/scalable/apps/ymir-$name.svg" ;;
      ?*) install -m 644 "$i" "$ICONS/ymir-$name.png" ;;
    esac
    printf '%s\n' "$want" > "$out.tmp-$$" && mv -f "$out.tmp-$$" "$out"
    row "$name" written "$out"
  done < <(catalog)
  if [ "$MODE" = write ]; then
    command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q "$APPS_DIR" 2>/dev/null || true
    command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t "$DATA/icons/hicolor" 2>/dev/null || true
  fi
}

# ── wsl: real Windows shortcuts in the Start menu, written from inside WSL ─────────────────────────────────────
png_to_ico() {  # <png> <ico> — an ICO holding the PNG as is (Windows Vista and later read it); no image library needed
  python3 - "$1" "$2" <<'PY'
import struct,sys
p=open(sys.argv[1],'rb').read()
w,h=struct.unpack('>II',p[16:24]); w=0 if w>=256 else w; h=0 if h>=256 else h
open(sys.argv[2],'wb').write(struct.pack('<HHH',0,1,1)+struct.pack('<BBBBHHII',w,h,0,0,1,32,len(p),22)+p)
PY
}
wsl_shortcuts() {
  local ps distro progs lauch_exe icons_w icons_l name tpl ico file lnk i n=0
  ps="$(command -v powershell.exe 2>/dev/null || ls /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe 2>/dev/null)"
  [ -n "$ps" ] || { row windows OWED "powershell.exe is not reachable from WSL (interop off?) — the Start-menu shortcuts cannot be written"; owed=1; return; }
  distro="${YMIR_WSL_DISTRO:-${WSL_DISTRO_NAME:-}}"
  [ -n "$distro" ] || { row windows OWED "no WSL distribution name (WSL_DISTRO_NAME is empty)"; owed=1; return; }
  progs="$("$ps" -NoProfile -Command '[Environment]::GetFolderPath("Programs")' 2>/dev/null | tr -d '\r')"
  [ -n "$progs" ] || { row windows OWED "the Windows Start menu folder could not be read"; owed=1; return; }
  local appdata; appdata="$("$ps" -NoProfile -Command '[Environment]::GetFolderPath("LocalApplicationData")' 2>/dev/null | tr -d '\r')"
  icons_w="$appdata\\Ymir\\icons"; icons_l="$(wslpath -u "$icons_w" 2>/dev/null)"
  # WSLg's own launcher runs a GUI app without a console window; plain wsl.exe is the fallback
  lauch_exe='C:\Program Files\WSL\wslg.exe'
  [ -e "$(wslpath -u "$lauch_exe" 2>/dev/null)" ] || lauch_exe='C:\Windows\System32\wsl.exe'
  while IFS=$'\t' read -r name tpl ico file; do
    [ -f "$ROOT/$tpl" ] || continue
    lnk="$progs\\Ymir\\$(title "$name").lnk"
    if [ "$MODE" = check ]; then
      if [ -e "$(wslpath -u "$lnk" 2>/dev/null)" ]; then row "win:$name" ok "$lnk"; else row "win:$name" OWED "no Start-menu shortcut"; owed=1; fi
      continue
    fi
    if [ "$MODE" = remove ]; then rm -f "$(wslpath -u "$lnk" 2>/dev/null)"; row "win:$name" removed "$lnk"; continue; fi
    mkdir -p "$icons_l" 2>/dev/null; i="$(icon_src "$ico" "$tpl")"
    case "$i" in *.png) ;; *) i="" ;; esac
    [ -n "$i" ] && [ -n "$icons_l" ] && png_to_ico "$i" "$icons_l/ymir-$name.ico" 2>/dev/null
    "$ps" -NoProfile -Command "
      \$d = '$progs\\Ymir'; New-Item -ItemType Directory -Force -Path \$d | Out-Null
      \$s = (New-Object -ComObject WScript.Shell).CreateShortcut('$lnk')
      \$s.TargetPath = '$lauch_exe'
      \$s.Arguments = '-d $distro -- $BIN/ymir-app $name'
      \$s.WindowStyle = 7
      \$s.Description = '$(title "$name") (Ymir in WSL)'
      if (Test-Path '$icons_w\\ymir-$name.ico') { \$s.IconLocation = '$icons_w\\ymir-$name.ico' }
      \$s.Save()" >/dev/null 2>&1 \
      && { row "win:$name" written "$lnk"; n=$((n+1)); } || { row "win:$name" OWED "powershell could not write $lnk"; owed=1; }
  done < <(catalog)
}

# ── macos: a small .app per Ymir app ───────────────────────────────────────────────────────────────────────────
mac_apps() {
  local name tpl ico file t app
  while IFS=$'\t' read -r name tpl ico file; do
    [ -f "$ROOT/$tpl" ] || continue
    t="$(title "$name")"; app="$HOME/Applications/$t.app"
    if [ "$MODE" = check ]; then [ -x "$app/Contents/MacOS/ymir-app" ] && row "mac:$name" ok "$app" || { row "mac:$name" OWED "no $app"; owed=1; }; continue; fi
    if [ "$MODE" = remove ]; then rm -rf "$app"; row "mac:$name" removed "$app"; continue; fi
    mkdir -p "$app/Contents/MacOS"
    printf '#!/bin/bash\nexec "%s/ymir-app" %s\n' "$BIN" "$name" > "$app/Contents/MacOS/ymir-app"; chmod 755 "$app/Contents/MacOS/ymir-app"
    cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$t</string><key>CFBundleIdentifier</key><string>dev.ymir.$name</string>
<key>CFBundleExecutable</key><string>ymir-app</string><key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
    row "mac:$name" written "$app"
  done < <(catalog)
}

printf 'shortcuts[1]{platform,mode}:\n  "%s","%s"\n' "$PLAT" "$MODE"
printf 'shortcut{name,state,where}:\n'
case "$PLAT" in
  linux) linux_entries ;;
  wsl) linux_entries; wsl_shortcuts ;;
  macos) [ "$MODE" = write ] && { mkdir -p "$BIN"; install -m 755 "$SELF/ymir-app" "$BIN/ymir-app"; }; mac_apps ;;
  *) row all skip "no shortcut layer for $(uname -s)" ;;
esac
[ "$MODE" = check ] && [ "$owed" = 1 ] && exit 1
exit 0

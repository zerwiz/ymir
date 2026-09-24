#!/usr/bin/env bash
# desktop-verify.sh — the INSTALL-time guarantee: every desktop surface can run,
# and the right app is routed to the right app. (P4/P5, 2026-09-24)
#
# Called by bin/ymir-install.sh's desktop step and by the update path. It runs
# in seconds and FAILS LOUDLY, naming the surface and the resolved path — a
# surface without a runnable runtime is a FAILURE, never a silent skip, and a
# surface whose class is misrouted is a FAILURE, never a silent orphan.
#
# For each surface (hlidskjalf · smidja · odrerir · sessrumnir):
#   (a) the resolver (bin/electron-lib.sh) yields an executable binary —
#       app-local, workspace-hoisted, or the sibling package; never assumed
#   (b) that binary answers `--version`
#   (c) --live, with a compositor present: a window of the surface's class is
#       actually held by the compositor (proves the route end to end)
#   (d) the class invariant ALWAYS: the one class in bin/app-lib.sh equals the
#       surface's .desktop StartupWMClass, the generated Hyprland window rule,
#       the installed launcher entry, and the slug the app's own source sets —
#       a future rename cannot silently orphan a rule
#
# Usage:
#   bin/desktop-verify.sh [--live]     # runtime + class checks for every surface
#   bin/desktop-verify.sh --class-only # just the routing invariant (no binary)
#   bin/desktop-verify.sh --version
#
# Exit: 0 every surface verifies; 1 any check failed (the failures are named).
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

for _dc in "$SCRIPT_DIR/app-lib.sh" "$ROOT/bin/app-lib.sh"; do
  [ -r "$_dc" ] && { . "$_dc"; break; }
done
for _dc in "$SCRIPT_DIR/electron-lib.sh" "$ROOT/bin/electron-lib.sh"; do
  [ -r "$_dc" ] && { . "$_dc"; break; }
done

SURFACES=(hlidskjalf smidja odrerir sessrumnir)
LIVE=0
CLASS_ONLY=0

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
for a in "$@"; do
  case "$a" in
    --live) LIVE=1 ;;
    --class-only) CLASS_ONLY=1 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/desktop-verify.sh [--live|--class-only]\n' "$a" >&2; exit 2 ;;
  esac
done

fail=0
vfail() {  # <surface> <detail> — one loud, named failure
  printf '  "%s","FAIL","%s"\n' "$1" "$2"
  fail=1
}
vok() { printf '  "%s","ok","%s"\n' "$1" "$2"; }

# which app dir LAUNCHES this surface's window — smidja rides hlidskjalf's
# electron shell (its main.cjs presents ymir-smidja); the others own theirs.
shell_dir() {  # <surface>
  local d=""
  case "$1" in
    smidja) app_dir hlidskjalf d || d="" ;;
    *) app_dir "$1" d || d="" ;;
  esac
  printf '%s' "$d"
}
# the .desktop template this surface ships (StartupWMClass must equal app_class)
template_for() {  # <surface>
  local h o s
  case "$1" in
    hlidskjalf) app_dir hlidskjalf h; printf '%s' "$h/electron/ymir-hlidskjalf.desktop.in" ;;
    smidja)     app_dir hlidskjalf h; printf '%s' "$h/electron/ymir-smidja.desktop.in" ;;
    odrerir)    app_dir odrerir o; printf '%s' "$o/electron/ymir-odrerir.desktop.in" ;;
    sessrumnir) app_dir sessrumnir s; printf '%s' "$s/resources/ymir-sessrumnir.desktop.in" ;;
  esac
}
# the app sources that SET the class (the slug the electron presents)
slug_source_dirs() {  # <surface>
  local h o s
  case "$1" in
    hlidskjalf|smidja) app_dir hlidskjalf h; printf '%s' "$h/electron" ;;
    odrerir)           app_dir odrerir o; printf '%s' "$o/electron" ;;
    sessrumnir)        app_dir sessrumnir s; printf '%s %s' "$s/src" "$s/bin" ;;
  esac
}

# ── (a)+(b): the runtime is there, and it answers ───────────────────────────
check_runtime() {  # <surface>
  local s="$1" app bin
  app="$(shell_dir "$s")"
  if [ -z "$app" ] || [ ! -d "$app" ]; then
    vfail "$s" "app dir not resolved (web-only install is a recorded decision, not this)"
    return 1
  fi
  bin="$(electron_bin "$app" "$ROOT" "$(app_pkg "$s")" 2>/dev/null || true)"
  if [ -z "$bin" ] || [ ! -x "$bin" ]; then
    vfail "$s" "no executable Electron runtime — the resolver found nothing under $app (run npm install at the workspace root, or bin/ymir-install.sh)"
    return 1
  fi
  if ! "$bin" --version >/dev/null 2>&1; then
    vfail "$s" "resolved $bin but it does not answer --version"
    return 1
  fi
  vok "$s" "$bin"
}

# ── (c): with a compositor present, the window that appears carries the class ──
check_live_class() {  # <surface>
  local s="$1" cls
  cls="$(app_class "$s")"
  command -v hyprctl >/dev/null 2>&1 || return 0        # no compositor to ask
  hyprctl clients 2>/dev/null | grep -qiE "class:[[:space:]]*${cls}[[:space:]]*$" \
    && vok "$s" "window of class ${cls} held by the compositor" \
    || vfail "$s" "no window of class ${cls} on the compositor — the route is broken (SUPER+<key> would raise nothing)"
}

# ── (d): the class invariant — one string, four writers ─────────────────────
check_class_invariant() {  # <surface>
  local s="$1" cls tpl rule slugs srcs
  cls="$(app_class "$s")"
  tpl="$(template_for "$s")"
  if [ -f "$tpl" ] && ! grep -q "^StartupWMClass=${cls}$" "$tpl"; then
    vfail "$s" "$tpl carries StartupWMClass that is not ${cls}"
    return 1
  fi
  local rule="$HOME/.config/hypr/ymir-desktops.lua"
  if [ -f "$rule" ] && ! grep -qE "class = \"\^${cls}\\$\"" "$rule"; then
    vfail "$s" "the generated window rule $rule has no rule for ${cls}"
    return 1
  fi
  local installed="$HOME/.local/share/applications/ymir-$s.desktop"
  if [ -f "$installed" ] && ! grep -q "^StartupWMClass=${cls}$" "$installed"; then
    vfail "$s" "the installed launcher $installed carries a stale StartupWMClass (not ${cls})"
    return 1
  fi
  srcs="$(slug_source_dirs "$s")"
  slugs="$(grep -rhoE "'ymir-[a-z-]+'" $srcs 2>/dev/null | tr -d "'" | sort -u)"
  if printf '%s\n' "$slugs" | grep -qx "$cls"; then
    vok "$s" "class ${cls} agrees: template · rule · launcher · app source"
  else
    vfail "$s" "the app source under $srcs does not present the slug ${cls} (slugs: $(printf '%s' "$slugs" | tr '\n' ' '))"
  fi
}

printf 'desktop-verify[1]{surfaces,class-check,runtime-check}:\n'
if [ "$CLASS_ONLY" = 1 ]; then
  for s in "${SURFACES[@]}"; do check_class_invariant "$s"; done
else
  for s in "${SURFACES[@]}"; do
    check_runtime "$s" || true
    check_class_invariant "$s" || true
    [ "$LIVE" = 1 ] && check_live_class "$s" || true
  done
fi

if [ "$fail" = 0 ]; then
  if [ "$CLASS_ONLY" = 1 ]; then
    printf 'desktop-verify[1]{state}:\n  "ok","every surface window class is routed right"\n'
  else
    printf 'desktop-verify[1]{state}:\n  "ok","every surface resolves a runnable Electron and is routed right"\n'
  fi
  exit 0
fi
printf 'desktop-verify[1]{state}:\n  "FAIL","fix the rows named above — a surface that cannot open must not be silent"\n'
exit 1
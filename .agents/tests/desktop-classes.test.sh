#!/usr/bin/env bash
# desktop-classes.test.sh — the routing invariant (P5, 2026-09-24): one string
# per surface, four writers. app_class (bin/app-lib.sh) must equal the
# surface's .desktop template StartupWMClass AND the slug the app's own source
# sets (app.setName / appendSwitch('class')). A future rename cannot silently
# orphan a window rule or a launcher.
#
# The 2026-09-24 fault: desktop-place.sh declared CLASS_sessrumnir="sessrumnir"
# while the app presents ymir-sessrumnir — the generated window rule and the
# launcher's StartupWMClass matched nothing, so every Ymir key opened the same
# app. This test would have caught it.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

# shellcheck source=bin/app-lib.sh
. "$ROOT/bin/app-lib.sh"

# The .desktop template each surface ships.
template_for() {  # <surface>
  case "$1" in
    hlidskjalf) printf '%s' "$ROOT/apps/hlidskjalf/electron/ymir-hlidskjalf.desktop.in" ;;
    smidja)     printf '%s' "$ROOT/apps/hlidskjalf/electron/ymir-smidja.desktop.in" ;;
    odrerir)    printf '%s' "$ROOT/apps/odrerir/electron/ymir-odrerir.desktop.in" ;;
    sessrumnir) printf '%s' "$ROOT/apps/sessrumnir/resources/ymir-sessrumnir.desktop.in" ;;
  esac
}
# The app sources that SET the class slug.
slug_dirs() {  # <surface>
  case "$1" in
    hlidskjalf|smidja) printf '%s' "$ROOT/apps/hlidskjalf/electron" ;;
    odrerir)           printf '%s' "$ROOT/apps/odrerir/electron" ;;
    sessrumnir)        printf '%s %s' "$ROOT/apps/sessrumnir/src" "$ROOT/apps/sessrumnir/bin" ;;
  esac
}

for s in hlidskjalf smidja odrerir sessrumnir; do
  cls="$(app_class "$s")"
  # 1. the .desktop template carries exactly the class
  tpl="$(template_for "$s")"
  if [ ! -f "$tpl" ]; then
    bad "$s: no .desktop template at $tpl"
    continue
  fi
  if grep -q "^StartupWMClass=${cls}$" "$tpl"; then
    ok "$s: .desktop StartupWMClass=${cls}"
  else
    bad "$s: $tpl StartupWMClass is not ${cls} (got: $(grep '^StartupWMClass' "$tpl" | head -1 || echo none))"
  fi
  # 2. the app's own source presents the exact slug
  srcs="$(slug_dirs "$s")"
  slugs="$(grep -rhoE "'ymir-[a-z-]+'" $srcs 2>/dev/null | tr -d "'" | sort -u)"
  if printf '%s\n' "$slugs" | grep -qx "$cls"; then
    ok "$s: the app source presents the slug ${cls}"
  else
    bad "$s: the app source under $srcs does not present ${cls} (slugs: $(printf '%s' "$slugs" | tr '\n' ' '))"
  fi
done

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
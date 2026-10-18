#!/usr/bin/env bash
# app-folder-guard.sh — Rule 22: no code in an application's folder, and no
# application's folder inside bin/.
#
# Why (2026-10-18): a display/opening tool was written into `bin/desktop/` — a
# directory named after an APPLICATION — because a file it was modelled on happened to
# live there. The Allfather's verdict: *"we can't have random code in the application
# folders."* The rule is RULES/22; this is the ward that makes it bite instead of
# asking nicely.
#
# What it refuses:
#   1. a DIRECTORY under bin/ named after an application          (bin/desktop/)
#   2. an app-named FILE under bin/ whose name carries no function (bin/desktop/smidja.sh)
#   3. a layer's own tool sitting inside apps/<app>/               (apps/x/desktop-place.sh)
#
# What it allows, deliberately:
#   * <app>-<function>.sh shims in the layer that deploys the app — the layer owns the
#     deployment and the app owns the logic (sessrumnir-ensure.sh · smidja-observe.sh)
#   * an app's own launch door (sessrumnir.sh), because launching IS its function
#   * bin/pi/ … — a harness integration namespace, not one of our apps
#
# Usage: app-folder-guard.sh check [path…]   (default: bin/ and apps/)
#        app-folder-guard.sh --list-apps
#        app-folder-guard.sh --version
# Exit: 0 clean · 1 a finding · 2 usage.
set -u

VERSION="1.0.0"

_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/apps" ] && [ -d "$d/bin" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
}
ROOT="$(_root)"

# The application names, read from apps/ — never a hardcoded list.
app_names() {
  local d
  for d in "$ROOT/apps"/*/; do
    [ -d "$d" ] || continue
    case "$(basename "$d")" in node_modules|README|dist|build) continue ;; esac
    basename "$d"
  done
}

# A function suffix: <app>-<function>.sh is allowed in bin/.
is_function_name() {
  local base="$1" rest="${1##*-}" f
  case "$base" in *-*) ;; *) return 1 ;; esac
  rest="${base#*-}"; rest="${rest%.sh}"; rest="${rest%.py}"
  for f in ensure status sync observe bootstrap board usage smoke build lib agent agents place verify run ls list plan apply fetch install deps start stop launch purge prune doctor; do
    [ "$rest" = "$f" ] && return 0
  done
  return 1
}

findings=0
say() { printf 'app-folder-guard[1]{finding,path,rule,why}:\n  "%s","%s","%s","%s"\n' "$1" "$2" "$3" "$4"; findings=$((findings+1)); }

check_tree() {
  local app path base
  while IFS= read -r app; do
    [ -n "$app" ] || continue
    # 1 · a DIRECTORY under bin/ named after the app
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      say "an application's folder in bin/" "$d" "Rule 22 §3" "the folder is the app's name; everything in it is misfiled by association"
    done < <(find "$ROOT/bin" -type d -name "$app" 2>/dev/null)

    # 2 · an app-named FILE with no function in its name
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      base="$(basename "$f")"
      case "$base" in "$app.sh"|"$app.py") ;; *) continue ;; esac
      is_function_name "$base" && continue
      say "app-named file, no function" "${f#"$ROOT"/}" "Rule 22 §4" "name it <app>-<function>.sh, or move the logic into apps/$app/"
    done < <(find "$ROOT/bin" -type f \( -name "$app.sh" -o -name "$app.py" \) 2>/dev/null)
  done < <(app_names)

  # 3 · a layer's tool inside an application's folder
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    say "a layer's tool inside apps/" "${f#"$ROOT"/}" "Rule 22 §5" "an application's folder is not a toolbox"
  done < <(find "$ROOT/apps" -maxdepth 2 -type f \( -name 'desktop-place.sh' -o -name 'editor-place.sh' -o -name 'display-lib.sh' -o -name 'open-on.sh' -o -name 'app-build.sh' -o -name 'app-lib.sh' \) 2>/dev/null)
}

case "${1:-check}" in
  --list-apps) app_names | sed 's/^/app: /' ;;
  --version)   printf 'app-folder-guard %s\n' "$VERSION" ;;
  check)
    if [ -d "$ROOT/bin" ] && [ -d "$ROOT/apps" ]; then
      check_tree
    else
      printf 'app-folder-guard[1]{finding,path,rule,why}:\n  "no tree to check","%s","—","bin/ or apps/ missing"\n' "$ROOT"
      exit 2
    fi
    if [ "$findings" -eq 0 ]; then
      printf 'app-folder-guard: clean — no application folder under bin/, no app-named file without a function\n'
      exit 0
    fi
    printf 'app-folder-guard: %s finding(s)\nhelp: RULES/22 — the apps live in apps/; bin/ is never an app; a bin/ path carrying an app name is a misfiled tool (name it for the function, or make it <app>-<function>.sh in the layer that deploys it)\n' "$findings" >&2
    exit 1 ;;
  *) printf 'usage: app-folder-guard.sh [check|--list-apps|--version]\n' >&2; exit 2 ;;
esac

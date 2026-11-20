#!/usr/bin/env bash
# app-lib.sh — where an app actually lives.
#
# Two installs, one name. In a clone the apps sit at `apps/<surface>` (the
# registry's `repo: apps/<path>` block clones them there). In a packaged install
# the tree has no `apps/` at all: each surface arrives as a dependency, at
# `node_modules/@zerwiz/<package>`.
#
#            surface            package
#            ----------------   ---------------------
#            hlidskjalf         hlidskjalf
#            hlidskjalf-mobile  hlidskjalf-mobile
#            odrerir            odrerir
#            sessrumnir         sessrumnir
#            smidja             smidja-factory
#
# A surface's name is not always its package's name — and a path is not a name at
# all. Every script that needs an app resolves it HERE, so the two shapes can
# never disagree (Rule 07). Source-safe; functions only.
#
#   app_dir <surface> <result-var>   the app's directory (empty + exit 1 if absent)
#   app_pkg <surface>                the npm package name for that surface
#   app_class <surface>              the window class the app actually presents
#                                    (the ONE source of truth for routing —
#                                    desktop-place rules, .desktop StartupWMClass,
#                                    and the electron app.setName slug must agree, 2026-09-24)
set -u

app_pkg() {  # <surface> → the package name npm serves
  case "${1-}" in
    smidja) printf '%s' 'smidja-factory' ;;
    *)      printf '%s' "${1-}" ;;
  esac
}

app_class() {  # <surface> → the WM class the app presents
  # Read from the electrons themselves: hlidskjalf's main.cjs names
  # ymir-hlidskjalf / ymir-smidja / ymir-odrerir; odrerir's own and
  # sessrumnir's both name their ymir-<slug>. A rename belongs HERE first.
  case "${1-}" in
    hlidskjalf) printf '%s' 'ymir-hlidskjalf' ;;
    smidja)     printf '%s' 'ymir-smidja' ;;
    odrerir)    printf '%s' 'ymir-odrerir' ;;
    sessrumnir) printf '%s' 'ymir-sessrumnir' ;;
    *)          printf '%s' "ymir-${1-}" ;;
  esac
}

app_dir() {  # <surface> <result-var> — a clone's apps/<x>, else the package
  # Scratch names are function-prefixed on purpose: `printf -v <name>` writes to THIS
  # function's scope, so a scratch variable sharing the caller's requested name
  # would swallow the answer (a caller asking for "c" or "root" would get nothing).
  local _apd_surface="${1-}" _apd_rv="${2-}" _apd_root _apd_pkg _apd_c
  [ -n "$_apd_surface" ] && [ -n "$_apd_rv" ] || return 2
  _apd_root="${YMIR_ROOT_DIR:-}"
  if [ -z "$_apd_root" ]; then _apd_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; fi
  _apd_pkg="$(app_pkg "$_apd_surface")"
  # Three shapes, and npm uses the third more than anyone expects:
  #   a clone            apps/<surface> — or apps/<package>, when the surface's
  #                      clone Dir is its package's name (smidja → smidja-factory)
  #   a nested package   <pkg>/node_modules/@zerwiz/<package>
  #   a SIBLING package  <prefix>/lib/node_modules/@zerwiz/<package> — beside ymir,
  #                      where a global install puts a dependency it hoists out
  # (the sibling is found through dirname, so no parent-climbing path is written)
  for _apd_c in \
    "$_apd_root/apps/$_apd_surface" \
    "$_apd_root/apps/$_apd_pkg" \
    "$_apd_root/node_modules/@zerwiz/$_apd_pkg" \
    "$(dirname "$_apd_root")/$_apd_pkg"
  do
    # A hollow directory is not an app. An install step used to `mkdir` — or a
    # clone used to fail — leaving `apps/<name>` empty, and that empty shell
    # shadowed the real package beside it until the SPA could not be served and
    # nobody knew why. An app declares itself: a manifest, a build, or sources.
    if [ -d "$_apd_c" ] \
       && { [ -f "$_apd_c/package.json" ] || [ -d "$_apd_c/dist" ] || [ -d "$_apd_c/src" ]; }; then
      printf -v "$_apd_rv" '%s' "$_apd_c"; return 0
    fi
  done
  printf -v "$_apd_rv" '%s' ""
  return 1
}

# Some callers need the directory a mint writes INTO (an app's public/, electron/,
# dist/…). A packaged app is read-only in spirit, so the clone's apps/ is preferred
# when it exists; otherwise the package is the only truth there is.
app_root() {  # <result-var> — where apps live in THIS tree
  local _apr_rv="${1-}" _apr_root
  [ -n "$_apr_rv" ] || return 2
  _apr_root="${YMIR_ROOT_DIR:-}"
  if [ -z "$_apr_root" ]; then _apr_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; fi
  if [ -d "$_apr_root/apps" ]; then printf -v "$_apr_rv" '%s' "$_apr_root/apps"; return 0; fi
  printf -v "$_apr_rv" '%s' "$_apr_root/node_modules/@zerwiz"
}

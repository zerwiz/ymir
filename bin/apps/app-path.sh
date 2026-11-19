#!/usr/bin/env bash
# app-path.sh — where an app's runnable copy is (plan 01 §2, the split of 2026-11).
#
# The Allfather, 2026-11-18: "i dont wanna them come into the apps folder anymore if
# installed they need their own places." An installed app lives in its OWN home:
#
#   ${YMIR_APPS_HOME:-${XDG_DATA_HOME:-~/.local/share}/ymir-apps}/<name>/
#     repo/              the clone (fetch only, never built in)
#     releases/<sha>/    a built, checked copy per update
#     current  -> releases/<sha>
#     previous -> releases/<sha>
#
# The resolver checks, first hit wins, and names the ROAD it took:
#   dev      YMIR_APP_<NAME>_DIR — a developer's own checkout
#   home     $YMIR_APPS_HOME/<name>/current
#   legacy   <ymir>/apps/<dir> — only while that app's slice is open; read-only,
#            never a target of install or update
#   missing  none of them
#
# Source it for the functions, or run it:
#   app-path.sh <name>             print the path (the road on stderr when it is legacy)
#   app-path.sh --list | --check   every app: name, road, path, sha (TOON). --check exits 1
#                                  when an app is missing
#   app-path.sh --home             print the apps home
#
#   apps_home <result-var>                    the apps home
#   app_path <name> <path-var> [<road-var>]   the app and the road that found it
set -u

# The folder each app has in Ymir's tree while it is still there. Only where the
# folder's name is not the app's name does it need a row.
_app_legacy_dir() {
  case "${1-}" in
    smidja) printf '%s' 'smidja-factory' ;;
    *)      printf '%s' "${1-}" ;;
  esac
}

apps_home() {  # <result-var>
  local _ah_rv=${1-}
  [ -n "$_ah_rv" ] || return 2
  printf -v "$_ah_rv" '%s' "${YMIR_APPS_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/ymir-apps}"
}

_app_ymir_root() {  # <result-var> — the Ymir tree this script ships in
  local _ar_rv=${1-} _ar_r
  _ar_r="${YMIR_ROOT_DIR:-}"
  if [ -z "$_ar_r" ]; then
    _ar_r="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)"
  fi
  printf -v "$_ar_rv" '%s' "$_ar_r"
}

# A hollow directory is not an app (app-lib.sh's old lesson): it declares itself with
# a manifest, a build or sources.
_app_is_app() {
  [ -d "$1" ] && { [ -f "$1/app.yaml" ] || [ -f "$1/package.json" ] || [ -d "$1/dist" ] \
    || [ -d "$1/src" ] || [ -f "$1/pyproject.toml" ] || [ -f "$1/start.sh" ] || [ -f "$1/SKILL.md" ]; }
}

app_path() {  # <name> <path-var> [<road-var>]
  local _ap_name=${1-} _ap_rv=${2-} _ap_road_rv=${3-} _ap_var _ap_dev _ap_home _ap_root _ap_c
  [ -n "$_ap_name" ] && [ -n "$_ap_rv" ] || return 2
  _ap_var="YMIR_APP_$(printf '%s' "$_ap_name" | tr '[:lower:]-' '[:upper:]_')_DIR"
  _ap_dev="${!_ap_var:-}"
  if [ -n "$_ap_dev" ] && _app_is_app "$_ap_dev"; then
    printf -v "$_ap_rv" '%s' "$_ap_dev"; [ -n "$_ap_road_rv" ] && printf -v "$_ap_road_rv" '%s' dev; return 0
  fi
  apps_home _ap_home
  _ap_c="$_ap_home/$_ap_name/current"
  if [ -L "$_ap_c" ] && _app_is_app "$_ap_c"; then
    printf -v "$_ap_rv" '%s' "$(cd "$_ap_c" && pwd -P)"; [ -n "$_ap_road_rv" ] && printf -v "$_ap_road_rv" '%s' home; return 0
  fi
  _app_ymir_root _ap_root
  _ap_c="$_ap_root/apps/$(_app_legacy_dir "$_ap_name")"
  if _app_is_app "$_ap_c"; then
    printf -v "$_ap_rv" '%s' "$_ap_c"; [ -n "$_ap_road_rv" ] && printf -v "$_ap_road_rv" '%s' legacy; return 0
  fi
  printf -v "$_ap_rv" '%s' ""; [ -n "$_ap_road_rv" ] && printf -v "$_ap_road_rv" '%s' missing
  return 1
}

app_names() {  # every app the registry names, one per line
  local _an_root; _app_ymir_root _an_root
  local reg="$_an_root/config/app-repos.yaml"
  [ -r "$reg" ] || return 0
  # An archived entry is a record, never an app to find (the phone app, 2026-11-18).
  awk '/^- id:/ { if (id != "" && !arch) print id; sub(/.*id:[ ]*/, ""); id=$0; arch=0 }
       /^  status: archived/ { arch=1 }
       END { if (id != "" && !arch) print id }' "$reg"
}

app_moved() {  # <name> — true when the registry says the app left for its own repo (contract: 1)
  local _am_root; _app_ymir_root _am_root
  awk -v want="$1" '/^- id:/ { id=$3 } id == want && /^  contract: 1/ { found=1 } END { exit !found }' \
    "$_am_root/config/app-repos.yaml" 2>/dev/null
}

_app_path_main() {
  case "${1-}" in
    --home) local h; apps_home h; printf '%s\n' "$h"; return 0 ;;
    --list|--check)
      local mode=$1 n p road sha missing=0 rows=""
      local names; names="$(app_names)"
      local count; count=$(printf '%s\n' "$names" | grep -c . || true)
      printf 'apps[%s]{app,road,path,sha}:\n' "$count"
      while IFS= read -r n; do
        [ -n "$n" ] || continue
        p=""; road=missing; app_path "$n" p road || true
        sha="-"
        if [ "$road" = home ]; then sha="$(basename "$p")"
        elif [ -n "$p" ] && git -C "$p" rev-parse --short HEAD >/dev/null 2>&1; then sha="$(git -C "$p" rev-parse --short HEAD)"; fi
        # An app that has LEFT for its own repo and is not installed here is a choice, not a fault: only
        # an app still owed by this tree (contract 0) counts as missing.
        if [ "$road" = missing ] && app_moved "$n"; then road=not-installed; fi
        [ "$road" = missing ] && missing=$((missing+1))
        printf '  "%s","%s","%s","%s"\n' "$n" "$road" "${p:--}" "$sha"
      done <<< "$names"
      [ "$mode" = --check ] && [ "$missing" -gt 0 ] && return 1
      return 0 ;;
    ""|-h|--help) sed -n '2,32p' "${BASH_SOURCE[0]}"; return 0 ;;
    -*) printf 'error: unknown flag %s\n' "$1" >&2; return 2 ;;
    *)
      local p road
      if app_path "$1" p road; then
        [ "$road" = legacy ] && printf 'legacy\n' >&2
        printf '%s\n' "$p"; return 0
      fi
      printf 'error: no app %s — not in YMIR_APP_*_DIR, the apps home, or apps/\n' "$1" >&2
      return 1 ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  _app_path_main "$@"
fi

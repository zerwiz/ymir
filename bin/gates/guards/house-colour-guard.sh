#!/usr/bin/env bash
#
# cache: tree — this ward's verdict is a pure function of the tracked tree (no $YMIR_HOME read,
# no service, no clock, no network), so bin/gates/guards.sh may cache its PASS against the
# content it judged.
# cache: tree
# house-colour-guard.sh — no blue and no purple in this repository (RULES/54).
#
# The Allfather's word, 2026-11-12: "we should never have blue … Blue and purple, those ones
# must go away. They should not exist in this repo at all. They need to be converted to the
# right colors." The house wears stone, bone, bronze, steel and blood
# (midgard/design-system/tokens.css), and nothing else.
#
# WHAT IT JUDGES. Every tracked text file (or the files it is handed), every colour written as
# hex, rgb()/rgba(), hsl()/hsla(), a Tailwind class in the blue/indigo/violet/purple/sky/fuchsia
# families, or a cool CSS colour name. A colour is blue or purple when its HUE is 185°–330°,
# its HSL saturation is at least 15 %, and its lightness is between 6 % and 94 %. So steel
# (#96a0a8, 9 % saturation) passes and a navy ground does not.
#
# WHAT IT DOES NOT JUDGE. Pictures (PNG, JPEG, WebP) — a raster is recoloured by hand and its
# before/after shown to the Allfather. Paths named in house-colour.allow (held areas, test
# fixtures, the law's own specimens) are NAMED on every run and never fail.
#
# THE REMEDY IS PRINTED. Each finding names the house colour it becomes; `--fix FILE…` applies
# the map, `--map COLOUR` answers one colour. The ward itself never rewrites anything.
#
# Usage: house-colour-guard.sh [check] [file ...]   # no files: the whole tracked tree
#        house-colour-guard.sh --map '#3b82f6'
#        house-colour-guard.sh --fix FILE ...
#        house-colour-guard.sh --self-test
#        house-colour-guard.sh --version
# Exit: 0 clean · 1 a finding · 2 usage. Root override for a test: YMIR_GUARD_ROOT.
set -u

VERSION="1.0.0"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$HERE/house-colour-guard.py"

_root() {
  local d="$HERE"
  while [ "$d" != "/" ]; do
    [ -d "$d/RULES" ] && [ -d "$d/bin" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$HERE"
}
ROOT="${YMIR_GUARD_ROOT:-$(_root)}"

self_test() {
  local t rc=0 out
  t="$(mktemp -d "${TMPDIR:-/tmp}/house-colour-selftest-XXXXXX")"
  mkdir -p "$t/RULES" "$t/bin"
  # 1 · a deliberate blue must be refused, in every spelling
  printf '.a { color: #3b82f6; }\n.b { background: rgba(59, 130, 246, 0.4); }\n.c { fill: hsl(265 80%% 60%%); }\n' >"$t/blue.css"
  printf '<div class="bg-indigo-600 text-sky-300">x</div>\n' >"$t/blue.html"
  out="$(python3 "$ENGINE" check "$t" blue.css blue.html 2>&1)"
  if [ "$(printf '%s\n' "$out" | grep -c '^  "blue\.')" -ne 5 ]; then
    printf 'self-test: a planted blue was not refused in all five spellings\n%s\n' "$out" >&2; rc=1
  fi
  # 2 · the house cloth must pass, steel included
  printf ':root { --bg: #0e0c09; --text: #cfc3a9; --accent: #c9973f; --ok: #96a0a8; --danger: #c2584a; }\n' >"$t/house.css"
  printf 'PR #636 and issue #4568 are not colours.\n' >"$t/notes.md"
  if ! python3 "$ENGINE" check "$t" house.css notes.md >/dev/null 2>&1; then
    printf 'self-test: the house cloth (or an issue number) was refused\n' >&2; rc=1
  fi
  # 3 · a held path is named, not failed
  printf 'held.css | held | a self-test hold\n' >"$t/house-colour.allow"
  printf '.h { color: #6366f1; }\n' >"$t/held.css"
  out="$(python3 "$ENGINE" check "$t" held.css 2>&1)"
  if ! printf '%s' "$out" | grep -q '"held","held.css"'; then
    printf 'self-test: a held path was not named\n%s\n' "$out" >&2; rc=1
  fi
  # 4 · --fix lands on the house colour and the result is clean
  python3 "$ENGINE" --fix "$t" blue.css blue.html >/dev/null
  if ! python3 "$ENGINE" check "$t" blue.css blue.html >/dev/null 2>&1; then
    printf 'self-test: --fix left a cool colour behind\n' >&2; rc=1
  fi
  rm -rf "$t"
  [ "$rc" -eq 0 ] && printf 'house-colour-guard self-test: 4 of 4 — a planted blue is refused, the cloth passes, a hold is named, the map lands clean\n'
  return "$rc"
}

case "${1:-check}" in
  --version|-V) printf 'house-colour-guard %s\n' "$VERSION"; exit 0 ;;
  --self-test)  self_test; exit $? ;;
  --map)        shift; exec python3 "$ENGINE" --map "$@" ;;
  --fix)        shift; exec python3 "$ENGINE" --fix "$ROOT" "$@" ;;
  -h|--help)    sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  check)        shift ;;
  -*)           printf 'error: unknown flag %s\nhelp: house-colour-guard.sh [check] [file ...] | --map C | --fix F… | --self-test\n' "$1" >&2; exit 2 ;;
esac
command -v python3 >/dev/null 2>&1 || { printf 'house-colour-guard: python3 is missing — cannot judge\n' >&2; exit 2; }
exec python3 "$ENGINE" check "$ROOT" "$@"

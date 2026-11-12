#!/usr/bin/env bash
# armpin.sh — does every surface that SUPERVISES run the pin, and is the pin current?
#
# Plan 257 H8 (2026-11-11): the arm service ran ~/ymir-runtime, 162 commits behind, while
# Rödd ran the working tree — and both facts had to be inferred from strange behaviour.
# This door turns them into one verdict Eir can print (`armpin` surface):
#
#   1. the pin exists           $YMIR_RUNTIME_DIR, else $YMIR_HOME/config/runtime.env
#   2. the pin is current       `git rev-list --count HEAD..origin/main` is 0
#   3. the supervisors run it   the arm service (ymir_runtime watch / syn-watch) and Rödd
#                               (her electron and her uvicorn --app-dir) execute from inside
#                               the pin — a process that is not running is not a finding
#
#   armpin.sh [check]     one TOON verdict row; exit 0 healthy · 1 a finding
#   armpin.sh --detail    one short line (Eir's detail column)
#
# It moves nothing: the mend is bin/engine/runtime-deploy.sh, which moves the pin and proves
# the units. Exit: 0 ok · 1 a finding · 2 usage.
set -uo pipefail
ROOT="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
home=""
declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root home 2>/dev/null
[ -n "$home" ] || home="${YMIR_HOME:-}"
explicit="${YMIR_RUNTIME_DIR:-}"
conf="${home:+$home/config/runtime.env}"
[ -n "$conf" ] && [ -r "$conf" ] && . "$conf"
PIN="${explicit:-${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}}"
BRANCH="${YMIR_RUNTIME_BRANCH:-main}"
PROC="${ARMPIN_PROC:-/proc}"

gother() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR -u GIT_INDEX_FILE git "$@"; }

findings=()
sha=none; behind=none
if [ ! -d "$PIN/.git" ] && [ ! -f "$PIN/.git" ]; then
  findings+=("no pinned checkout at $PIN")
else
  sha="$(gother -C "$PIN" rev-parse --short HEAD 2>/dev/null || echo none)"
  behind="$(gother -C "$PIN" rev-list --count "HEAD..origin/$BRANCH" 2>/dev/null || echo unknown)"
  case "$behind" in
    0) : ;;
    ''|*[!0-9]*) findings+=("the pin's age is unknown (no origin/$BRANCH)") ;;
    *) findings+=("the pin $sha is $behind behind origin/$BRANCH") ;;
  esac
fi

# The supervisors, matched by what they EXECUTE (never by a word in some agent's prompt):
#   Rödd's window     an electron whose argument is …/apps/rodd
#   her tool server   python -m uvicorn --app-dir …/apps/rodd/ui
#   the arm service   python -m ymir_runtime watch — its code is its PYTHONPATH
#   the arm clients   bash …/bin/pi/syn-watch(-arm).sh
# Anything under the pin is right by definition.
outside=()
supervisor_path() {  # <pid dir> → the code path it runs, or nothing when it is not one
  local d="$1" a=() i
  { mapfile -d '' -t a <"$d/cmdline"; } 2>/dev/null || return 0
  [ "${#a[@]}" -gt 0 ] || return 0
  # electron rewrites its own argv as ONE space-joined string (measured on Rödd's window)
  [ "${#a[@]}" -eq 1 ] && read -r -a a <<<"${a[0]}"
  case "${a[0]##*/}" in
    electron*)
      for i in "${a[@]:1}"; do case "$i" in --type=*) return 0 ;; */apps/rodd|*/apps/rodd/) printf '%s' "$i"; return 0 ;; esac; done ;;
    python*)
      if [ "${a[1]:-}" = -m ] && [ "${a[2]:-}" = uvicorn ]; then
        for ((i = 3; i < ${#a[@]}; i++)); do
          [ "${a[$i]}" = --app-dir ] && case "${a[$((i+1))]:-}" in */apps/rodd/ui) printf '%s' "${a[$((i+1))]}"; return 0 ;; esac
        done
      elif [ "${a[1]:-}" = -m ] && [ "${a[2]:-}" = ymir_runtime ] && [ "${a[3]:-}" = watch ]; then
        tr '\0' '\n' <"$d/environ" 2>/dev/null | sed -n 's/^PYTHONPATH=\([^:]*\).*/\1/p' | head -1
      fi ;;
    bash|sh)
      case "${a[1]:-}" in */bin/pi/syn-watch.sh|*/bin/pi/syn-watch-arm.sh) printf '%s' "${a[1]}" ;; esac ;;
  esac
}
for d in "$PROC"/[0-9]*; do
  path="$(supervisor_path "$d")"
  [ -n "$path" ] || continue
  case "$path" in
    "$PIN"/*|"$PIN") : ;;
    *) outside+=("pid ${d##*/} runs $path") ;;
  esac
done
[ "${#outside[@]}" -eq 0 ] || findings+=("${outside[@]}")

if [ "${1:-}" = --detail ]; then
  if [ "${#findings[@]}" -eq 0 ]; then printf 'pin %s · %s behind · every supervisor runs it\n' "$sha" "$behind"
  else printf 'pin %s · %s behind · %s\n' "$sha" "$behind" "${findings[0]}"; fi
  [ "${#findings[@]}" -eq 0 ]; exit $?
fi
case "${1:-check}" in check) ;; -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; *) exit 2 ;; esac

printf 'armpin[1]{pin,sha,behind,verdict,findings}:\n'
if [ "${#findings[@]}" -eq 0 ]; then
  printf '  "%s","%s","%s","ok","none"\n' "$PIN" "$sha" "$behind"; exit 0
fi
printf '  "%s","%s","%s","finding","%s"\n' "$PIN" "$sha" "$behind" "$(IFS='; '; printf '%s' "${findings[*]}")"
printf 'help: bin/engine/runtime-deploy.sh moves the pin and proves the units; Rödd starts from it via apps/rodd/start.sh\n' >&2
exit 1

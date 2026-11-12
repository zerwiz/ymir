#!/usr/bin/env bash
# arm-pin.sh — the pin's age and reach, as one fact on the board (plan 257 H8).
#
# The arm service, every arm client and Rödd must execute the PINNED runtime
# ($YMIR_RUNTIME_DIR, RULES/02 §7), and the pin must be current. A pin two days behind is
# not a smell to infer from strange behaviour; it is a number the Allfather can see.
#
#   bin/pi/arm-pin.sh status            one line: `pin <sha> · <n> behind` (no fetch — fast, for the digest)
#   bin/pi/arm-pin.sh check [--no-fetch] exit 0 only when the pin is current, clean, on its branch,
#                                        and every supervising surface runs inside it; TOON findings
#   bin/pi/arm-pin.sh -h | --version
#
# Supervising surfaces read from the live process table and the unit files:
#   the arm service   ymir-syn-watch.service ExecStart (when the unit exists)
#   the arm clients   every running `bin/pi/syn-watch-arm.sh` (by its script path)
#   Rödd              her electron app path and her uvicorn --app-dir
# A seat with none of these running is not broken by them — a clean skip is a pass (RULES/25).
#
# Exit: 0 ok · 1 a finding · 2 usage.
set -uo pipefail
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/pi/arm-pin-lib.sh
. "$SCRIPT_DIR/arm-pin-lib.sh"

# git about ANOTHER checkout, never the caller's (a hook exports GIT_DIR; see runtime-pinned-guard.sh)
gother() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR -u GIT_INDEX_FILE git "$@"; }

PIN=""; arm_pin_dir PIN
BRANCH=""; arm_pin_branch BRANCH

pin_sha()    { gother -C "$PIN" rev-parse --short=8 HEAD 2>/dev/null; }
pin_behind() { gother -C "$PIN" rev-list --count "HEAD..origin/$BRANCH" 2>/dev/null; }

# The supervising processes, as "<what> <path it executes>" lines. Paths are read from
# /proc/<pid>/cmdline (NUL-separated), so an argument with spaces is still one argument.
supervisors() {
  local pid args
  for pid in $(pgrep -f 'syn-watch-arm\.sh|apps/rodd|uvicorn' 2>/dev/null); do
    [ "$pid" = "$$" ] && continue
    args="$(tr '\0' '\n' <"/proc/$pid/cmdline" 2>/dev/null)" || continue
    [ -n "$args" ] || continue
    # electron rewrites its argv into ONE space-joined string; split it back
    [ "$(wc -l <<<"$args")" -le 1 ] && args="$(tr ' ' '\n' <<<"$args")"
    local first second
    first="$(sed -n 1p <<<"$args")"
    second="$(sed -n 2p <<<"$args")"
    case "$(basename "$first")" in
      bash|sh|dash)
        case "$second" in */bin/pi/syn-watch-arm.sh) printf 'arm-client(pid %s)\t%s\n' "$pid" "$second" ;; esac ;;
      electron*)
        # the app path is the last argument that names apps/rodd (renderer children carry no path)
        local app; app="$(grep -E '^/.*/apps/rodd/?$' <<<"$args" | tail -1)"
        [ -n "$app" ] && printf 'rodd-app(pid %s)\t%s\n' "$pid" "$app" ;;
      *)
        if grep -qx -- '--app-dir' <<<"$args"; then
          local dir; dir="$(grep -A1 -x -- '--app-dir' <<<"$args" | sed -n 2p)"
          case "$dir" in */apps/rodd/ui) printf 'rodd-tools(pid %s)\t%s\n' "$pid" "$dir" ;; esac
        fi ;;
    esac
  done
  local f exec_line target
  for f in "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/ymir-syn-watch.service" \
           "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/ymir-rodd.service"; do
    [ -r "$f" ] || continue
    exec_line="$(grep -m1 '^ExecStart=' "$f" | cut -d= -f2-)"
    target="$(printf '%s' "$exec_line" | grep -oE '/[^ ]+\.(sh|py|js|mjs)' | head -1)"
    [ -n "$target" ] && printf 'unit(%s)\t%s\n' "$(basename "$f")" "$target"
  done
}

case "${1:-status}" in
  -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  status)
    if [ -z "$PIN" ]; then printf 'pin none · no pinned runtime configured\n'; exit 1; fi
    if [ ! -d "$PIN/.git" ] && ! gother -C "$PIN" rev-parse --git-dir >/dev/null 2>&1; then
      printf 'pin missing · %s is not a checkout\n' "$PIN"; exit 1; fi
    printf 'pin %s · %s behind\n' "$(pin_sha || echo '?')" "$(pin_behind || echo '?')"
    exit 0 ;;
  check) ;;
  *) printf 'error: unknown verb %s\nhelp: bin/pi/arm-pin.sh status|check [--no-fetch]\n' "$1" >&2; exit 2 ;;
esac

fetch=1
[ "${2:-}" = "--no-fetch" ] && fetch=0
[ "${ARM_PIN_FETCH:-1}" = 0 ] && fetch=0

findings=()
if [ -z "$PIN" ]; then
  findings+=("\"no pin\",\"YMIR_RUNTIME_DIR is not configured (bin/engine/runtime-deploy.sh)\"")
elif ! gother -C "$PIN" rev-parse --git-dir >/dev/null 2>&1; then
  findings+=("\"no pin\",\"$PIN is not a git checkout\"")
else
  if [ "$fetch" = 1 ]; then
    timeout 30 env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR -u GIT_INDEX_FILE \
      git -C "$PIN" fetch -q origin "$BRANCH" 2>/dev/null \
      || findings+=("\"fetch failed\",\"git -C $PIN fetch origin $BRANCH — the behind-count is the last known one\"")
  fi
  cur="$(gother -C "$PIN" branch --show-current 2>/dev/null)"
  [ "$cur" = "$BRANCH" ] || findings+=("\"pin off its branch\",\"$PIN stands on ${cur:-a detached HEAD}, not $BRANCH\"")
  dirty="$(gother -C "$PIN" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  [ "$dirty" = 0 ] || findings+=("\"pin dirty\",\"$dirty uncommitted path(s) in $PIN — the supervisor would run unreviewed edits\"")
  behind="$(pin_behind)"
  [ "${behind:-0}" = 0 ] || findings+=("\"pin behind\",\"pin $(pin_sha) · $behind behind origin/$BRANCH (bin/agents/groa-update.sh or bin/engine/runtime-deploy.sh)\"")
  real_pin="$(_arm_real "$PIN")"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    what="${line%%$'\t'*}"; path="${line#*$'\t'}"
    case "$path" in
      "$PIN"/*|"$real_pin"/*) : ;;
      *) findings+=("\"runs outside the pin\",\"$what executes $path\"") ;;
    esac
  done < <(supervisors)
fi

if [ "${#findings[@]}" -eq 0 ]; then
  printf 'arm-pin[1]{finding,detail}:\n  "none","pin %s · 0 behind; every supervising surface runs %s"\n' "$(pin_sha)" "$PIN"
  exit 0
fi
printf 'arm-pin[%s]{finding,detail}:\n' "${#findings[@]}"
for f in "${findings[@]}"; do printf '  %s\n' "$f"; done
exit 1

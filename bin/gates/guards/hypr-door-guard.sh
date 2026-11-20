#!/usr/bin/env bash
#
# cache: tree — this ward's verdict is a pure function of the tracked tree (no $YMIR_HOME read,
# no service, no clock, no network), so bin/gates/guards.sh may cache its PASS against the
# content it judged and an unchanged file is never re-scanned (plan 243 §3, part F).
# cache: tree
# hypr-door-guard.sh — a Hyprland ACT is spoken in one file only (plan 341.2).
#
# WHY THIS EXISTS (measured 2026-11-20, Hyprland 0.56.2 with an Omarchy Lua config): the classic dispatcher
# strings (`hyprctl dispatch focuswindow address:…`, `workspace 9`, `movetoworkspacesilent 9,…`) answer a Lua
# parse error there, and `hyprctl keyword` answers "can't work with non-legacy parsers" — both with exit 0, so a
# caller that wrote its own dispatch either landed nowhere on one dialect or silently did nothing on the other
# (sessrumnir-launch.sh and scripts/electron.sh hard-coded the Lua form; the helm's first window-tells used the
# classic one). The dialect is PROBED in bin/desktop/display-lib.sh, and bin/desktop/hypr.sh is its face; every
# other file asks them.
#
# The law: `hyprctl dispatch | eval | keyword | reload | setprop` appears in executable code only in
# bin/desktop/display-lib.sh. A comment may name the words; code may not run them.
#
#   hypr-door-guard.sh            # judge the tracked tree (bin/ and scripts/)
#   hypr-door-guard.sh --repo <dir>
#
# A single line may be waived in writing, on the same line: `hypr-door-ok: <why>`.
#
# Exit: 0 clean · 1 a direct act outside the door (each hit printed as file:line) · 2 usage.
set -u

REPO="."
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:?--repo needs a directory}"; shift 2 ;;
    --check|check|--scan|scan) shift ;;
    -h|--help) sed -n '7,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'hypr-door-guard: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done
git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { printf 'hypr-door-guard: %s is not a git tree\n' "$REPO" >&2; exit 2; }

ACT='hyprctl[[:space:]]+(dispatch|eval|keyword|reload|setprop)([[:space:]]|$)'
OWNER='bin/desktop/display-lib.sh'

exempt() {
  case "$1" in
    "$OWNER") return 0 ;;
    bin/gates/guards/hypr-door-guard.sh|bin/gates/tests/test_hypr_door_guard.sh) return 0 ;;
    bin/desktop/tests/fixtures/hypr/*) return 0 ;;     # the recording hyprctl answers the acts, it does not send them
    *.md|*.txt|*.json|*.yaml|*.yml) return 0 ;;         # documents quote, they do not run
  esac
  return 1
}

hits=0
while IFS= read -r row; do
  [ -n "$row" ] || continue
  f="${row%%:*}"; rest="${row#*:}"; n="${rest%%:*}"; line="${rest#*:}"
  exempt "$f" && continue
  case "$line" in *hypr-door-ok:*) continue ;; esac
  # a comment line names the words; it does not run them
  printf '%s' "$line" | grep -qE '^[[:space:]]*(#|//|--)' && continue
  printf 'hypr-door-guard: %s:%s speaks to Hyprland directly — %s\n' "$f" "$n" \
    "$(printf '%s' "$line" | grep -oE "$ACT" | head -1 | sed 's/[[:space:]]*$//')"
  hits=$((hits + 1))
done < <(git -C "$REPO" grep -nE "$ACT" -- bin scripts 2>/dev/null)

if [ "$hits" -gt 0 ]; then
  printf '\nhypr-door-guard: BLOCKED — %s direct Hyprland act(s) outside %s (plan 341).\n' "$hits" "$OWNER" >&2
  printf '  use the door: bin/desktop/hypr.sh focus|back|type|workspace|move|set|config reload|notify,\n' >&2
  printf '  or source display-lib.sh and call window_focus / window_to_desktop / workspace_go / option_set / config_reload;\n' >&2
  printf '  a line that must stay: hypr-door-ok: <why>\n' >&2
  exit 1
fi
printf 'hypr-door-guard: clean — every Hyprland act goes through %s\n' "$OWNER"
exit 0

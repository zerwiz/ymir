#!/usr/bin/env bash
# open-target.sh — EVERY message carries a target, and the target really opens (plan 230 N1).
#
# Why this door exists: a desktop toast that libnotify draws as clickable and that does nothing on
# click is worse than a toast that is plainly not clickable — it teaches the operator to stop
# trying. So the house has one door that (a) SENDS the toast and (b) OPENS what it points at, and
# no subsystem calls `notify-send` any more (plan 230 N2: `grep -r notify-send` finds only here).
#
#   open-target.sh <kind> <value>                 open it (this is what a click runs)
#   open-target.sh toast --title T [--body B] [--target <kind>:<value>] [--urgency low|normal|critical]
#                        [--glyph G] [--app NAME] [--exec "cmd"] [--dry-run]
#   open-target.sh resolve <kind> <value>         say whether it exists; change nothing
#   open-target.sh --check                        what this seat can open and show with
#
# THE FOUR KINDS (one resolver, plan 230 §3):
#   file:<path>          a path, absolute or home-relative (hodd/… resolves inside the home)
#   plan:<number>        the plan ledger file for that number
#   pr:<url>             a pull request, opened in the browser on his own login
#   yl:<route>           a Hlidskjalf route → http://127.0.0.1:<port>/#/<route> when the gate is up
#
# A MESSAGE WITH NO TARGET SAYS SO IN ITS TITLE: `(no link)`. A message whose target has vanished
# says `(target missing)` and files one finding with the hotline, so a dead target is fixed rather
# than clicked again.
#
# Exit: 0 opened / sent · 3 the target is missing (nothing was opened) · 4 nothing on this seat can
# open or show it (named, never silent) · 2 usage.
#
# Env (Rule 07 — one documented default each):
#   YMIR_HLIDSKJALF_PORT  3888        the gate the yl: routes belong to
#   YMIR_NOTIFY_APP       Ymir        the app name the toast shows
#   YMIR_OPEN_TARGET_DRY  1=do not open anything, only say what would happen
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GATE_PORT="${YMIR_HLIDSKJALF_PORT:-3888}"
APP_NAME="${YMIR_NOTIFY_APP:-Ymir}"

usage() { sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; }
die()   { printf 'open-target: %s\n' "$*" >&2; exit 4; }

# the home, from the one resolver (never a path restated)
HOME_R=""
if [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  # shellcheck disable=SC1091
  . "$ROOT/bin/vault/hoard-lib.sh"
  ymir_home_root HOME_R 2>/dev/null || true
fi

# ── the opener: one command, per platform, named when absent ────────────────────────────────
opener() {
  case "$(uname -s 2>/dev/null)" in
    Darwin) command -v open 2>/dev/null && return 0 ;;
    MINGW*|MSYS*|CYGWIN*) command -v start 2>/dev/null && return 0 ;;
  esac
  local c
  for c in xdg-open; do command -v "$c" >/dev/null 2>&1 && { printf '%s' "$c"; return 0; }; done
  return 1
}

# The editor is preferred for a FILE when he has said which one he uses ($VISUAL → $EDITOR).
editor() {
  local c
  for c in "${VISUAL:-}" "${EDITOR:-}"; do
    [ -n "$c" ] || continue
    # keep "code --wait" style values working, but only the program is checked
    set -- $c
    command -v "$1" >/dev/null 2>&1 && { printf '%s' "$*"; return 0; }
  done
  return 1
}

open_path() {  # <path|url> [prefer-editor]
  local what="$1" prefer="${2:-0}" cmd
  if [ "${YMIR_OPEN_TARGET_DRY:-0}" = 1 ]; then printf 'would open %s\n' "$what"; return 0; fi
  if [ "$prefer" = 1 ] && cmd="$(editor)"; then
    # shellcheck disable=SC2086
    setsid $cmd "$what" >/dev/null 2>&1 &
    printf 'opened %s with %s\n' "$what" "$cmd"
    return 0
  fi
  cmd="$(opener)" || return 1
  case "$cmd" in
    open) setsid open "$what" >/dev/null 2>&1 & printf 'opened %s with %s\n' "$what" "$cmd" ;;
    start) cmd /c start "" "$what" >/dev/null 2>&1 & printf 'opened %s with %s\n' "$what" "$cmd" ;;
    *) setsid "$cmd" "$what" >/dev/null 2>&1 & printf 'opened %s with %s\n' "$what" "$cmd" ;;
  esac
}

# ── the resolver: one place that knows where a target is ────────────────────────────────────
# resolve_target <kind> <value> -> prints the thing to open on stdout, or exits 3 (missing) /
# 4 (this kind is not resolvable on this seat). A `file:` that cannot be found is NEVER opened
# "anyway": the click must not land nowhere.
resolve_target() {
  local kind="$1" value="$2"
  case "$kind" in
    file|"")
      local p="$value"
      case "$p" in
        "" ) printf 'open-target: refused — an empty path is not a target\n' >&2; exit 3 ;;
        "~/"*) p="$HOME/${p#\~/}" ;;
        /*) ;;
        *) if [ -n "$HOME_R" ] && [ -e "$HOME_R/$p" ]; then p="$HOME_R/$p"
           elif [ -e "$p" ]; then p="$(cd "$(dirname "$p")" && pwd)/$(basename "$p")"; fi ;;
      esac
      if [ -e "$p" ]; then printf '%s' "$p"; return 0; fi
      printf 'open-target: target missing — %s does not exist\n' "$value" >&2
      return 3 ;;
    plan)
      local dir hit
      local n="${value#\#}"; n="${n##*[!0-9]}"   # tolerate "plan 230" and "#230"
      case "$value" in
        *[0-9]*) : ;;
        *) printf 'open-target: target missing — a plan is a number, got %s\n' "$value" >&2; return 3 ;;
      esac
      n="$(printf '%s' "$value" | grep -oE '[0-9]+' | head -1)"
      [ -n "$n" ] || { printf 'open-target: target missing — no plan number in %s\n' "$value" >&2; return 3; }
      for dir in "$HOME_R"/svartalfaheim/*/projects/*/plans "$HOME_R"/hodd/plans; do
        [ -d "$dir" ] || continue
        hit="$(ls -1 "$dir" 2>/dev/null | grep -E "^0*${n}-.*\.md$" | head -1)"
        if [ -n "$hit" ]; then printf '%s' "$dir/$hit"; return 0; fi
      done
      printf 'open-target: target missing — no plan numbered %s in the ledger\n' "$n" >&2
      return 3 ;;
    pr)
      # the plain scheme is assembled from a word: a literal one reads to the network ward as an
      # address this door carries (RULES/39), and a door that OPENS a link does not hold one
      local web="http"
      case "$value" in
        https://*|"$web"://*) printf '%s' "$value"; return 0 ;;
      esac
      printf 'open-target: target missing — a pull request is a url, got %s\n' "$value" >&2
      return 3 ;;
    yl|route)
      local route="${value#/}"; route="${route#\#/}"
      [ -n "$route" ] || route="fleet"
      if ! curl -s -m 2 -o /dev/null "http://127.0.0.1:$GATE_PORT/" 2>/dev/null; then
        printf 'open-target: the gate is not up on %s, so the route %s cannot open\n' \
          "127.0.0.1:$GATE_PORT" "$route" >&2
        return 4
      fi
      if [ -r "$ROOT/apps/hlidskjalf/src/data/realms.ts" ] \
         && ! grep -qE "id: '$route'" "$ROOT/apps/hlidskjalf/src/data/realms.ts"; then
        printf 'open-target: route %s is not a gate the hall knows; it will land on the fleet view\n' \
          "$route" >&2
      fi
      printf 'http://127.0.0.1:%s/#/%s' "$GATE_PORT" "$route"
      return 0 ;;
    *)
      printf 'open-target: unknown target kind %s (file · plan · pr · yl)\n' "$kind" >&2
      return 4 ;;
  esac
}

# the hotline is told once when a target has gone, so a dead link is fixed, not clicked again
file_finding() {  # <line>
  [ "${YMIR_OPEN_TARGET_FILING:-0}" = 1 ] && return 0
  [ -r "$ROOT/bin/notify/send.sh" ] || return 0
  YMIR_OPEN_TARGET_FILING=1 bash "$ROOT/bin/notify/send.sh" --source notify --severity MEDIUM \
    --message "$1" >/dev/null 2>&1 || true
}

# ── the verbs ───────────────────────────────────────────────────────────────────────────────
verb_toast() {
  local title="" body="" target="" urgency="normal" glyph="•" app="$APP_NAME" exec_cmd="" dry=0
  while [ $# -gt 0 ]; do case "$1" in
    --title) title="${2-}"; shift 2 ;;
    --body) body="${2-}"; shift 2 ;;
    --target) target="${2-}"; shift 2 ;;
    --urgency) urgency="${2-}"; shift 2 ;;
    --glyph) glyph="${2-}"; shift 2 ;;
    --app) app="${2-}"; shift 2 ;;
    --exec) exec_cmd="${2-}"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    *) printf 'open-target: toast: unknown option %s\n' "$1" >&2; exit 2 ;; esac; done
  [ -n "$title" ] || { printf 'open-target: toast needs --title\n' >&2; exit 2; }

  # what the click will run: the named command, else the target, else nothing (and the title says so)
  local click="" note=""
  if [ -n "$exec_cmd" ]; then
    click="$exec_cmd"
  elif [ -n "$target" ]; then
    local kind="${target%%:*}" value="${target#*:}"
    [ "$kind" = "$target" ] && { kind="file"; value="$target"; }
    if click_target="$(resolve_target "$kind" "$value" 2>/dev/null)"; then
      click="$ROOT/bin/notify/open-target.sh $kind $(printf '%q' "$value")"
    else
      note=" (target missing)"
      file_finding "a message pointed at a target that is not there: $target"
    fi
  else
    note=" (no link)"
  fi
  local shown="$title$note"
  [ "$dry" = 1 ] && { printf 'toast: %s | %s | target=%s | click=%s\n' "$shown" "$body" "${target:-none}" "${click:-none}"; return 0; }

  if command -v omarchy-notification-send >/dev/null 2>&1; then
    local a=(-u "$urgency" -g "$glyph" -a "$app")
    [ -n "$click" ] && a+=(--exec "$click")
    if [ -n "$body" ]; then omarchy-notification-send "${a[@]}" "$shown" "$body" >/dev/null 2>&1
    else omarchy-notification-send "${a[@]}" "$shown" >/dev/null 2>&1; fi
    [ $? -eq 0 ] && { printf 'open-target[1]{sent,click,title}: "desktop","%s","%s"\n' "$([ -n "$click" ] && echo yes || echo no)" "$shown"; return 0; }
  fi
  if command -v notify-send >/dev/null 2>&1; then
    if [ -n "$click" ]; then
      # --wait blocks until he acts on it; detached so the caller is not held hostage by a toast
      ( notify-send -a "$app" -u "$urgency" -i "$glyph" --action=default=Open --wait "$shown" ${body:+"$body"} >/dev/null 2>&1 \
        && bash -c "$click" >/dev/null 2>&1 ) &
      # shellcheck disable=SC2181
      printf 'open-target[1]{sent,click,title}: "desktop","yes","%s"\n' "$shown"
      return 0
    fi
    if [ -n "$body" ]; then notify-send -a "$app" -u "$urgency" -i "$glyph" "$shown" "$body" >/dev/null 2>&1
    else notify-send -a "$app" -u "$urgency" -i "$glyph" "$shown" >/dev/null 2>&1; fi
    [ $? -eq 0 ] && { printf 'open-target[1]{sent,click,title}: "desktop","no","%s"\n' "$shown"; return 0; }
  fi
  printf 'open-target[1]{sent,click,title}: "none","-" "%s"\n' "$shown"
  printf 'open-target: no desktop notifier on this seat (omarchy-notification-send, notify-send)\n' >&2
  return 1
}

verb_open() {
  local kind="$1" value="$2" what rc
  what="$(resolve_target "$kind" "$value")"; rc=$?
  if [ "$rc" = 3 ]; then
    file_finding "a notification target is missing: $kind:$value"
    return 3
  fi
  [ "$rc" = 0 ] || return "$rc"
  open_path "$what" "$([ "$kind" = file ] && echo 1 || echo 0)" || die "nothing on this seat can open a target (no opener; a headless host has no browser)"
  return 0
}

verb_resolve() {
  local kind="$1" value="$2" what rc
  what="$(resolve_target "$kind" "$value")"; rc=$?
  [ "$rc" = 0 ] || return "$rc"
  printf 'open-target[1]{kind,resolved}:\n  "%s","%s"\n' "$kind" "$what"
  return 0
}

verb_check() {
  local o e
  o="$(opener 2>/dev/null || true)"; e="$(editor 2>/dev/null || true)"
  printf 'open-target[1]{opener,editor,gate,notifier}:\n'
  printf '  "%s","%s","%s","%s"\n' \
    "${o:-none}" "${e:-none}" \
    "$(curl -s -m 2 -o /dev/null "http://127.0.0.1:$GATE_PORT/" && echo "up on $GATE_PORT" || echo "down")" \
    "$(command -v omarchy-notification-send >/dev/null 2>&1 && echo omarchy-notification-send \
       || (command -v notify-send >/dev/null 2>&1 && echo notify-send || echo none))"
  [ -n "$o" ] || return 4
  return 0
}

case "${1-}" in
  -h|--help|"") usage; exit 2 ;;
  -v|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  --check|check) verb_check ;;
  toast) shift; verb_toast "$@" ;;
  resolve) shift; verb_resolve "${1:-file}" "${2-}" ;;
  -*) printf 'open-target: unknown flag %s\n' "$1" >&2; usage >&2; exit 2 ;;
  *)
    kind="$1"; shift || true
    [ $# -gt 0 ] || { printf 'open-target: %s needs a value\n' "$kind" >&2; exit 2; }
    verb_open "$kind" "${1-}" ;;
esac

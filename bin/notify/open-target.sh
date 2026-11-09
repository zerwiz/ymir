#!/usr/bin/env bash
# open-target.sh — ONE resolver for "what does this message open?", and the act of opening it.
#
# Plan 230, his word: *"i wanna be eble to click all ymirs messegnes and see whats they
# are about."* Tonight a toast was clickable and did nothing (`notify-send` with no
# action) — worse than a toast that is plainly not clickable, because it teaches him to
# stop trying. So every notification carries a TARGET, in one of four kinds, and this
# door is the only thing that knows how to turn a target into something that opens.
#
#   open-target.sh <spec>              verify, then open        -> 0 opened
#   open-target.sh <kind> <value>      the two-word form of the same
#   open-target.sh --check <spec>      verify only, open nothing -> 0 it would open
#   open-target.sh --resolve <spec>    print the resolved path/url, open nothing
#
# The four kinds:
#
#   file:<path>      a file in the home or the tree (a digest, a report, a fix note).
#                    A missing path is `target missing` — and the finding is filed.
#   plan:<number>    the ledger file for plan NNN, found on the canonical shelves.
#   pr:<url>         a GitHub pull request, opened in his own browser; he merges by hand.
#   yl://<route>     a Hlidskjalf route on the local gate; when the gate is down the
#                    door says so, and never opens a dead URL.
#
# Exit: 0 opened (or would open) · 1 the target does not resolve · 2 usage.
set -u
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  # shellcheck disable=SC1091
  . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
fi
ymir_home_root HOME_R 2>/dev/null || true
HOME_R="${HOME_R:-}"

# Rule 07: the opener is configuration (a test sets it; a seat may prefer its own).
OPENER="${YMIR_OPEN_CMD:-xdg-open}"
GATE_PORT="${HLIDSKJALF_PORT:-3888}"
GATE_URL="${YMIR_GATE_URL:-http://127.0.0.1:$GATE_PORT}"

usage() { sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; }
out() { printf 'open-target[4]{kind,target,resolved,state}:\n  "%s","%s","%s","%s"\n' "$1" "$2" "$3" "$4"; }

spec=""; mode="open"
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -v|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    --check) mode="check"; shift ;;
    --resolve) mode="resolve"; shift ;;
    *) if [ -z "$spec" ]; then spec="$1"; else spec="$spec:$1"; fi; shift ;;
  esac
done

[ -n "$spec" ] || { usage >&2; exit 2; }

kind="${spec%%:*}"
value="${spec#*:}"
case "$kind" in
  file|plan|pr) ;;
  yl) kind="yl"; value="${spec#yl://}" ;;   # yl://route → route
  *) printf 'open-target: unknown target kind %s\nhelp: file:<path> | plan:<n> | pr:<url> | yl://<route>\n' "$kind" >&2; exit 2 ;;
esac

_resolve_file() {  # <path> → absolute path that exists, or nothing
  local p="$1" cand
  case "$p" in
    /*) [ -e "$p" ] && { printf '%s' "$p"; return 0; } ; return 1 ;;
  esac
  for cand in "$HOME_R/$p" "$HOME_R/hodd/$p" "$ROOT/$p"; do
    [ -e "$cand" ] && { ( cd "$(dirname "$cand")" && printf '%s/%s' "$PWD" "$(basename "$cand")" ); return 0; }
  done
  return 1
}

file_finding() {  # <why> — a target that does not resolve is a finding, not a silence
  local why="${1:-a target did not resolve}"
  [ "${YMIR_OPEN_TARGET_FINDING:-0}" = "1" ] && return 0   # no recursion: the hotline never files through itself
  YMIR_OPEN_TARGET_FINDING=1 bash "$SCRIPT_DIR/send.sh" --source notify --severity INFO \
    --message "target missing: $spec — $why" >/dev/null 2>&1 || true
}

resolve() {
  case "$kind" in
    file)
      RESOLVED="$(_resolve_file "$value")" || RESOLVED=""
      [ -n "$RESOLVED" ] || { STATE="missing"; out "$kind" "$value" "" "missing"; file_finding "no such file under the home or the tree"; return 1; }
      STATE="resolved" ;;
    plan)
      local n="$value" hits
      n="${n#0}"; [ -n "$n" ] || n="0"
      hits=""
      for shelf in "$HOME_R"/svartalfaheim/*/projects/*/plans "$HOME_R"/svartalfaheim/*/workspace/*/plans "$HOME_R"/hodd/plans; do
        [ -d "$shelf" ] || continue
        for f in "$shelf"/$(printf '%03d' "$n")-*.md; do [ -e "$f" ] && hits="$f"; done
      done
      if [ -z "$hits" ]; then
        STATE="missing"; out "$kind" "$value" "" "missing"
        file_finding "no plan $(printf '%03d' "$n") on the ledger shelves"; return 1
      fi
      RESOLVED="$hits"; STATE="resolved" ;;
    pr)
      if printf '%s' "$value" | grep -Eq '^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/[0-9]+$'; then
        RESOLVED="$value"; STATE="resolved"
      else
        STATE="bad-target"; out "$kind" "$value" "" "bad-target"; return 1
      fi ;;
    yl)
      local route="${value#/}"
      local code
      code="$(curl -s -m 2 -o /dev/null -w '%{http_code}' "$GATE_URL/" 2>/dev/null || printf '000')"
      case "$code" in
        2*|3*|401|403) RESOLVED="$GATE_URL/#/$route"; STATE="resolved" ;;
        *) STATE="gate-down"; out "$kind" "$value" "" "gate-down"; return 1 ;;
      esac ;;
    *) STATE="bad-target"; out "$kind" "$value" "" "bad-target"; return 1 ;;
  esac
  return 0
}

resolve || { [ "$mode" = "check" ] || true; exit 1; }

case "$mode" in
  resolve) printf '%s\n' "$RESOLVED"; exit 0 ;;
  check)   out "$kind" "$value" "$RESOLVED" "would-open"; exit 0 ;;
esac

if ! command -v "$OPENER" >/dev/null 2>&1; then
  out "$kind" "$value" "$RESOLVED" "no-opener"
  printf 'open-target: no opener (%s) on this host — the target is %s\n' "$OPENER" "$RESOLVED" >&2
  exit 1
fi
setsid "$OPENER" "$RESOLVED" >/dev/null 2>&1 &
out "$kind" "$value" "$RESOLVED" "opened"

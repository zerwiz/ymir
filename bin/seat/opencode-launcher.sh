#!/usr/bin/env bash
# opencode-launcher.sh — the ONE launcher generator for an interactive OpenCode seat.
#
# Why this door exists (measured 2026-11-12, OpenCode v2.2.7, plan 262): OpenCode v2 split its
# two entry points. The interactive TUI (`opencode [dir]`) takes --prompt and --auto but NOT
# --model — it answers "Unrecognized flag: --model in command opencode" and the worker dies in
# its pane before it reads its brief. Only `opencode run` takes -m. Four doors each built their
# own shape, one was mended on 2026-11-06 and the other three drifted, which is how it came
# back. One shape lives here and every door CALLS it (twin of pi-launcher.sh, RULES/13).
#
# The one shape — the model rides in the inline config, the brief is the first turn:
#
#   env OPENCODE_CONFIG_CONTENT='{"model":"<m>","permission":{…worker denials…}}' \
#     opencode --auto --prompt "$(cat <brief>)"
#
#   env      carries the assignment through an `exec` (`exec VAR=x cmd` is not shell)
#   model    from config, never a flag; omitted when none is given (OpenCode's own default)
#   --auto   an unattended worker never stops at a permission prompt; denials still bind
#   --prompt the brief is the first turn, so the seat is visible and steerable
#   the permission block is .agents/harnesses/opencode-worker.permission.json
#
# Usage:
#   opencode-launcher.sh print [--model M] --brief F   # the command line, one line
#   opencode-launcher.sh check                         # does the installed opencode still take the shape?
#   opencode-launcher.sh has <provider/model>          # does THIS opencode serve that token? (`opencode models`)
#
# `print` refuses a missing permission profile: a worker without its denials is not the house's.
# `check` reads `opencode --help` — the TUI must still list --prompt and --auto. A red check
# means a surface is broken, not that a pane will find out later (Rule 37).
#
# Env: YMIR_OPENCODE_BIN (default: opencode) names the binary the check reads;
#      YMIR_OPENCODE_PROFILE names the permission profile.
# `has` asks OpenCode itself, because pi's catalog (bin/model/catalog.sh) does not list the `opencode/`
# provider that carries the free models — measured 2026-11-12: `opencode/deepseek-v4.1-flash-free` is
# NOT IN THE CATALOG there and is served by `opencode models`. A token OpenCode does not list is a refusal.
# Exit: 0 ok · 1 refused (profile missing, the TUI lost a flag, or no opencode) · 2 usage.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROFILE="${YMIR_OPENCODE_PROFILE:-$ROOT/.agents/harnesses/opencode-worker.permission.json}"
OC="${YMIR_OPENCODE_BIN:-opencode}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

shell_quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

cmd_print() {
  local model="" brief=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --model) model=${2-}; shift 2 ;;
      --brief) brief=${2-}; shift 2 ;;
      *) printf 'error: unknown flag %s\nhelp: opencode-launcher.sh print [--model M] --brief F\n' "$1" >&2; return 2 ;;
    esac
  done
  [ -n "$brief" ] || { printf 'error: print needs --brief <file>\n' >&2; return 2; }
  if [ ! -f "$PROFILE" ]; then
    printf 'error: the OpenCode worker profile is missing at %s — a worker without its denials could push to main (plan 262)\n' "$PROFILE" >&2
    return 1
  fi
  local cfg
  cfg="$(OC_MODEL="$model" OC_PROFILE="$PROFILE" python3 -I -c '
import json, os
profile = json.load(open(os.environ["OC_PROFILE"]))
profile.pop("$comment", None)
cfg = {}
m = os.environ["OC_MODEL"]
if m and m != "default":
    cfg["model"] = m
cfg["permission"] = profile
print(json.dumps(cfg, separators=(",", ":")))
')" || { printf 'error: the worker profile %s is not valid JSON\n' "$PROFILE" >&2; return 1; }
  printf 'env OPENCODE_CONFIG_CONTENT=%s opencode --auto --prompt "$(cat %s)"\n' \
    "$(shell_quote "$cfg")" "$(shell_quote "$brief")"
}

cmd_check() {
  if ! command -v "$OC" >/dev/null 2>&1; then
    printf 'opencode-launcher[1]{state,detail}:\n  "absent","no %s on this host"\n' "$OC"
    return 1
  fi
  local help ver missing=""
  help="$("$OC" --help 2>&1)" || true
  ver="$("$OC" --version 2>&1 | head -1)"; ver="${ver#opencode }"
  for f in --prompt --auto; do
    printf '%s\n' "$help" | grep -q -- "^  $f\b" || missing="$missing $f"
  done
  if [ -n "$missing" ]; then
    printf 'opencode-launcher[1]{state,detail}:\n  "red","opencode %s: the interactive TUI no longer lists%s — the launch shape needs both (bin/seat/opencode-launcher.sh)"\n' "$ver" "$missing"
    return 1
  fi
  printf 'opencode-launcher[1]{state,detail}:\n  "ok","opencode %s: the TUI takes --prompt and --auto"\n' "$ver"
}

cmd_has() {
  local m=${1-}
  [ -n "$m" ] || { printf 'error: has needs a provider/model token\n' >&2; return 2; }
  command -v "$OC" >/dev/null 2>&1 || { printf 'opencode-launcher[1]{model,state}:\n  "%s","no opencode on this host"\n' "$m"; return 1; }
  if "$OC" models 2>/dev/null | grep -qxF -- "$m"; then
    printf 'opencode-launcher[1]{model,state}:\n  "%s","served"\n' "$m"
  else
    printf 'opencode-launcher[1]{model,state}:\n  "%s","NOT SERVED by this opencode (opencode models)"\n' "$m"; return 1
  fi
}

sub=$1; shift
case "$sub" in
  print) cmd_print "$@" ;;
  check) cmd_check ;;
  has) cmd_has "$@" ;;
  *) printf 'error: unknown subcommand %s\nhelp: opencode-launcher.sh print|check|has\n' "$sub" >&2; exit 2 ;;
esac

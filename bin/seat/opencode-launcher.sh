#!/usr/bin/env bash
# opencode-launcher.sh — the ONE launch door for an OpenCode seat, as pi-launcher.sh is pi's.
#
# Why (measured 2026-11-12, opencode v2.2.7). OpenCode v2 moved the message to `run`;
# the old top-level shape `opencode --model M --prompt "…"` answers
#   ERROR  Unrecognized flag: --model in command opencode
# and the seat dies in its pane. The shell road (einherjar-spawn.sh) was mended on
# 2026-11-06, the engine road (src/ymir_runtime/harness.py) was not — two copies of one
# shape, and one of them killed every OpenCode seat the engine started. One door now
# owns the shape; both roads match it (the parity test in test_harness.py holds them).
#
# The one shape, and every part of it is load-bearing:
#
#   env OPENCODE_CONFIG_CONTENT='{"permission":{"*":"allow"}}' opencode run [--model M] --auto "<brief>"
#
#   env      the seat writer prefixes `exec `; `exec VAR=x cmd` is not runnable shell
#   run      v2's non-interactive verb; the message is its argument
#   --auto   approve what is not explicitly denied — no pane waits on a prompt nobody sees
#
# `--model free` picks a free model from the live catalog (bin/model/free-models.sh) —
# the road when the paid tokens are spent.
#
# Usage:
#   opencode-launcher.sh print [--model M|free] [--brief F]     # the command line, for a seat
#   opencode-launcher.sh write <out-script> [--model M|free] [--brief F]
#   opencode-launcher.sh run [--model M|free] [--cwd D] "<prompt>"  # launch it now, by hand
#   opencode-launcher.sh check                                   # opencode present and v2 `run` shape
#   opencode-launcher.sh has <provider/model>                    # does THIS opencode serve that token? (`opencode models`)
#
# Exit: 0 ok · 1 refused (no opencode, no free model, bad shape) · 2 usage.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

shell_quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
PERMS='{"permission":{"*":"allow"}}'

ACTION=$1; shift
OUT=""; MODEL=""; BRIEF=""; CWD=""; PROMPT=""
if [ "$ACTION" = write ]; then OUT=${1-}; shift || true; fi
while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL=${2-}; shift 2 ;;
    --brief) BRIEF=${2-}; shift 2 ;;
    --cwd)   CWD=${2-}; shift 2 ;;
    -*) printf 'error: unknown flag %s\nhelp: opencode-launcher.sh --help\n' "$1" >&2; exit 2 ;;
    *)  PROMPT=$1; shift ;;
  esac
done

resolve_model() {
  if [ "$MODEL" = free ]; then
    MODEL="$("$SCRIPT_DIR/../model/free-models.sh" pick opencode)" || exit 1
  fi
  case "$MODEL" in
    ""|default) MODEL="" ;;
    */*) ;;
    *) printf 'error: OpenCode takes a provider/model token or "free" (got "%s")\nhelp: opencode models | bin/model/free-models.sh list opencode\n' "$MODEL" >&2; exit 1 ;;
  esac
}

shape() {  # the one command line
  local mf=""
  [ -n "$MODEL" ] && mf="--model $(shell_quote "$MODEL") "
  printf 'env OPENCODE_CONFIG_CONTENT=%s opencode run %s--auto "$(cat %s)"' \
    "$(shell_quote "$PERMS")" "$mf" "$(shell_quote "$BRIEF")"
}

case "$ACTION" in
  print)
    [ -n "$BRIEF" ] || { echo "error: print needs --brief <file>" >&2; exit 2; }
    resolve_model; shape; printf '\n' ;;
  write)
    [ -n "$OUT" ] && [ -n "$BRIEF" ] || { echo "error: write needs <out-script> and --brief <file>" >&2; exit 2; }
    resolve_model
    { printf '#!/usr/bin/env bash\n'; printf 'exec '; shape; printf '\n'; } >"$OUT"
    chmod +x "$OUT"; printf '%s\n' "$OUT" ;;
  run)
    [ -n "$PROMPT" ] || { echo "error: run needs a prompt" >&2; exit 2; }
    command -v opencode >/dev/null 2>&1 || { echo "error: opencode is not on PATH" >&2; exit 1; }
    resolve_model
    [ -n "$CWD" ] && { cd "$CWD" || exit 1; }
    printf 'opencode-launcher: model=%s cwd=%s\n' "${MODEL:-<opencode default>}" "$PWD" >&2
    exec env OPENCODE_CONFIG_CONTENT="$PERMS" opencode run ${MODEL:+--model "$MODEL"} --auto "$PROMPT" ;;
  check)
    command -v opencode >/dev/null 2>&1 || { printf 'opencode-launcher[1]{check,state}:\n  "binary","missing"\n'; exit 1; }
    v="$(opencode --version 2>/dev/null | head -1)"
    h="$(opencode run --help 2>&1)"
    ok=yes
    for f in --model --auto; do printf '%s' "$h" | grep -q -- "$f" || ok=no; done
    printf 'opencode-launcher[2]{check,state}:\n  "version","%s"\n  "run --model --auto","%s"\n' "$v" "$ok"
    [ "$ok" = yes ] || exit 1 ;;
  has)
    # Pi's catalog (bin/model/catalog.sh) does not list the `opencode/` provider that carries the free
    # models; OpenCode itself is the authority on what it serves (plan 262, measured 2026-11-12).
    m=${MODEL:-${PROMPT:-}}
    [ -n "$m" ] || { echo "error: has needs a provider/model token" >&2; exit 2; }
    command -v opencode >/dev/null 2>&1 || { printf 'opencode-launcher[1]{model,state}:\n  "%s","no opencode on this host"\n' "$m"; exit 1; }
    if opencode models 2>/dev/null | grep -qxF -- "$m"; then
      printf 'opencode-launcher[1]{model,state}:\n  "%s","served"\n' "$m"
    else
      printf 'opencode-launcher[1]{model,state}:\n  "%s","NOT SERVED by this opencode (opencode models)"\n' "$m"; exit 1
    fi ;;
  *) printf 'error: unknown action %s\nhelp: opencode-launcher.sh print|write|run|check|has\n' "$ACTION" >&2; exit 2 ;;
esac

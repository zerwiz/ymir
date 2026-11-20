#!/usr/bin/env bash
# claude-seat.sh — what a Claude Code worker needs to start with no human click.
#
#   bin/seat/claude-seat.sh model <request>          # the name Claude accepts (claude/claude-opus-5-5 -> claude-opus-5-5)
#   bin/seat/claude-seat.sh default                  # the allow-list's default Claude model
#   bin/seat/claude-seat.sh trust <dir>              # mark one seat folder trusted in ~/.claude.json (never $HOME)
#   bin/seat/claude-seat.sh settings <seat-cwd> <out.json>   # the worker profile + one allow per MCP server
#   bin/seat/claude-seat.sh args <seat-cwd> <model> <out.json>  # the launch flags, one per line
#   bin/seat/claude-seat.sh check <pane> [state]     # what the pane shows: ok | model | trust | confirm | permission | login | empty
#   bin/seat/claude-seat.sh repair <pane> <fault> <model> <brief-file>   # ONE repair attempt for that fault
#
# Measured 2026-11-20: seven workers sat on "There's an issue with the selected model"
# (launched with `--model claude/claude-opus-5-5`), others on the trust dialog, and
# herdr called them done. The rule lives in src/ymir_runtime/claude_seat.py; the model
# name comes from the allow-list (bin/model/model-allow.sh), so the seat and the policy
# name a model the same way. The ward stays whole: `dontAsk` denies an unlisted tool
# rather than asking, the profile's deny list and every hook still apply.
#
# Exit: 0 ok · 1 fault · 2 usage · 3 refused (or, for check, a stuck seat).
set -u
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TREE="$(cd "$SELF_DIR/../.." && pwd)"
CORE="$TREE/src/ymir_runtime/claude_seat.py"
PROFILE="$TREE/.agents/harnesses/claude-worker.settings.json"
HDR_BIN="${HDR:-$(command -v herdr || command -v hdr || printf 'herdr')}"
hdr() { if [ -n "${HERDR_SESSION:-}" ]; then "$HDR_BIN" --session "$HERDR_SESSION" "$@"; else "$HDR_BIN" "$@"; fi; }

cmd="$1"; shift
case "$cmd" in
  model)
    [ $# -eq 1 ] || { printf 'usage: claude-seat.sh model <request>\n' >&2; exit 2; }
    out="$("$TREE/bin/model/model-allow.sh" check "$1" --harness claude 2>&1)"; rc=$?
    if [ "$rc" -ne 0 ]; then printf '%s\n' "$out" >&2; exit 3; fi
    # row 2, field 3 (the model as the CLI names it): "claude","<req>","<model>",…
    printf '%s\n' "$out" | sed -n '2p' | cut -d'"' -f6
    ;;
  default)
    m="$("$TREE/bin/model/model-allow.sh" default claude 2>/dev/null)"
    [ -n "$m" ] || m=sonnet
    "$0" model "$m"
    ;;
  trust)
    [ $# -eq 1 ] || { printf 'usage: claude-seat.sh trust <dir>\n' >&2; exit 2; }
    exec python3 "$CORE" trust "$1"
    ;;
  settings)
    [ $# -eq 2 ] || { printf 'usage: claude-seat.sh settings <seat-cwd> <out.json>\n' >&2; exit 2; }
    [ -r "$PROFILE" ] || { printf 'error: the Claude worker profile is missing at %s\n' "$PROFILE" >&2; exit 1; }
    exec python3 "$CORE" settings "$PROFILE" "$1" "$2"
    ;;
  args)
    [ $# -eq 3 ] || { printf 'usage: claude-seat.sh args <seat-cwd> <model> <out.json>\n' >&2; exit 2; }
    "$0" settings "$1" "$3" >/dev/null || exit 1
    printf '%s\n' --permission-mode dontAsk --settings "$3"
    [ -n "$2" ] && printf '%s\n' --model "$2"
    ;;
  check)
    [ $# -ge 1 ] || { printf 'usage: claude-seat.sh check <pane> [state]\n' >&2; exit 2; }
    text="$(hdr agent read "$1" --source recent --lines 120 2>/dev/null || hdr pane read "$1" 2>/dev/null)"
    verdict="$(printf '%s' "$text" | python3 "$CORE" classify "${2:-}")"
    printf '%s\n' "$verdict"
    case "$verdict" in ok*) exit 0 ;; *) exit 3 ;; esac
    ;;
  repair)
    [ $# -eq 4 ] || { printf 'usage: claude-seat.sh repair <pane> <fault> <model> <brief-file>\n' >&2; exit 2; }
    pane="$1"; fault="$2"; model="$3"; brief="$4"
    case "$fault" in
      trust)
        # the seat folder is marked (so the next seat never sees it), then the dialog's default — "Yes" — is taken
        cwd="$(hdr pane get "$pane" 2>/dev/null | python3 -c 'import json,sys
try:
  d=json.load(sys.stdin); r=d.get("result",d); p=r.get("pane",r); print(p.get("cwd") or "")
except Exception: print("")' 2>/dev/null)"
        [ -n "$cwd" ] && python3 "$CORE" trust "$cwd" >/dev/null 2>&1
        hdr agent send-keys "$pane" Enter >/dev/null 2>&1 || exit 1
        ;;
      confirm)
        hdr agent send-keys "$pane" Enter >/dev/null 2>&1 || exit 1 ;;
      permission)
        # never approve on the worker's behalf: refuse the one call, and tell it to go on without it
        hdr agent send-keys "$pane" Escape >/dev/null 2>&1 || exit 1
        sleep 1
        hdr agent prompt "$pane" "That permission was refused by the seat (no human is here). Carry on with the errand without it, or write the question to your questions file." >/dev/null 2>&1 || exit 1
        ;;
      model)
        [ -n "$model" ] || exit 1
        hdr agent prompt "$pane" "/model $model" >/dev/null 2>&1 || exit 1
        sleep 3
        hdr agent send-keys "$pane" Enter >/dev/null 2>&1 || true   # a switch confirmation, if one is drawn
        sleep 2
        [ -r "$brief" ] && { hdr agent prompt "$pane" "$(cat "$brief")" >/dev/null 2>&1 || exit 1; }
        ;;
      empty)
        [ -r "$brief" ] || exit 1
        hdr agent prompt "$pane" "$(cat "$brief")" >/dev/null 2>&1 || exit 1 ;;
      *) exit 1 ;;   # login and anything unnamed: no repair is safe
    esac
    ;;
  *) printf 'error: unknown action %s\nhelp: bin/seat/claude-seat.sh --help\n' "$cmd" >&2; exit 2 ;;
esac

#!/usr/bin/env bash
# syn-judge.sh — the supervisor's JUDGEMENT: one model turn, through doors the house already carries.
#
# The middle step of Sýn's loop (plan 004) is a hand, not a threshold. This door is
# that hand's road, and it carries NO prompt and NO threshold of its own: the prompt
# arrives on stdin (the loop composes it from the measurement and the runbook
# library), and the model is resolved by the house's one resolver.
#
#   <prompt> | bin/agents/syn-judge.sh        the model's answer on stdout
#
# WHY A DOOR — the Allfather, 2026-11-06: *"this model choosing logic don't make
# sense. all users and computers have different models … are we shipping hardcoded
# models?"* So this file names no model. `bin/model/agent-model.sh` resolves it in
# its own order (explicit → YMIR_<AGENT>_MODEL → this machine's overlay → the
# fleet's choice → the agent's tier → the fleet default → refusal), and the answer
# is checked by `bin/model/model-allow.sh` before anything is served. A model this
# seat cannot serve is refused by name, never swapped quietly for another.
#
# THE JUDGE IS READ-ONLY, BY CONSTRUCTION: `-nt` (no tools), `--no-mcp`,
# `--no-extensions`, `--no-session`. A judgement that could run bash is a second
# pair of hands in a loop that already gates its acts on the arm.
#
# Env:
#   SYN_JUDGE_AGENT   which agents.yaml row resolves the model (default: syn)
#   SYN_JUDGE_MODEL   an explicit provider/model for this call (the operator's word for one run)
#   SYN_JUDGE_TIMEOUT the model's wall clock in seconds (default: 300)
#
# Exit: 0 an answer · 2 usage · 3 refused (a model this seat cannot serve) · 1 the door failed.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

die()    { printf 'syn-judge: %s\n' "$*" >&2; exit 1; }
refuse() { printf 'syn-judge: REFUSED — %s\n' "$*" >&2; exit 3; }

AGENT="${SYN_JUDGE_AGENT:-syn}"
TIMEOUT="${SYN_JUDGE_TIMEOUT:-300}"
bin_model_reason() { "$ROOT/bin/model/agent-model.sh" "$AGENT" "${MODEL_ARGS[@]}" 2>&1 | tail -1; }

# The prompt comes on stdin: a judgement is about the measurement handed to it.
PROMPT="$(cat)"
[ -n "${PROMPT//[[:space:]]/}" ] || { printf 'syn-judge: usage: <prompt> | %s\n' "$0" >&2; exit 2; }

# 1 · WHICH MODEL. The one resolver; a refusal is the resolver's, by name.
MODEL_ARGS=()
[ -n "${SYN_JUDGE_MODEL:-}" ] && MODEL_ARGS=(--model "$SYN_JUDGE_MODEL")
MODEL="$("$ROOT/bin/model/agent-model.sh" "$AGENT" --plain "${MODEL_ARGS[@]}" 2>/dev/null)"
rc=$?
case "$rc" in
  0) [ -n "$MODEL" ] || die "the resolver returned no model for agent '$AGENT'" ;;
  3) refuse "agent-model refused: $(bin_model_reason)" ;;
  2) printf 'syn-judge: usage: <prompt> | %s\n' "$0" >&2; exit 2 ;;
  *) refuse "the model could not be resolved for agent '$AGENT' (agent-model exit $rc)" ;;
esac

# 2 · MAY THIS SEAT SERVE IT. The allow-list is the operator's; no env variable lifts it.
if [ -x "$ROOT/bin/model/model-allow.sh" ]; then
  ALLOW_OUT="$("$ROOT/bin/model/model-allow.sh" check "$MODEL" --harness pi --for syn-judge 2>&1)"
  ALLOW_RC=$?
  [ "$ALLOW_RC" -eq 0 ] || refuse "the allow-list refused '$MODEL' (exit $ALLOW_RC): $(printf '%s' "$ALLOW_OUT" | tail -1)"
fi

# 3 · WHICH HARNESS. pi for every road this operator uses (config/agents.yaml), and a
#     harness this door cannot serve read-only is a refusal rather than a gamble.
HARNESS="$("$ROOT/bin/fleet/agents-config.sh" get "$AGENT" harness 2>/dev/null)"
[ -n "$HARNESS" ] || HARNESS="pi"
case "$HARNESS" in
  pi) : ;;
  *)  refuse "the harness '$HARNESS' is not wired for a read-only judgement (only pi) — name a pi row" ;;
esac

command -v pi >/dev/null 2>&1 || die "the harness 'pi' is not on PATH"

# 4 · THE TURN. No tools, no MCP, no extensions, no session: a judgement leaves
#     nothing behind but its answer.
command -v timeout >/dev/null 2>&1 && TIMEOUT_BIN=(timeout "$TIMEOUT") || TIMEOUT_BIN=()
"${TIMEOUT_BIN[@]}" pi --print --no-tools --no-mcp --no-extensions --no-session \
  --model "$MODEL" "$PROMPT" 2>/dev/null

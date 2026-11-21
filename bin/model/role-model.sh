#!/usr/bin/env bash
# role-model.sh — WHICH HARNESS AND MODEL A ROLE RUNS, AND WHETHER ITS SEAT RUNS UNATTENDED.
#
# The one resolver behind every spawn: the review spine, einherjar-spawn.sh, the errand door,
# the review loop and the work loop. The operator tunes it in the home's config/agents.yaml
# (a per-machine overlay config/agents.<host>.yaml wins per role):
#
#   roles:
#     judge: [claude:opus, pi:opencode-go/deepseek-v4.1-flash]
#     coder: { choose: [claude:sonnet, pi:opencode-go/beam-free], yolo: on }
#
#   role-model.sh <role>                      harness<TAB>model   (first choice this seat can serve)
#   role-model.sh <role> --explain            the same, plus every skipped choice and why
#   role-model.sh <role> --harness H --model M   an explicit pair wins over the list
#   role-model.sh yolo <role> [on|off]        on|off<TAB>where it came from
#   role-model.sh posture <role> <harness> [on|off]   the one line a spawn prints
#   role-model.sh --check                     every role, or the choice that fails
#
# A choice this seat cannot serve is skipped and NAMED on stderr; a role with none servable is a
# refusal (exit 3), never a silent fallback. Law: RULES/08 (2026-11-21); how-to:
# docs/features/choose-the-models-your-judges-and-coders-run.md
# Exit: 0 resolved · 1 fault · 2 usage · 3 refused.
set -u
SELF_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
TREE="$(dirname "$(dirname "$SELF_DIR")")"
CORE="$TREE/src/ymir_runtime/role_config.py"
export PYTHONPATH="$TREE/src${PYTHONPATH:+:$PYTHONPATH}"
case "${1-}" in
  -h|--help|"") sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --check) exec python3 "$CORE" check ;;
  yolo)
    shift; [ $# -ge 1 ] || { echo "usage: role-model.sh yolo <role> [on|off]" >&2; exit 2; }
    exec python3 "$CORE" yolo "$@" ;;
  posture)
    shift; [ $# -ge 2 ] || { echo "usage: role-model.sh posture <role> <harness> [on|off]" >&2; exit 2; }
    role="$1"; harness="$2"; flag="${3:-}"
    ans="$(python3 "$CORE" yolo "$role" $flag)" || exit 1
    python3 -c 'import sys; from ymir_runtime import role_config as r; on,src=sys.argv[2].split("\t"); print(r.posture(sys.argv[1], on=="on") + " — from " + src)' "$harness" "$ans"
    ;;
  *)
    role="$1"; shift; H=""; M=""; EXPLAIN=0
    while [ $# -gt 0 ]; do case "$1" in
      --harness) H="${2:-}"; shift 2 ;; --harness=*) H="${1#--harness=}"; shift ;;
      --model) M="${2:-}"; shift 2 ;; --model=*) M="${1#--model=}"; shift ;;
      --explain) EXPLAIN=1; shift ;; --plain) shift ;;
      *) echo "role-model: unknown argument $1" >&2; exit 2 ;; esac; done
    if [ -n "$H" ] || [ -n "$M" ]; then   # the operator's word for this run wins
      printf '%s\t%s\t-1\texplicit\n' "$H" "$M"; exit 0
    fi
    out="$(python3 "$CORE" model "$role")"; rc=$?
    [ "$rc" -eq 0 ] || exit "$rc"
    if [ "$EXPLAIN" = 1 ]; then
      printf 'role-model[1]{role,harness,model,choice,skipped}:\n'
      printf '%s\n' "$out" | awk -F'\t' -v r="$role" '{ printf "  \"%s\",\"%s\",\"%s\",\"%d\",\"%s\"\n", r, $1, $2, $3+1, $4 }'
    else
      printf '%s\n' "$out" | cut -f1,2
    fi
    ;;
esac

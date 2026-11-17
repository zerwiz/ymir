#!/usr/bin/env bash
# agent-ready.sh — one answer per target: ready · working · blocked: <why> · dead.
#
#   bin/seat/agent-ready.sh w6R:p1                 # a herdr pane
#   bin/seat/agent-ready.sh hermes:fd2ee4d0        # a Hermes session, by id prefix or title
#   bin/seat/agent-ready.sh --all                  # every agent and session on this machine
#   bin/seat/agent-ready.sh w6R:p1 w4E:p1 --json
#
# WHY (plan 303 §12.3 step 1): a relay that wakes an agent must know whether the
# agent can take a turn at all. herdr and Hermes answer in two vocabularies, and a
# pane standing on a dialog swallows the first message typed into it (measured on
# w4E:p1 and w4E:p2, the Claude folder-trust prompt). One vocabulary for both, so a
# caller never learns which backend it is talking to.
#
# Exit: 0 ready · 1 working · 2 blocked · 3 dead · 64 usage · 65 the reader failed.
# Several targets answer with the worst of them — the one a person must act on.
#
# The reader is bin/seat/agent-ready.py; this door adds nothing to it, so there is
# one place the vocabulary is decided.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="${AGENT_READY_PY:-$here/agent-ready.py}"

case "${1-}" in
  -v|-V|--version) printf '1.0.0\n'; exit 0 ;;
  -h|--help|"") sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit $([ -n "${1-}" ] && echo 0 || echo 64) ;;
esac

[ -r "$PY" ] || { printf 'error: the reader is missing: %s\n' "$PY" >&2; exit 65; }
command -v python3 >/dev/null 2>&1 || { printf 'error: python3 is required\n' >&2; exit 65; }

exec python3 "$PY" "$@"

#!/usr/bin/env bash
# project-brief.sh — "this project", for any session in any harness (Claude Code, Pi, OpenCode, Hermes).
#
#   project-brief.sh [DIR]        brief for the project DIR belongs to (default: the session's working directory)
#   project-brief.sh --self-test  the proofs (a fixture home)
#
# A fresh session must learn a project's private state without being told where it lives. The repository may not
# carry private paths, so the pointer lives in the home's project registry (hodd/identity/projects.yaml): DIR's git
# remote or clone path finds the entry, and its `seat:` names the project's folder in the home. The brief prints that
# folder's where-we-are note (NOW.md, else README.md), the open to-do lines that name the project, and the newest
# daily-log lines that name it. Read-only, and only when asked ("brief me on this project") — never at session start.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR" && while [ ! -d "$PWD/RULES" ] || [ ! -d "$PWD/bin" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
# The home is resolved, never assumed (RULES/07): the one resolver is bin/vault/hoard-lib.sh.
if [ -z "${YMIR_HOME:-}" ] && [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  . "$ROOT/bin/vault/hoard-lib.sh" >/dev/null 2>&1 || true
  if command -v ymir_home_root >/dev/null 2>&1; then H=""; ymir_home_root H; [ -n "$H" ] && export YMIR_HOME="$H"; fi
fi
exec python3 "$DIR/project_brief.py" "$@"

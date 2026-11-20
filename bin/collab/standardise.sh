#!/usr/bin/env bash
# standardise.sh — put the collaboration kit into a repository, upgrade an older one, or say what is missing.
#
#   bin/collab/standardise.sh --check <repo> [--profile P] [--register plain|house] [--languages en:sv]
#   bin/collab/standardise.sh --apply <repo> [same options]   # install, upgrade older kit files, seat the hooks
#   bin/collab/standardise.sh --uninstall <repo>              # put the hooks back as they were
#
# Never replaces a file the repository changed for itself (a local rule wins: reported, never replaced); never
# takes the repository's hooks (they run after the kit's); never touches product code. Idempotent.
# 2.0.0 (2026-11-20, plan 267 K-1…K-13): plain register by default, project.yaml with stack profiles and
# languages, the worktree lifecycle and the leftover prune (RULES/17, RULES/24), chained hooks, the container door
# and check-host (RULES/23), the language rule (RULES/22). The implementation is standardise.py beside this file.
set -euo pipefail
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/standardise.py" "$@"

#!/usr/bin/env bash
# regenerate-on-merge.sh — the merge driver for WOVEN documents (Þættir, plan 174).
#
# git calls it as:  <driver> %O %A %B %L %P   (base · ours=output · theirs · marker · path)
# A woven document has no hand-kept content: the answer to any conflict is to
# WEAVE it again from the fragments the merge just combined.
set -uo pipefail
# git hands the driver its inputs as `.merge_file_XXXXXX` temp files in the worktree root and
# unlinks them itself when the driver returns normally. A driver that is killed or interrupted
# (a gate timeout, a closed pane) leaves them behind — 18 of them at the repo root on 2026-11-12,
# when a PR merged. So the driver removes the base and theirs inputs on every way out (the output,
# %A, is git's to read and remove), and sweeps any `.merge_file_*` orphan an hour old.
_cleanup() {
  local f
  for f in "${1:-}" "${3:-}"; do
    case "$f" in */.merge_file_*|.merge_file_*) rm -f -- "$f" 2>/dev/null ;; esac
  done
  find . -maxdepth 1 -type f -name '.merge_file_??????' -mmin +60 -delete 2>/dev/null
  return 0
}
trap '_cleanup "$@"' EXIT
trap 'exit 130' INT TERM HUP
path="${5:-${3:-}}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
case "$path" in
  FEATURES.md|*/FEATURES.md)
    bash "$root/bin/records/weave-features.sh" >/dev/null || exit 1 ;;
  bin/README.md|*/bin/README.md|bin/INDEX.md|*/bin/INDEX.md|bin/*/INDEX.md|*/bin/*/INDEX.md|.agents/backend/README.md|*/.agents/backend/README.md)
    bash "$root/bin/gates/inventory.sh" >/dev/null || exit 1 ;;
  .agents/assets/agents/capabilities.md|*/.agents/assets/agents/capabilities.md|.agents/assets/agents/capabilities/*.md|*/.agents/assets/agents/capabilities/*.md)
    bash "$root/bin/gates/capabilities.sh" >/dev/null || exit 1 ;;
  *)
    exit 1 ;;   # not a woven document — let git keep the conflict
esac
exit 0

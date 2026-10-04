#!/usr/bin/env bash
# workflow-check.sh — every GitHub Actions workflow must PARSE, before CI is asked to run.
#
# WHY (2026-10-02): three workflows were invalid YAML — an unquoted scalar carrying a colon,
# and two heredoc/multi-line bodies whose continuation sat at COLUMN 1 and ended the block.
# GitHub reported only "This run likely failed because of a workflow file issue", so the
# gates never ran and nothing in the log said *which* file. One run was red for a full
# session before anyone noticed. That is precisely the failure mode fixed in 0.1.88 —
# **a gate that cannot START must say so** — applied one level up: the workflow itself
# could not start.
#
#   bin/workflow-check.sh          # parse every .github/workflows/*.yml
#   bin/workflow-check.sh --quiet  # only report failures
#
# Non-fatal if python3 lacks PyYAML: it then checks the two structural rules it can see.
set -uo pipefail
_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}
ROOT="$(_root)"
cd "$ROOT" || exit 2
QUIET=0; [ "${1:-}" = "--quiet" ] && QUIET=1

files=(.github/workflows/*.yml .github/workflows/*.yaml)
files=("${files[@]}")
[ -e "${files[0]}" ] || { echo "workflow-check: no workflows found" >&2; exit 1; }

bad=0
if python3 -c 'import yaml' 2>/dev/null; then
  for f in "${files[@]}"; do
    [ -f "$f" ] || continue
    err="$(python3 - "$f" <<'PY' 2>&1
import sys, yaml
f = sys.argv[1]
try:
    yaml.safe_load(open(f))
except yaml.YAMLError as e:
    m = e.problem_mark
    where = f"line {m.line + 1}" if m else "?"
    print(f"{where}: {e.problem}")
    if m:
        lines = open(f).read().splitlines()
        for i in range(max(0, m.line - 1), min(len(lines), m.line + 2)):
            print(f"    {i + 1:>3}| {lines[i].strip()[:76]}")
except Exception as e:
    print(str(e)[:120])
PY
)"
    if [ -n "$err" ]; then
      printf 'workflow_check[1]{workflow,why}: "%s","%s"\n' "$(basename "$f")" "$(printf '%s' "$err" | head -1)"
      printf '%s\n' "$err" | tail -n +2 | sed 's/^/    /'
      bad=$((bad + 1))
    fi
  done
else
  printf 'workflow_check[1]{mode}: "pyyaml-absent — fell back to a structural read"\n'
  for f in "${files[@]}"; do
    [ -f "$f" ] || continue
    # A heredoc or multi-line scalar body must never sit at column 0 inside `run: |`.
    if awk 'BEGIN{blk=0} /^[[:space:]]*(run|body):[[:space:]]*[|>]/ {blk=1; ind=index($0,$1); next} blk && /^[^[:space:]#]/ {print FILENAME": "NR": content at column 1 inside a block scalar"; blk=0} /^[^[:space:]]/ {blk=0}' "$f" | grep -q .; then
      awk 'BEGIN{blk=0} /^[[:space:]]*(run|body):[[:space:]]*[|>]/ {blk=1; next} blk && /^[^[:space:]#]/ {print FILENAME": "NR": content at column 1 inside a block scalar"; blk=0} /^[^[:space:]]/ {blk=0}' "$f"
      bad=$((bad + 1))
    fi
  done
fi

if [ "$bad" -eq 0 ]; then
  [ "$QUIET" = 1 ] || printf 'workflow_check[2]{workflows,bad}: "%s","0"\n' "${#files[@]}"
  exit 0
fi
printf 'workflow-check: %s workflow(s) do not parse — CI cannot run them, and GitHub will only say "workflow file issue".\n' "$bad" >&2
exit 1

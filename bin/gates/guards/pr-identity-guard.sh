#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/../../forge/pr-patterns.sh"
_root() { local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ "$d" != "/" ]; do [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }; d="$(dirname "$d")"; done; printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; }
ROOT="${YMIR_GUARD_ROOT:-$(_root)}"
cd "$ROOT" 2>/dev/null || true

mode="local"; pr=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ci) mode="ci"; shift;;
    --local) mode="local"; shift;;
    *) pr="$1"; shift;;
  esac
done

if [ "$mode" = "ci" ]; then
  [ -z "${GITHUB_EVENT_PATH:-}" ] && { echo "no GITHUB_EVENT_PATH" >&2; exit 2; }
  body=$(python3 -c "import json,sys; d=json.load(open('$GITHUB_EVENT_PATH')); print(d.get('pull_request',{}).get('body','') or '')")
  branch=$(python3 -c "import json,sys; d=json.load(open('$GITHUB_EVENT_PATH')); print(d.get('pull_request',{}).get('head',{}).get('ref',''))")
else
  [ -z "$pr" ] && { echo "usage: pr-identity-guard.sh <pr-number> [--ci]" >&2; exit 2; }
  body=$(gh pr view "$pr" --json body -q .body)
  branch=$(gh pr view "$pr" --json headRefName -q .headRefName)
fi

# check signature block present
if ! printf '%s\n' "$body" | grep -q '^house:'; then
  echo "refused: no signature block. Template:" >&2
  echo "house: <house>" >&2
  echo "fleet: <fleet>" >&2
  echo "agent: <role> (role: ship, errand: <id>)" >&2
  echo "authority: <words>" >&2
  echo "proves: <command and result>" >&2
  exit 1
fi

# forbidden patterns
tmp=$(mktemp); printf '%s\n' "$body" > "$tmp"
if m=$(pr_pattern_match "$tmp"); then
  rm -f "$tmp"; echo "refused: $m" >&2; exit 1
fi
rm -f "$tmp"

# agent vs branch errand id
agent=$(printf '%s\n' "$body" | grep -E '^agent:' | head -1 | sed 's/^agent:[[:space:]]*//; s/ .*//')
if printf '%s' "$branch" | grep -q '^eindri/'; then
  id=$(printf '%s' "$branch" | sed 's#^eindri/##')
  if [ "$agent" != "$id" ] && [ "$agent" != "ship" ]; then
    echo "refused: agent '$agent' disagrees with branch errand '$id'" >&2
    exit 1
  fi
fi
echo "pr-identity-guard: OK"
exit 0

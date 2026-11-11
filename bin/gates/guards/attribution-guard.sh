#!/usr/bin/env bash
# attribution-guard.sh — no AI tool signs the work (RULES/53).
#
# WHY (2026-11-11, at the Allfather's word): "no AI tools are allowed to add things like this into the code or
# documents: Co-Authored-By: Claude … it might be very improper to clients' repos and code." A harness adds an
# attribution trailer by default; this ward refuses it before it leaves.
#
# WHAT IT JUDGES: the messages of the commits a push ADDS (base..HEAD), or one message file (the commit-msg hook).
# History is not judged — published commits cannot be unmade by a ward, and history is never rewritten (Rule 06).
#
#   attribution-guard.sh --base origin/main   # the commits a push adds
#   attribution-guard.sh --msg <file>         # one commit message (commit-msg hook)
#   attribution-guard.sh --text <file>        # any text: a PR body, a letter, a document
#   attribution-guard.sh --self-test
set -uo pipefail

PATTERN='(co-authored-by:[^\n]*(claude|anthropic|openai|chatgpt|gpt-|gemini|copilot|codex|cursor|opus|sonnet|haiku|fable|devin|aider|noreply@anthropic\.com))|(generated (with|by) \[?(claude|chatgpt|copilot|gemini|codex|cursor|devin|aider))|(🤖 generated with)'

hits() { grep -inE "$PATTERN" "$1" 2>/dev/null; }

refuse() {
  printf 'attribution-guard refused (RULES/53): %s carries an AI attribution line:\n' "$1" >&2
  printf '%s\n' "$2" | sed 's/^/  /' >&2
  printf '  remove it — no AI tool signs the work, and none adds itself (RULES/53)\n' >&2
  exit 1
}

case "${1:-}" in
  --msg|--text)
    f="${2:-}"; [ -r "$f" ] || { printf 'attribution-guard: no file %s\n' "$f" >&2; exit 2; }
    h="$(grep -v '^#' "$f" | grep -inE "$PATTERN")" && refuse "$f" "$h"
    exit 0 ;;
  --base)
    base="${2:-origin/main}"
    git rev-parse -q --verify "$base" >/dev/null 2>&1 || { printf 'attribution-guard: no base %s — skipped\n' "$base" >&2; exit 0; }
    t="$(mktemp)"; trap 'rm -f "$t"' EXIT
    for c in $(git rev-list "$base..HEAD" 2>/dev/null); do
      git log -1 --format=%B "$c" >"$t"
      h="$(hits "$t")" && refuse "commit $(git log -1 --format='%h %s' "$c")" "$h"
    done
    exit 0 ;;
  --self-test)
    ok=0; d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT
    printf 'records: a change\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\n' >"$d/a"
    printf 'body\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\n' >"$d/b"
    printf 'docs: Craig wrote this\n\nCo-Authored-By: Craig Martin <craig@example.invalid>\n' >"$d/c"
    printf 'records: the brief\n\n# Co-Authored-By: Claude (a comment git strips)\n' >"$d/e"
    for f in a b; do bash "$0" --msg "$d/$f" 2>/dev/null && { echo "FAIL  $f passed"; ok=1; }; done
    for f in c e; do bash "$0" --msg "$d/$f" 2>/dev/null || { echo "FAIL  $f refused"; ok=1; }; done
    [ $ok = 0 ] && echo 'attribution-guard: self-test PASS' || echo 'attribution-guard: self-test FAILED'
    exit $ok ;;
  *) sed -n 2,14p "$0"; exit 2 ;;
esac

#!/usr/bin/env bash
# git-clobber-guard.sh — no command that throws away uncommitted work.
#
# WHY THIS EXISTS (measured 2026-10-21, twice in one day):
#   1. a hand-edit of the vault decrypted to nothing and the re-encrypt replaced 90 secrets
#      with 3 — a backup taken seconds earlier saved it;
#   2. proving a documentation ward could fail, a fake claim was appended to README.md and
#      reverted with `git checkout README.md` — which restores the LAST COMMIT, not the
#      previous minute, and threw away the uncommitted corrections that had just been made.
#
# Neither was carelessness about the target; both were commands whose blast radius was wider
# than the thing being changed. A command that discards uncommitted work is a DELETION of work
# that was never recorded — Rule 11's subject, arriving through a door Rule 11 did not name.
#
#   git-clobber-guard.sh check      # judge the current branch range against its base (a push)
#   git-clobber-guard.sh --scan     # audit the whole tree
#
# A line may be waived in writing on the same line:
#   # clobber-ok: <why a working tree cannot be lost here>
#
# Exit: 0 clean · 1 a clobber in the range · 2 usage.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# The patterns, each one a command that can destroy work it never saw. A BRANCH SWITCH is not
# one of them (`git checkout -b`, `git checkout main` move the tree deliberately, and git
# refuses when that would lose an edit) — flagging those would make the ward noise, and a
# noisy ward is disabled, which is how the real clobber gets through.
#   git checkout -- <path> · git checkout <ref> -- <path>   restore tracked files, discard edits
#   git restore                                             the same, newer spelling
#   git reset --hard                                        move the branch AND the tree
#   git clean -f[d/x]                                       delete untracked files
#   git stash drop|clear                                    delete saved work
#   git worktree remove --force                             delete a worktree with its edits
PATTERN='git[[:space:]]+checkout[[:space:]]+([^[:space:]]+[[:space:]]+)?--([[:space:]]|$)|git[[:space:]]+restore([[:space:]]|$)|git[[:space:]]+reset[[:space:]]+[^#;|]*--hard|git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f|git[[:space:]]+stash[[:space:]]+(drop|clear)|git[[:space:]]+worktree[[:space:]]+remove[[:space:]].*--force'

MODE="${1:-check}"; shift || true
case "$MODE" in
  check|--scan) ;;
  --version|-v) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) printf 'error: unknown command %s\nhelp: git-clobber-guard.sh [check|--scan]\n' "$MODE" >&2; exit 2 ;;
esac

# Only CODE is judged: a document may quote the command it forbids (this file does), and a
# fix note must be able to describe the mistake it records. The subject is what a script RUNS.
code_ext='\.(sh|bash|zsh|py|ts|js|mjs|cjs|rb|pl|lua|yaml|yml|toml)$'

if [ "$MODE" = "--scan" ]; then
  hits="$(cd "$ROOT" && grep -rInE "$PATTERN" \
    --include='*.sh' --include='*.bash' --include='*.py' --include='*.ts' --include='*.js' \
    bin/ .agents/ tools/ scripts/ src/ apps/ 2>/dev/null \
    | grep -v 'clobber-ok:' | grep -v 'git-clobber-guard.sh' | grep -v 'no-delete-guard' | head -40 || true)"
else
  head_sha="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || true)"
  base="$(git -C "$ROOT" merge-base "$head_sha" origin/main 2>/dev/null \
          || git -C "$ROOT" rev-parse "$head_sha^" 2>/dev/null || true)"
  hits=""
  if [ -n "${head_sha:-}" ] && [ -n "${base:-}" ]; then
    # added lines only, with their file, filtered to code
    hits="$(git -C "$ROOT" diff -U0 "$base" "$head_sha" -- 2>/dev/null \
      | awk -v ext="$code_ext" '
          /^\+\+\+ b\// { file = substr($0, 7); keep = (file ~ ext); next }
          /^\+/ && keep {
            line = substr($0, 2)
            if (line ~ /clobber-ok:/) next
            if (line ~ /git[ \t]+(checkout[ \t]+([^ \t]+[ \t]+)?--([ \t]|$)|restore([ \t]|$)|reset[ \t]+[^#;|]*--hard|clean[ \t]+-[a-zA-Z]*f|stash[ \t]+(drop|clear)|worktree[ \t]+remove[ \t].*--force)/)
              printf "%s:%s\n", file, line
          }' | head -40 || true)"
  fi
fi

if [ -n "$hits" ]; then
  printf 'git-clobber-guard[%s]{file,line}\n' "$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"
  printf '%s\n' "$hits" | while IFS= read -r hit; do
    [ -n "$hit" ] && printf '  "%s"\n' "$(printf '%s' "$hit" | cut -c1-140)"
  done
  printf 'git-clobber-guard: a command here discards uncommitted work (Rule 11) — name the target,\n'
  printf '  or waive it in writing with `# clobber-ok: <why>` on the same line\n' >&2
  exit 1
fi
printf 'git-clobber-guard[1]{gate,result}:\n  "%s","clean — no command discards uncommitted work"\n' "$MODE"
exit 0

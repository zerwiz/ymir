#!/usr/bin/env bash
# runtime-guard.sh — THE TREE IS NOT A RUNTIME.
#
# A lock, not a wish. The running system writes state, and the source tree is not
# where state goes. This ward refuses a checkout that carries runtime output it has
# not declared, because an undeclared artifact is how a checkout stops being a
# checkout and a `git reset` starts taking the runtime with it.
#
# Declared means one of two things and nothing else:
#   · git IGNORES it   (a workbench may keep caches; they must be named)
#   · git TRACKS it    (a deliberate, reviewed artifact)
# Anything else the system produced is a finding, with the file named.
#
# It cannot prove WHO wrote a file; it proves that nothing undeclared is sitting
# there. `snapshot` and `verify` cover the other half: run the stack, then prove the
# tree did not move.
#
# Usage:
#   runtime-guard.sh check          # the ward
#   runtime-guard.sh snapshot       # record the tree's state (default .run/tree.snapshot)
#   runtime-guard.sh verify [file]  # fail if the tree moved since the snapshot
#   runtime-guard.sh --version
#
# Exit: 0 clean · 1 a finding · 2 usage.
set -u

VERSION="1.0.0"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNAP="${RUNTIME_GUARD_SNAPSHOT:-$ROOT/.run/tree.snapshot}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  check|snapshot|verify|"") ;;
  *) printf 'error: unknown action %s\nhelp: runtime-guard.sh [check|snapshot|verify]\n' "${1-}" >&2; exit 2 ;;
esac
ACTION="${1:-check}"

# Runtime signatures: what a running system produces. A build output, a cache, a
# log, a pid, a lock, a database. Names, not paths — a signature anywhere is the
# same fault.
is_runtime() {  # <path> -> 0 when it looks like runtime output
  local p="$1" base; base="$(basename "$p")"
  case "$base" in
    node_modules|dist|build|target|.vite|.astro|__pycache__|.run|state) return 0 ;;
    *.pyc|*.log|*.pid|*.lock|*.db|*.db-wal|*.db-shm|*.sqlite|*.tar.gz|*.gguf) return 0 ;;
  esac
  case "$p" in
    */node_modules/*|*/dist/*|*/__pycache__/*|*/.vite/*|*/.astro/*|*/.run/*) return 0 ;;
  esac
  return 1
}

# A declaration IN WRITING. `RUNTIME-GUARD.allow` names runtime artifacts this repo
# keeps on purpose, one glob per line with a reason after `#`. This exists because a
# real case was found that was neither ignored nor tracked: the Smiðja visualizer's
# built UI, un-ignored in .gitignore to force it into an npm tarball. An undeclared
# artifact is the fault; a declared one is a decision, and a decision is reviewable.
ALLOW_FILE="${RUNTIME_GUARD_ALLOW:-$ROOT/RUNTIME-GUARD.allow}"
declared() {  # <path> -> 0 when the repo has declared it in writing
  local p="$1" line pat
  [ -f "$ALLOW_FILE" ] || return 1
  while IFS= read -r line; do
    pat="${line%%#*}"
    pat="$(printf '%s' "$pat" | tr -d '[:space:]')"
    [ -n "$pat" ] || continue
    case "$p" in $pat) return 0 ;; esac
  done <"$ALLOW_FILE"
  return 1
}

tree_state() {  # print a stable description of the tree's tracked state
  git -C "$ROOT" status --porcelain 2>/dev/null
}

case "$ACTION" in
  snapshot)
    mkdir -p "$(dirname "$SNAP")"
    tree_state >"$SNAP"
    printf 'runtime-guard[1]{action,snapshot,lines}:\n  "snapshot","%s","%s"\n' "${SNAP#"$ROOT"/}" "$(wc -l <"$SNAP")"
    exit 0
    ;;
  verify)
    [ -f "$SNAP" ] || { printf 'error: no snapshot to verify against\nhelp: runtime-guard.sh snapshot, run the stack, then verify\n' >&2; exit 2; }
    if diff -q "$SNAP" <(tree_state) >/dev/null 2>&1; then
      printf 'runtime-guard[1]{action,result,detail}:\n  "verify","ok","the tree did not move while the system ran"\n'
      exit 0
    fi
    printf 'runtime-guard[1]{action,result,detail}:\n  "verify","FAIL","the tree moved while the system ran — see the diff below"\n'
    diff "$SNAP" <(tree_state) | sed 's/^/  /'
    exit 1
    ;;
  check)
    findings=0
    printf 'runtime-guard[2]{finding,path,remedy}:\n'
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      p="${line:3}"                       # strip the "XY " status prefix
      p="${p%\"}"; p="${p#\"}"            # git quotes odd paths
      case "$p" in *" -> "*) p="${p##* -> }" ;; esac
      if is_runtime "$p" && ! git -C "$ROOT" check-ignore -q "$p" 2>/dev/null \
         && ! git -C "$ROOT" ls-files --error-unmatch "$p" >/dev/null 2>&1 \
         && ! declared "$p"; then
        printf '  "undeclared runtime output","%s","declare it: gitignore it for a workbench, or move it out of the tree for a deployment"\n' "$p"
        findings=$((findings + 1))
      fi
    done < <(tree_state)

    if [ "$findings" -eq 0 ]; then
      printf '  "none","","every runtime artifact is ignored or tracked"\n'
      exit 0
    fi
    printf 'runtime-guard: %s finding(s)\nhelp: the tree is not a runtime — declare the output or move it\n' "$findings" >&2
    exit 1
    ;;
esac

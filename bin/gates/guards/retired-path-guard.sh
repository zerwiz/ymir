#!/usr/bin/env bash
# retired-path-guard.sh — a NEW file may not name a retired home path (plan 331.9).
#
# Plan 331 gave the home four shelves: hodd/ the record, life/ the operator's own material, state/ runtime
# state, config/ settings. Three old paths were retired:
#
#   hodd/life/        -> life/
#   hodd/state/       -> state/
#   hodd/workspaces/  -> life/<topic>/
#
# Tens of thousands of EXISTING files still name them (measured 2026-11-19: hodd/state in 36,504 files,
# hodd/life in 21,118, hodd/workspaces in 5,442). Those are not rewritten by hand: the resolvers change, and
# for one release cycle the links hodd/life -> ../life and hodd/state -> ../state (migration 0026) carry the
# old references to the right shelf. What this guard stops is the SPREAD: the day a path is retired, a new
# file may not teach it again.
#
#   bin/gates/guards/retired-path-guard.sh                  # the staged change (pre-commit): added files only
#   bin/gates/guards/retired-path-guard.sh --range A..B     # the files a range adds (pre-push, CI)
#   bin/gates/guards/retired-path-guard.sh --repo <dir> …   # run against another repository (the home)
#
# Not judged — the places that must name the old paths to do their work or keep their record:
#   .agents/migrations/   the migration that moves them      docs/fixes/          the fix notes (append-only)
#   hodd/reference/moves/ the home's move records            RULES/               the law (append-only)
#   docs/contract-history/ the contract's verbatim prior text (plan 369 item 7)
#   this guard and its test
# A single line may be waived in writing with `retired-path-ok:` and a reason on the same line.
#
# Exit 0 clean · 1 a new file names a retired path (each hit printed as file:line) · 2 usage.
set -u

REPO="."
MODE=staged RANGE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)  REPO="${2:?--repo needs a directory}"; shift 2 ;;
    --range) MODE=range; RANGE="${2:?--range needs A..B}"; shift 2 ;;
    -h|--help) sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'error: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done
git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { printf 'retired-path-guard: %s is not a git tree\n' "$REPO" >&2; exit 2; }

RETIRED='hodd/(life|state|workspaces)/'

exempt() {
  case "$1" in
    .agents/migrations/*|docs/fixes/*|hodd/reference/moves/*|RULES/*) return 0 ;;
    docs/contract-history/*) return 0 ;;   # the contract's verbatim prior text (RULES/06): a record, never edited
    bin/gates/guards/retired-path-guard.sh|bin/gates/tests/test_retired_path_guard.sh) return 0 ;;
  esac
  return 1
}

if [ "$MODE" = range ]; then
  files="$(git -C "$REPO" diff --name-only --diff-filter=A "$RANGE" 2>/dev/null)"
  show() { git -C "$REPO" show "${RANGE##*..}:$1" 2>/dev/null; }
else
  files="$(git -C "$REPO" diff --cached --name-only --diff-filter=A 2>/dev/null)"
  show() { git -C "$REPO" show ":$1" 2>/dev/null; }
fi

hits=0 n=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  exempt "$f" && continue
  case "$f" in *.png|*.jpg|*.jpeg|*.gif|*.pdf|*.zip|*.gz|*.db|*.engram*|*.woff*|*.ttf|*.ico) continue ;; esac
  n=$((n + 1))
  while IFS= read -r line; do
    case "$line" in *retired-path-ok:*) continue ;; esac
    printf 'retired-path-guard: %s:%s names a retired path — %s\n' "$f" "${line%%:*}" \
      "$(printf '%s' "${line#*:}" | grep -oE "$RETIRED" | head -1)"
    hits=$((hits + 1))
  done < <(show "$f" | tr -d '\000' | grep -nE "$RETIRED")
done <<<"$files"

if [ "$hits" -gt 0 ]; then
  printf '\nretired-path-guard: BLOCKED — %s line(s) in new files name a retired home path (plan 331).\n' "$hits" >&2
  printf '  hodd/life/ -> life/   ·   hodd/state/ -> state/   ·   hodd/workspaces/ -> life/<topic>/\n' >&2
  printf '  in code, ask the resolver (bin/vault/hoard-lib.sh hoard_state_dir, ymir_home_root) instead of a path;\n' >&2
  printf '  in a document, cite .ymir-layout.yaml or hodd/identity/home.yaml; a line that must stay: retired-path-ok: <why>\n' >&2
  exit 1
fi
printf 'retired-path-guard: clean — %s new file(s) judged, none names a retired path\n' "$n"
exit 0

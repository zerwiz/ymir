#!/usr/bin/env bash
# branch-guard.sh — Rule 08: no push may land on a protected branch.
#
# Extracted from the ad-hoc .git/hooks/pre-push so the delivery gate is
# versioned and reproducible (installed by bin/gates/guards/fixes-guard.sh --install,
# or run by hand). A local merge on a verbal word is a decision, not a
# delivery — the gate is only fed by a PR (RULES/08-delivery-gate.md).
#
#   bin/gates/guards/branch-guard.sh            # pre-push: refs on stdin (hook mode)
#   bin/gates/guards/branch-guard.sh --branch X # check one branch name
#
#   bin/gates/guards/branch-guard.sh --documents <base> <head>
#                                    # exit 0 when base..head changes documents only
#
# THE DOCUMENT ROAD (RULES/08, appended 2026-11-12). A push that lands on `main`
# is allowed when EVERY file it changes is a document, by this exact set:
#   docs/**/*.md         added or modified — except docs/features/_catalogue/**
#                        (fragments woven into FEATURES.md)
#   docs/fixes/<c>/*.md  added only (a fix note is never rewritten)
#   RULES/*.md           added, or modified with ZERO deleted lines (append-only)
# and the push is a fast-forward of what the branch already is. Any other path —
# code, config, script, app, AGENTS.md, a skill, a deletion, a rename — still
# leaves by PR.
#
# Exit codes: 0 = clear, 1 = blocked, 2 = usage.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

PROTECTED="main master release production"

usage() {
  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

block() {  # <branch> [why]
  cat >&2 <<EOF
⛔ Rule 08 violation: direct push to '$1' is forbidden.
   Work leaves by PR: branch → commit → push → gh pr create → Glitnir review.
   Only a push whose every changed file is a document may land on '$1' directly.
   See RULES/08-delivery-gate.md
EOF
  [ -n "${2:-}" ] && printf 'why: %s\n' "$2" >&2
  printf 'error: branch-guard blocked a push to protected branch "%s"\n' "$1" >&2
  printf 'help: push a feature branch and open a PR instead (gh pr create)\n' >&2
  exit 1
}

is_protected() {  # <branch> — exit 0 when protected
  local b=${1-} p
  [ -n "$b" ] || return 1
  for p in $PROTECTED; do [ "$b" = "$p" ] && return 0; done
  return 1
}

# is_document_path <status> <path> <deleted-lines> — exit 0 when this one change is
# a document change by the set in the header. Status is git's A/M letter.
is_document_path() {
  local st="$1" p="$2" del="${3:-0}"
  case "$st" in A|M) ;; *) return 1 ;; esac
  case "$p" in
    docs/features/_catalogue/*) return 1 ;;
    docs/fixes/*/*.md) [ "$st" = A ] ;;
    docs/*.md) return 0 ;;
    RULES/*/*) return 1 ;;
    RULES/*.md) [ "$st" = A ] || [ "$del" = 0 ] ;;
    *) return 1 ;;
  esac
}

# DOC_WHY carries the first reason a range is not document-only, for the refusal.
DOC_WHY=""
documents_only() {  # <base> <head> — exit 0 when base..head changes documents only
  local base="$1" head="$2" st p del n=0 numstat names
  DOC_WHY=""
  git -C "$ROOT" cat-file -e "$base^{commit}" 2>/dev/null \
    || { DOC_WHY="the remote tip $base is not in this clone — fetch first"; return 1; }
  git -C "$ROOT" cat-file -e "$head^{commit}" 2>/dev/null \
    || { DOC_WHY="cannot read the pushed commit $head"; return 1; }
  git -C "$ROOT" merge-base --is-ancestor "$base" "$head" 2>/dev/null \
    || { DOC_WHY="not a fast-forward — a rewrite is never a document change"; return 1; }
  numstat="$(git -C "$ROOT" diff --no-renames --numstat "$base" "$head")"
  names="$(git -C "$ROOT" diff --no-renames --name-status "$base" "$head")"
  while IFS=$'\t' read -r st p; do
    [ -n "${p:-}" ] || continue
    n=$((n+1))
    del="$(printf '%s\n' "$numstat" | awk -F'\t' -v f="$p" '$3==f{print $2; exit}')"
    if ! is_document_path "$st" "$p" "${del:-0}"; then
      DOC_WHY="$p ($st) is not a document by the RULES/08 set"
      return 1
    fi
  done <<<"$names"
  [ "$n" -gt 0 ] || { DOC_WHY="the push changes no file"; return 1; }
  return 0
}

case "${1:-}" in
  -v|-V|--version) printf '1.1.0\n'; exit 0 ;;
  --documents)
    { [ -n "${2:-}" ] && [ -n "${3:-}" ]; } || usage
    if documents_only "$2" "$3"; then
      printf 'branch-guard[1]{gate,result}:\n  "documents","only documents"\n'; exit 0
    fi
    printf 'branch-guard[1]{gate,result}:\n  "documents","not documents only — %s"\n' "$DOC_WHY"; exit 1 ;;
  -h|--help) usage ;;
  --branch)
    b="${2:-}"; [ -n "$b" ] || usage
    is_protected "$b" && block "$b"
    printf 'branch-guard[1]{gate,result}:\n  "branch","ok"\n'; exit 0 ;;
  "") : ;;
  *) usage ;;
esac

# Judge the DESTINATION refs the push names, and nothing else. A push lands only
# on the branch it names, so standing on `main` while pushing — or deleting — a
# FEATURE branch is legal. The earlier "block when HEAD is protected" pre-check
# refused every such push, so deleting a merged branch from `main` needed
# --no-verify (found 2026-10-18). RULES/08 is about where a push LANDS, not about
# where the operator happens to be standing.
saw_ref=0
ZERO=0000000000000000000000000000000000000000
while read -r _local_ref local_sha remote_ref remote_sha; do
  [ -n "${remote_ref:-}" ] || continue
  saw_ref=1
  rb="${remote_ref#refs/heads/}"
  is_protected "$rb" || continue
  # The document road: an existing protected branch, moved forward, by documents only.
  # A creation or a deletion of a protected branch is never a document change.
  if [ "${local_sha:-$ZERO}" != "$ZERO" ] && [ "${remote_sha:-$ZERO}" != "$ZERO" ] \
     && documents_only "$remote_sha" "$local_sha"; then
    printf 'branch-guard: %s — documents only, the document road (RULES/08, 2026-11-12)\n' "$rb"
    continue
  fi
  block "$rb" "$DOC_WHY"
done

# No refs on stdin — run by hand rather than as a pre-push hook: judge the
# current branch, which is what a bare `git push` would land on.
if [ "$saw_ref" = 0 ]; then
  current="$(git -C "$ROOT" symbolic-ref --short HEAD 2>/dev/null || echo '')"
  is_protected "$current" && block "$current"
fi

printf 'branch-guard[1]{gate,result}:\n  "branch","ok"\n'
exit 0

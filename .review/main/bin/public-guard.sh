#!/usr/bin/env bash
# public-guard.sh — every PUBLIC, user-facing file must be free of operator
# private content (tenant names, personal handles, domains, /home paths, secret
# shapes). Supersedes agents-guard (root AGENTS.md is just one public file).
#
#   bin/public-guard.sh          # inspect the staged change (pre-commit)
#   bin/public-guard.sh --all    # inspect every tracked public file
#
# Two lessons are baked in here (2026-09-12):
#   1. The scan used to cover only root docs, so `apps/`, `bin/`, `scripts/` and
#      `.agents/` shipped unchecked — and a personal domain, a personal bundle id
#      and a live tunnel credential path sat in them for months.
#   2. Append-only records are HISTORY. Rewriting one to hide a name would
#      falsify the ledger, so they are exempt from the sweep by design and named
#      here rather than quietly skipped.
set -u
# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yh="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  for _i in 1 2 3 4 5; do
    [ -n "$_yh" ] || break
    if [ -r "$_yh/bin/hoard-lib.sh" ]; then . "$_yh/bin/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    if [ -r "$_yh/hoard-lib.sh" ]; then . "$_yh/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    _yh="$(cd "$_yh/.." 2>/dev/null && pwd)"
  done
  unset _yh _i
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# The public tree scanned for private markers: shipped code, agent surfaces, docs.
PUBLIC='^(apps/|bin/|scripts/|config/|midgard/|\.agents/|\.pi/|\.opencode/|AGENTS\.md|README\.md|TODO\.md|Structure\.md|CONTRIBUTING\.md|SECURITY\.md|NOTICE|docs/)'
# Append-only records and archived reference material: history, never rewritten.
APPEND_ONLY='(^docs/fixes/|^docs/append-only-log\.md$|^docs/plans/|^assets/reference/|^.agents/state/)'
# Operator-private markers that must never appear in a public file.
# Note: the public owner identity — "zerwiz" the repo holder, its public domains,
# and the project's own repo forms — is intentionally NOT private. What stays
# guarded: other personal names, real /home paths, tenants, and secret shapes.
PATTERNS='(josef|lindbom|$HOME|(ghp|gho|ghs|ghr)_[A-Za-z0-9]{36}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]+|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'
# Legitimate exceptions, named explicitly rather than by widening the pattern:
#   - the public owner identity (the repo's full URL, the short owner/repo form,
#     and the owner's public homepage — the copyright holder on every licence);
#   - AWS's documented dummy key, which is a fixture, not a credential.
ALLOW='github\.com/zerwiz/|zerwiz/ymir|zerwiz\.org|akka://|AKIAIOSFODNN7EXAMPLE|AKIA[A-Z0-9]*EXAMPLE'

leaks() {  # stdin → prints masked hits, returns 1 on any
  grep -En "$PATTERNS" \
    | grep -Ev "$ALLOW" \
    | sed -E 's/(sk-|ghp_|AKIA|xox[a-z]*-)[A-Za-z0-9-]+/\1…/g; s#$HOME#/home/<user>#g' \
    | head -5
}

scan_one() {  # $1 = path in the index; prints a finding, returns 1 when clean
  local f="$1" out
  # This file necessarily contains the patterns it looks for; scanning it would
  # always fail. The same is true of every guard whose job is to name a secret
  # shape, so all three are exempt by name — and the patterns in them stay honest.
  case "$f" in bin/public-guard.sh|bin/secret-guard.sh|bin/hoard-guard.sh) return 0 ;; esac
  printf '%s\n' "$f" | grep -Eq "$PUBLIC" || return 0
  printf '%s\n' "$f" | grep -Eq "$APPEND_ONLY" && return 0
  out="$(git -C "$ROOT" show ":$f" 2>/dev/null | leaks)" || true
  if [ -n "$out" ]; then
    printf 'public-guard: %s\n%s\n' "$f" "$out" >&2
    return 1
  fi
  return 0
}

hit=0
if [ "${1:-}" = "--all" ]; then
  while IFS= read -r f; do
    scan_one "$f" || hit=1
  done < <(git -C "$ROOT" ls-files)
else
  while IFS= read -r f; do
    scan_one "$f" || hit=1
  done < <(git -C "$ROOT" diff --cached --name-only --diff-filter=ACM)
fi

[ "$hit" = 0 ] || { printf 'public-guard: blocked — that is private; move it to $YMIR_HOME (Rule 04)\n' >&2; exit 1; }
exit 0

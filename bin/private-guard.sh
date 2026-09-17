#!/usr/bin/env bash
# private-guard.sh — enforce the Hoard boundary (Rule 04). Nothing under a
# private path may be TRACKED except its allowed guard/scaffold/example. Besides
# secret-guard (values) and docs-guard (public docs/), this stops a private
# path being committed — even by `git add -f` or a `git mv` that bypasses
# .gitignore.
#
#   bin/private-guard.sh           # inspect the staged change
#   bin/private-guard.sh --all     # inspect every tracked file
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Private roots — nothing here is public. These paths may exist locally
# but MUST never be committed: they live at YMIR_HOME, env-driven.
FORBID='^(hodd/|svartalfaheim/|state/|data/|workspace/(work|personal|memory|companies)/|workspace/config/|workspace/marketing/|workspace/INSTALL\.md|assets/reference/state/|\.a2a/|\.env)'
# Allowed tracked exceptions inside those roots.
ALLOW='^(hodd/(README\.md|\.gitignore|AGENTS\.example\.md|[^/]+\.example(\.md)?)$|svartalfaheim/.*(README\.md|\.gitkeep|\.gitignore|\.example(\.md)?)$|state/\.gitkeep$|data/[^/]+\.example$|assets/reference/state/[^/]+\.example$|\.env\.example|\.env\.sample)$'

# Tenant DOCUMENTS — a wiki, policy set, vision, roadmap or strategy file is
# company/operator knowledge, not a public asset. It belongs at
# $YMIR_HOME/hodd/identity/companies/<company>/ and nowhere in this repo.
# Added 2026-09-17 after `midgard/company_wiki/` was found sitting in the
# public tree: it was an empty placeholder, but the shape invited the leak.
#
# The match is deliberately a DIRECTORY or a doc suffixed with tenant content —
# NOT the bare word. `svartalfaheim/examples/SECRETS.md` is a public how-to (it
# teaches where secrets go and holds no value), so a bare `secrets` match would
# be a false positive.
TENANT_DOC='((^|/)(company_wiki|wiki|policies|handbook|playbook|internal|confidential)(/|\.)|(^|/)(vision|strategy|roadmap|policies)[^/]*\.(md|txt|rst|pdf|docx?)$)'
# Public exceptions: a wiki-shaped name that is a genuine scaffold or doc.
TENANT_DOC_ALLOW='(\.example$|\.example\.md$|README\.md$|/\.gitkeep$)'

scan_list() {
  local hit=0 f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if printf '%s\n' "$f" | grep -Eq "$FORBID" && ! printf '%s\n' "$f" | grep -Eq "$ALLOW"; then
      printf 'private-guard: tracked private path: %s\n' "$f" >&2
      hit=1
      continue
    fi
    if printf '%s\n' "$f" | grep -Eq "$TENANT_DOC" && ! printf '%s\n' "$f" | grep -Eq "$TENANT_DOC_ALLOW"; then
      printf 'private-guard: tenant/company document in the public tree: %s\n' "$f" >&2
      printf '  company knowledge belongs at $YMIR_HOME/hodd/identity/companies/, never here\n' >&2
      hit=1
    fi
  done
  return "$hit"
}

if [ "${1:-}" = "--all" ]; then
  scan_list < <(git -C "$ROOT" ls-files)
else
  scan_list < <(git -C "$ROOT" diff --cached --name-only --diff-filter=ACM)
fi || { printf 'private-guard: blocked — that path is private; keep it in the Hoard and untracked\n' >&2; exit 1; }
exit 0

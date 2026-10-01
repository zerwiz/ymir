#!/usr/bin/env bash
# private-guard.sh — enforce the Hoard boundary (Rule 04). Nothing under a
# private path may be TRACKED except its allowed guard/scaffold/example. Besides
# secret-guard (values) and docs-guard (public docs/), this stops a private
# path being committed — even by `git add -f` or a `git mv` that bypasses
# .gitignore.
#
#   bin/gates/guards/private-guard.sh           # inspect the staged change
#   bin/gates/guards/private-guard.sh --all     # inspect every tracked file
set -u
# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yh="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  for _i in 1 2 3 4 5; do
    [ -n "$_yh" ] || break
    if [ -r "$_yh/bin/vault/hoard-lib.sh" ]; then . "$_yh/bin/vault/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    if [ -r "$_yh/hoard-lib.sh" ]; then . "$_yh/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    _yh="$(cd "$_yh/.." 2>/dev/null && pwd)"
  done
  unset _yh _i
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

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

# CONTENT — operator IDENTITY and TOPOLOGY (Rule 04, appended 2026-10-01).
#
# private-guard above polices PATHS and secret-guard polices CREDENTIAL VALUES.
# Neither ever looked at the plain text of a file for who the operator IS or
# WHERE their machines live: a username, a tailnet domain, a personal hostname,
# a fleet hardware inventory. That content is personal even though it is not a
# secret, so no ward woke when it was committed and pushed to a public remote.
#
# The patterns below are deliberately GENERIC and shape-based. The operator's
# own name, domains and hosts are never written into this repo — naming them
# here would re-create the very leak this guard exists to stop. It matches the
# SHAPE of private identity; the values live at $YMIR_HOME.
PERSONAL='(/home/[a-z][a-z0-9._-]*/|[a-z0-9][a-z0-9-]*\.ts\.net|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]{1,3}\.[0-9]{1,3})'
# `$HOME` and `<user>` / `<host>` placeholders are the PUBLIC way to say these
# things — a doc using them teaches the craft without naming the man.
PERSONAL_OK='(\$HOME|\$\{HOME\}|\$USER|\$HOME_SEAT|<user>|<host>|<tailnet>|<gpu>|<seat>|<home>|/home/user/|100\.64\.0\.0/10)'

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
      continue
    fi
    # Synthetic fixtures are not the operator. A test's /home/alice and a
    # fleet.json.example's host.tail.ts.net are teaching shapes, not identity.
    case "$f" in
      *.test.sh|*.test.ts|*.test.py|*/tests/*|tests/*|*.example|*.example.*|*/fixtures/*) continue ;;
    esac
    if [ -f "$ROOT/$f" ] && grep -Eq "$PERSONAL" "$ROOT/$f" 2>/dev/null && ! grep -Eq "$PERSONAL_OK" "$ROOT/$f" 2>/dev/null; then
      printf 'private-guard: operator identity/topology in public file: %s\n' "$f" >&2
      grep -En "$PERSONAL" "$ROOT/$f" 2>/dev/null | head -3 | cut -c1-160 | sed 's/^/  /' >&2
      printf '  say it with $HOME / <user> / <host> / <tailnet>, or keep it at $YMIR_HOME\n' >&2
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

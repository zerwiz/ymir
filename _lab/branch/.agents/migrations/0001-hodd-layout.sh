#!/usr/bin/env bash
# 0001-hodd-layout — consolidate private material into hodd/ for homes that
# predate the Hoard (RULES/04-hoard.md). Idempotent: safe to run repeatedly.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOARD="${YMIR_HOARD:-$ROOT/hodd}"

mkdir -p "$HOARD/secrets" "$HOARD/docs" "$HOARD/tenants" "$HOARD/identity"

move() {  # <src> <dest-dir>
  [ -e "$1" ] || return 0
  mkdir -p "$2" || return 0
  if [ -e "$2/$(basename "$1")" ]; then return 0; fi
  mv -n "$1" "$2/$(basename "$1")" 2>/dev/null && printf '  moved %s\n' "${1#$ROOT/}"
}

# Private documents
for f in masterplan.md append-only-log.md; do move "$ROOT/docs/$f" "$HOARD/docs"; done
move "$ROOT/docs/plans" "$HOARD/docs"

# Private project data
for f in "$ROOT"/assets/data/aigf-*.md; do [ -e "$f" ] && move "$f" "$HOARD/docs/aigf"; done

# Business identity
move "$ROOT/svartalfaheim/wayof/AGENTS.md" "$HOARD/identity/svartalfaheim/wayof"
move "$ROOT/svartalfaheim/wayof/companies/wayof/entity.md" "$HOARD/identity/svartalfaheim/wayof/companies/wayof"
for f in "$ROOT"/svartalfaheim/wayof/domains/*/entity.md; do
  [ -e "$f" ] || continue
  d="$(basename "$(dirname "$f")")"
  move "$f" "$HOARD/identity/svartalfaheim/wayof/domains/$d"
done

# Registries (leave the tracked *.example scaffold behind)
move "$ROOT/workspace/projects.yaml" "$HOARD/identity"
move "$ROOT/workspace/workspaces.yaml" "$HOARD/identity"

echo "0001-hodd-layout: done"

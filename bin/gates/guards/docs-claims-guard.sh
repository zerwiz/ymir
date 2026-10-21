#!/usr/bin/env bash
# docs-claims-guard.sh — Rule 27: a user-facing document may not name a road that is closed.
#
# Runs the claims checker over every document a USER reads: the README, the feature
# catalogue, the lore, and each feature how-to. It fails the push, which is the only
# place a stale instruction can still be stopped cheaply.
#
#   docs-claims-guard.sh check     # the ward (what guards.sh calls)
#
# Exit: 0 every claim resolves · 1 a claim does not · 2 usage.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CMD="${1:-check}"; shift || true
case "$CMD" in
  check|--version|-h|--help) ;;
  *) printf 'error: unknown command %s\nhelp: docs-claims-guard.sh check\n' "$CMD" >&2; exit 2 ;;
esac
[ "$CMD" = "check" ] || { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

files=("$ROOT/README.md" "$ROOT/FEATURES.md" "$ROOT/docs/lore.md")
while IFS= read -r page; do files+=("$page"); done < <(ls "$ROOT"/docs/features/*.md 2>/dev/null)

if out="$(bash "$ROOT/bin/gates/checks/readme-claims.sh" "${files[@]}" 2>&1)"; then
  printf 'docs-claims-guard[1]{ward,result}:\n  "documentation","every claim resolves across %s page(s)"\n' "${#files[@]}"
  exit 0
fi
printf '%s\n' "$out" | tail -20
printf 'docs-claims-guard: a document names a road that is closed — fix it or waive it in writing (Rule 27)\n' >&2
exit 1

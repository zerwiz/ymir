#!/usr/bin/env bash
# no-delete — Rule 11 — a tracked file is moved, never deleted (against the PR's base).
#
# RULES/11 says the ward runs here; until 2026-11-03 nothing called it, so a deletion passed CI
# unseen. The range is the PR's base when there is one, and an honest SKIP (not a green) when this
# checkout has no base.
if nd_base="$(nodelete_base)"; then
  gate no-delete "Rule 11 — a tracked file is moved, never deleted (against $nd_base)" \
       bash "$ROOT/bin/no-delete-guard.sh" --base "$nd_base"
else
  printf '  "%s","SKIP","%s"\n' "no-delete" "no base ref in this checkout — judged by the pre-push hook and on a PR"
fi

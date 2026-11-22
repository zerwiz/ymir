#!/usr/bin/env bash
# lore-audit — 2026-11-22 (plan 350 A): every system the saga tells of has a row in docs/lore-claims.tsv, its door is
# measured (true · partial · false · planned), and the weekly watch names a claim that turned false.
gate lore-audit "every saga system has a measured claim; a claim gone false is named" \
     bash "$ROOT/bin/records/tests/test_lore_audit.sh"

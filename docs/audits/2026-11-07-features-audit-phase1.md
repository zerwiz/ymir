# Audit Phase 1 — The catalogue itself

**Date:** 2026-11-07
**Plan:** 213
**Scope:** FEATURES.md, docs/features/_catalogue/, docs/features/

## Weave check

`bin/records/weave-features.sh --check` → `FEATURES.md is current (179 entries)`

The catalogue and the woven file agree. No drift at the weave level.

## Rows with no how-to page (blank debt)

Three rows carry `—` instead of a link:

1. **Sensitive-data tests** (`tests/test_snotra_sensitive.sh`) — Security
2. **The board's promises** (`systems/snotra/services/cron/trello-due.sh`) — Security
3. **The house watch** (`bin/time/housewatch.sh`) — Runtime

These features ship code but have no user-facing page. Per Rule 14, a feature with no
page is not finished. Each needs a `docs/features/*.md` page and a catalogue row update.

## Orphan pages

Only `docs/features/README.md` is unreferenced — expected, it is the index.

## Verdict

Phase 1: **stands**. The catalogue is whole and woven. Three how-to debt items to
carry into Phase 7 (codebase audit) and then into follow-up plans.
## CHANGE LOG

- **2026-11-08** — the document was committed by the catalogue-audit pane without its change log, and
  `rules-compliance-guard` (RULES/06) refused the branch that carried it. The section is added here, in the
  author's own record, rather than the document being rewritten.

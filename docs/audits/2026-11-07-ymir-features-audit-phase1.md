# Features audit — Phase 1 of plan 213

Date: 2026-11-07
Scope: read-only catalogue audit. No code changes.

## 1. Weave check

Command: `bin/records/weave-features.sh --check`

Result: `FEATURES.md is current (179 entries)` — exit 0. The woven catalogue matches its fragments.

## 2. FEATURES.md rows whose `how-to` is blank or points at a missing file

Scanned all 179 entry fragments in `docs/features/_catalogue/entries/`. 134 are feature rows; the rest are structural (blank/section-header) rows. Of the feature rows, the following carry a blank, dash, or non-file value in the `how-to` column (no row points at a missing file — every markdown link in the `how-to` column resolves):

| entry file | feature | how-to value |
|---|---|---|
| `06-028-security-sensitive-data-tests-tests-test-sno.md` | **Sensitive-data tests** (`tests/test_snotra_sensitive.sh`) | `—` |
| `06-040-security-the-board-s-promises-systems-snotra.md` | **The board's promises** (`systems/snotra/services/cron/trello-due.sh`) | `—` |
| `06-041-runtime-the-house-watch-bin-time-housewatch-.md` | **The house watch** (`bin/time/housewatch.sh`) | `—` |
| `06-065-voice-voice-notes-speaking-to-ymir-and-heari.md` | **Voice notes — speaking to Ymir and hearing it answer** | `owner-only chat` (link lives in the "what" column) |
| `06-069-runtime-the-well-answers-on-every-role-a-pho.md` | **The well answers on every role — a phone borrows the heart's memory instead of being dark** | `RULES/25 (2026-10-28 section), RULES/39` (link lives in the "what" column) |
| `06-070-runtime-the-clock-can-say-hourly-schedules-t.md` | **The clock can say hourly — schedules that repeat, not just land** | `plan 140` (link lives in the "what" column) |

No row's `how-to` cell points at a missing file.

## 3. `docs/features/*.md` not named by any row

Command: `bin/gates/guards/features-guard.sh` → `every feature page is catalogued, and the woven catalogue is current` (exit 0).

Orphan page count: 0. Every page under `docs/features/` (excluding `README.md`) is named somewhere in `FEATURES.md`.

## Summary

- Weave: current (179 entries).
- Blank/missing how-to rows: 6 (3 with `—`, 3 with a non-file note where the link sits in the "what" column).
- Missing-file how-to rows: 0.
- Orphan feature pages: 0.
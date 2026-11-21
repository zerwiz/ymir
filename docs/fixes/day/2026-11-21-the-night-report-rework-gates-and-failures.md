# 2026-11-21 — the night report's tests are a gate, and its failures speak

**Component:** day (`bin/day/night_report.py`), with one gate file (`bin/gates/checks.d/0545-night-report.sh`).

This note closes items 4 to 6 of the judge's review of PR #867. The detail is in the addenda at the foot
of `docs/fixes/day/2026-11-21-the-night-report.md`.

- **Item 4.** `bin/gates/checks.d/0545-night-report.sh` runs `bin/day/tests/test_night_report.py` in
  every gate run.
- **Item 5.** A missing default repository and a PR whose state `gh` could not read are named under
  *What could not be read*. A failed ship exits 1, and the message says the report is on one seat only.
- **Item 6.** The first note's dry-run numbers and the PR body's came from two runs; the addendum says
  which to quote.

Proof: `python3 bin/day/tests/test_night_report.py` runs 9 tests, and all pass.

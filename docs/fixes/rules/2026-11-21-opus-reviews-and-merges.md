# rules · 2026-11-21 — RULES/08: every PR reviewed by Claude Opus; an approval merges at once

## What changed

At the Allfather's word (*"We need to have a claude opus review every pr. If its OK. He merges instantly"*), RULES/08
gains a section. Every PR is reviewed by the judge, now Claude Opus (`forseti` in the home's config: harness
`claude`, model `opus`). On APPROVE, the judge re-checks the gates, mergeability, the hold and the head at that
instant, and merges under the operator's account, with one Rune per merge. NEEDS-REWORK sends the items back. A red
or pending gate never merges.

## Files

- `RULES/08-delivery-gate.md` — the appended section

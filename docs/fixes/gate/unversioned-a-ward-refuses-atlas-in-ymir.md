## gate · unversioned · 2026-11-18 — a ward refuses the word atlas in Ymir

### Why
Atlas and Ymir are separate projects (RULES/58). Nothing enforced it, so Atlas material could come back into Ymir unseen.

### Files
- `bin/gates/guards/rules-compliance-guard.sh`
- `RULES/58-atlas-is-not-ymir.md`, `RULES/README.md`
- `docs/fixes/gate/unversioned-a-ward-refuses-atlas-in-ymir.md`

### What
Rule R5 refuses the whole word "atlas" on any line a push adds or changes in a Ymir file. Whole word only, so "Atlassian" passes. Fix notes, rules, guards and guard tests are exempt because they must name what they forbid. The ward now also reads modified files, and no longer exits early when a push adds no new file.

### Verified
See the probe in the PR: a push that adds the word is refused, and one that adds "Atlassian" is not.

## CHANGE LOG

- **2026-11-18** — opened.

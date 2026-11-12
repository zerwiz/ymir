# Frontend Best Practices — __PROJECT__

## Structure
- Feature-based folders; shared UI in a common components dir.

## State
- Server state via a data-fetching library; local UI state via hooks.
- No global state store unless genuinely cross-cutting.

## Styling
- Pinned CSS approach; no inline magic values.
- Responsive-first.

## Enforced By
- `.agents/skills/lifecycle/status.sh` + feature smoke tests.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.

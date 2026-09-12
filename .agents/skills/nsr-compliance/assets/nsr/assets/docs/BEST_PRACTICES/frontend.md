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
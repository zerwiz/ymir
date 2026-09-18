## runtime · unversioned · 2026-09-17 — the fleet stops colliding: a grid fan, and each smith's own house

### Why
- **The Fleet graph collided above ~8 agents.** `Fleet.tsx` fanned every
  non-hub agent into a single two-row line at ~4.4% pitch on 46px rings — with
  20 roster cards the rings and labels overlapped into an unreadable pile.
  `layout()` now fans a square-ish grid (`cols = ceil(sqrt(n))`, hub at top,
  rows pitched past ring+label), so 20 agents render separated.
- **Every ring showed the same rune.** `bin/hlidskjalf-agents.sh` hardcoded
  `domain: ymirlabs` for every card and its roster parser never read the
  `domain:` frontmatter each figure carries — so all twenty cards wore the
  anonymous ᛦ. The roster now parses `domain:` and passes it through;
  `galdr.md` names its house (`brokkforge`); the graph falls back to
  `DOMAINS.ymirlabs` only when a domain is genuinely unknown (was a crash)
  — and the `AgentCard` already fell back safely.

galdr-reread: `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md` — the
Fleet graph paragraph (grid fan, roster domains, fallback).

### Files
- *(carried from the frozen CHANGELOG.md)*

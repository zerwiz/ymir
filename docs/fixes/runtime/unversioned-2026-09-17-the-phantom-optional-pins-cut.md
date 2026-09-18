## runtime · unversioned · 2026-09-17 — the phantom optional pins, cut

### Why
- The platform's stale \`optionalDependencies\` (sessrumnir pinned at the broken
  0.1.9) shadowed the required \`^0.1.10\` — npm never fetched the good seat.
  Removed; the required deps now resolve to latest (0.1.18).

### Files
- *(carried from the frozen CHANGELOG.md)*

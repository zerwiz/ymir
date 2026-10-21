## docs · 2026-10-21 — the claims ward, the roster, and the two gates that were only stale

### Why
CI on #385 failed five gates. Three were real, and two were the same wound seen twice.

**1 · `ward` — `docs-claims-guard` failed in a clean checkout and passed on the box.** The
difference is untracked files: 13 claims name paths that live in the **home**, not the repo —
`config/agents.yaml` (the operator's own file; the repo ships `config/agents.yaml.example`),
`config/cron.yaml`, `config/tailscale-sync.yaml`, `.agents/skills-local/` (gitignored by design)
and `apps/odrerir/public/livehall.json` (generated at runtime). On this box they exist; in CI
they never will.

**2 · `compliance` — `in-tree-but-not-rostered:modgud`.** The new chair's profile
(`.agents/agents/modgud-auditor.md`) had no row in the roster the compliance gate reads
(`config/agents.yaml.example`), so the canonical tree and the roster disagreed.

**3 · `capability` and `inventory` — STALE, twice.** Both are generated from the tree, and both
were regenerated *before* the last scripts landed, so the register said 531 doors while the tree
held more. They are now regenerated last: `capabilities --check` → current (536 door rows),
`inventory --check` → current.

### Fix
- `docs/README-claims.waived` — the guard's own written-waiver mechanism (`grep -qxF` on one path
  per line), with the reason for each entry in comments. A waiver, not a silence: the guard still
  checks every other claim.
- `config/agents.yaml.example` gains `modgud` — the roster and the tree agree again.
- The register and both inventories regenerated **after** the last change.

### Verification
```
docs-claims-guard  → "every claim resolves across 124 page(s)"
capabilities --check → current (536 door rows)
inventory --check    → both current (175 files)
```

### The lesson, for the next hand
A generated file must be regenerated **last**, immediately before the commit — otherwise the
gate is green on the bench and red in CI, and the difference is the files you added while it ran.

### Files
- `docs/README-claims.waived` (new)
- `config/agents.yaml.example`
- `.agents/assets/agents/capabilities.md`, `bin/README.md`, `.agents/backend/README.md` (regenerated)

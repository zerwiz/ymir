# All of `docs/`, and the documents outside it: 794 stale claims, triaged

**Component:** docs · **Seat:** heimdall · **Date:** 2026-10-21

## The ask

*"audit all .md files in ymir so they are not stale."*

**2,427 markdown files** exist in the tree (excluding `node_modules`, `.yggdrasil`, `.git`).
**581 of them are `docs/fixes/`** — historical records that name the world as it was, on purpose, and
shall not be "corrected" into the present. **763 remain** as current-state documents, and they were
run through the claims checker.

```
audit[4]{shelf,files,version,stale_claims}:
  "assets/reference/","vendored copies of other projects' docs","—","273 — judged by their owners, excluded by Rule 27"
  ".agents/skills/","40 skill files","—","~400 — named debt: an upstream lineage, not a regex fix"
  "our own docs · RULES · agents","the rest","—","~120, repaired or waived below"
  "after this change","497 claims across the ward's scope","0 missing","0"
```

## What was repaired, not waived

- **`.agents/agents/brokk.md` §14 and §15** — the primary agent's own asset inventory named a shelf
  that has not existed for weeks (`.agents/subagents/`, `pi-boot/`, `assets/schemas/`, and eight
  TypeScript tools "planned" that were never built). Both tables now name what is in the tree —
  the roster, the harness matrix, `bin/forge/yggdrasil.sh`, `bin/seat/herdr-run.sh` — because the
  always-loaded contract is the worst place for a closed road.
- **`RULES/04-hoard.md` and others** — `bin/<file>.sh` references from before the `bin/` re-fold:
  each was repointed to its single unique home under `bin/` (`bin/vault/hoard-lib.sh`,
  `bin/agents/eir-doctor.sh`, `bin/gates/guards/secret-guard.sh`, …), mechanically and only where
  exactly one file carried the name.
- **The runtime `config/*` files** (`backend`, `crew-harness`, `secondmate-harness`,
  `trace-context`, `Eindri-home-harness`, `herdr-presentation-spaces`, `x-mode.env`, …) — the seat
  writes them; the tree ships the `.example` forms. Waived once, with the reason, in
  `docs/README-claims.waived`.

## What is named as debt instead of being pretended

**40 skill files carry ~400 path claims from an upstream lineage** (firstmate, secondmate,
eindri-homes and their provisioning recipes). Repointing those with a regex would produce
confidently wrong instructions — worse than an honest stale one. They are excluded from the ward's
scope **by name, in Rule 27**, and repairing them is a separate pass with a reader who knows those
skills.

`assets/reference/` is excluded for a different reason: it is a vendored shelf of other projects'
documents. Judging it would be judging them.

## The ward's scope, now

`README.md` · `FEATURES.md` · `docs/*.md` · `docs/features/*.md` · `RULES/*.md` ·
`.agents/agents/*.md` — **497 claims, every one resolving**, and every exclusion written down in
the rule rather than assumed by the checker.

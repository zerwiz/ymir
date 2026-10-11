# Rule 14 — Every feature is explained: `FEATURES.md` and `docs/features/`

> Adopted 2026-10-11, after the Allfather asked how a user is meant to *use* Ymir —
> and the honest answer was "they are not; almost no feature is explained."

**A feature that a user cannot discover and use does not exist, however well it is
built.** This rule makes the explanation part of the feature.

## The two records

1. **`FEATURES.md` (repo root) — the master catalogue.** Every feature and function
   Ymir has, one row each: *area · feature · what it gives you · how-to link*. It is
   the map of the whole system, and it **grows for the life of the project.**
2. **`docs/features/` — the how-tos.** One plain-language page per user-facing
   feature: *what it is · what you need · the commands · limits · if it does not
   work*. Written for the person **using** Ymir, never for the agent building it.
   The index is [`docs/features/README.md`](docs/features/README.md).

The deep reference stays where the code lives (the Galdr assets under
`.agents/skills/galdr-ymirsystem/assets/`); these two are the **user's front door**.

## The law

```
features_law[5]{rule}:
  "A user-facing feature has a page under docs/features/ — a feature with no page is not finished"
  "The same change that adds or changes a feature adds/updates its FEATURES.md row AND its page"
  "FEATURES.md is append-only (Rule 06): add a row; correct by a new entry citing the old, never by erasing"
  "README.md links FEATURES.md and docs/features/; AGENTS.md carries the duty to every agent"
  "A blank how-to link in FEATURES.md is a DEBT, named plainly — not a default to ignore"
```

## Why this exists

The runtime is built beautifully and explained almost nowhere. Skills are covered
for agents, code is covered by fix notes, but the **operator** — the person the whole
thing serves — had no page that said "here is a feature, here is how you use it."
This rule closes that: discoverability and usage are part of shipping.

## Enforcement

`FEATURES.md` and `docs/features/` are checked in the delivery gate alongside the
other records: a push that changes a user-facing feature is expected to touch them,
and the ward **`bin/gates/guards/features-guard.sh`** (seated in `guards.sh`'s
`WARDS`) refuses a `docs/features/*.md` page that the `FEATURES.md` catalogue does
not name. When a feature's command, flag, or limit moves, the page moves in the same
change.

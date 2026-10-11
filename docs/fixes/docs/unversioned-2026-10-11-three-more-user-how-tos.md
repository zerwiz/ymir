## docs · unversioned · 2026-10-11 — three more user how-tos (Hlidskjalf · the well · Mjollnir)

### What

Pays down the first debts of Rule 14's catalogue — the blank `how-to` links in
`FEATURES.md`. Three new plain-language pages, each in the shape Rule 14 fixes
(*what it is · what you need · do it · notes and limits · if it does not work*):

- **`docs/features/hlidskjalf-the-control-plane.md`** — raise the portal
  (`scripts/start.sh`), the SPA `:3888` and gate `:3889`, the in-app login from
  `HLIDSKJALF_AUTH`, invites, the tunnel, the desktop shell.
- **`docs/features/the-well-recall-and-remember.md`** — `bin/records/mimir.sh`
  `health · recall · observe · timeline`, the `:4602` bridge, the `engram` MCP, and the
  limits (one well in the hoard; recall is not authority; nothing confidential enters
  it — Rule 15/16).
- **`docs/features/mjollnir-issue-to-pr.md`** — `bin/forge/mjollnir.sh run --repo …
  --issue …`, the modes and isolation, and the law: a PR, never a merge; Glitnir holds
  the seal.

`FEATURES.md` rows for the three now link their pages.

### Verified

- `guards.sh` → all **seven** wards PASS, including `features-guard`.
- `features-guard check` → `"none","","every feature page is catalogued"`.

### Files

- `docs/features/hlidskjalf-the-control-plane.md` (new)
- `docs/features/the-well-recall-and-remember.md` (new)
- `docs/features/mjollnir-issue-to-pr.md` (new)
- `FEATURES.md`

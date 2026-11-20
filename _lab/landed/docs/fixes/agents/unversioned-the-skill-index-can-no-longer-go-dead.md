## agents · unversioned · 2026-10-18 — the skill index can no longer go dead

### Why

The skills inventory was dead, and the reason was structural, not neglect. Two
half-mechanisms were wired to nothing:

- **`hodd/docs/skills-inventory.md` was a hand-made file no trigger generated and
  no tool read.** Grep for its generator (`skill-inventory.sh`) across the repo
  and the home found zero callers; grep for the inventory itself found only the
  generator writing it. It also pointed at a shelf (`~/command/command/docs/…`)
  that is not the shelf the home holds.
- **`bin/agents/skill-find.sh` never saw the home shelf at all.** It sourced its
  resolver from `$(dirname)/hoard-lib.sh` — a path at which no `hoard-lib.sh`
  exists (`bin/vault/hoard-lib.sh` does) — so the `|| true` swallowed the failure
  and `HOMESKILLS` fell back to the *ship* shelf. The finder then walked only
  `"$shelf"/*/SKILL.md`, one level deep. Four upstream layouts were invisible:
  `skills/<name>/`, `skills/<cat>/<name>/`, `.claude/skills/<name>/`, and the
  flat `skills/*.md` corpora. Roughly **130 skills existed; the finder reached 3.**

### Now

One loop replaces both halves:

- **`bin/agents/skill-index.sh`** walks every shelf **generically** — `SKILL.md`
  at any depth, no pack known by name, so a new developer's pack is seen the
  moment it lands with no code change — and writes ONE machine-readable index at
  `$YMIR_HOME/.agents/skills/skills.yaml`, plus the human inventory. `--check`
  fails loudly when the index is missing a skill or has gone stale.
- **`bin/agents/skill-find.sh`** reads the index first, and refreshes it when it
  is stale. The resolver path is mended. A live, recursive walk is the fallback.
- **`bin/time/saga-session-start.sh`** gains a `SKILLS` section that refreshes the
  index every session, so a session opens knowing what it holds.
- **`bin/agents/skill-vendor-sync.sh`** keeps imported third-party packs current
  (sync, never absorb); provenance lives in `vendor/<source>/.source`.
- The first synced vendor is `github.com/mattpocock/skills` @ `49dd158d` (v1.3.1,
  MIT), 38 skills, under `$YMIR_HOME/.agents/skills/vendor/mattpocock-skills/`.

Measured: **192 skills indexed across 4 shelves** (ships 31 · local 0 · home 117
· pi 44… see the index `total:`).

### Verified

- `.agents/tests/skill-index.test.sh` → **5 passed, 0 failed**: a `SKILL.md`
  nested three levels deep is indexed; `--where` resolves it from the index;
  `--check` passes fresh, **fails** on an incomplete index, and the finder heals
  the index by itself.
- `bin/agents/skill-index.sh --check` → `index fresh: 192 skills`.
- `bin/agents/skill-find.sh --where grill-me` → resolves (the skill that started
  this: it was unfindable before).
- `bin/agents/skill-vendor-sync.sh --check` → `mattpocock-skills current @
  49dd158d1076`.
- `bin/gates/capabilities.sh --check` → current, 459 door rows; both new doors
  read `tested · keep`.

### Files

- `bin/agents/skill-index.sh` (new)
- `bin/agents/skill-find.sh`
- `bin/agents/skill-vendor-sync.sh` (new)
- `bin/time/saga-session-start.sh`
- `.agents/tests/skill-index.test.sh` (new)
- `bin/README.md`, `.agents/assets/agents/capabilities.md` (regenerated)

### Also mended — pre-existing red on `main`, not from this change

- `.agents/skills/galdr-ymirsystem/assets/memory-well.md` — the `well_law`
  TOON block declared `{rule}` (one column) while its rows carried two fields,
  so `compliance-check.sh`'s TOON gate failed on `main` for **any** branch. The
  header now names both columns: `{rule,meaning}`. (Introduced by the Rule 20
  append `d40f5056`.)
- `plans/queue.md` (the home, not this repo) regenerated — it was stale by its
  derived date only; `bin/gates/queue.sh` + `--check` now read current, 66 rows.

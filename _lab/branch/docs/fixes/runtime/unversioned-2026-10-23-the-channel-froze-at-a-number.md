## runtime · unversioned · 2026-10-23 — the npm channel froze at `0.1.53` for 24 days and every check said "in sync"

### Why

The Allfather asked whether npm installs are *beneficial or just duplicates*, then: *"how are this
possible. this are not production ready."* The audit is
`hodd/docs/audits/2026-10-23-the-npm-install-audit.md`; this is the repair.

**What was true on this seat, measured:**

```
published    @zerwiz/ymir@0.1.53 on 2026-09-29   (24 days frozen)
installed    ~/.npm-global/…/@zerwiz/ymir        33,545 files · 840 MB · on PATH as `ymir`
the checkout ~/ymir                              the canon per .ymir-root
drift        doors 532/377 · rules 32/10 · feature pages 69/0   (tree / installed)
```

**Why nothing noticed — five links, each measured:**

1. the version label never moved (`package.json` 0.1.53 while fix notes carried up to 1.2.1);
2. `bin/fleet/fleet-version.sh check` compared **labels**, and three equal labels over two different
   trees is "in sync" — a label check cannot see a content drift;
3. `bin/forge/npm/npm-publish.sh` had no release guard: nothing refused a publish whose version
   already existed — and npm itself refuses to republish a version, so the channel froze silently;
4. the door that would have said so was called by tests and skills, **not** by `guards.sh`, Norni or
   Eir — a ward that runs nowhere;
5. `ymir` on PATH resolved to the installed copy, so an operator typing it got the older house.

### The mends

| # | mend | proof |
|---|---|---|
| 1 | `bin/fleet/fleet-version.sh` measures **content** (doors · rules · feature pages) as well as labels, and its verdict order is fixed: an install NEWER than the tree, a published version newer than the tree, or three equal labels over two trees are faults; a tree ahead of npm is a **release owed** | on this seat: `verdict ahead · a RELEASE is owed — doors 533/377 · rules 32/10 · feature pages 69/0` |
| 2 | `bin/gates/guards/fleet-version-guard.sh` — new ward, seeded in the ONE ward list (14 → 15); a machine with no global copy is a clean **skip** in words (Rule 25) | ward PASS with the release owed named, never a silent green |
| 3 | `bin/forge/npm/npm-publish.sh` refuses a publish whose version npm already has, and a publish from a tree with uncommitted changes | a no-op publish cannot freeze the channel again |
| 4 | `package.json` **0.1.53 → 0.2.0**, so the next publish *can* mean something | `fleet-version.sh` verdict moves from `content drift` to `ahead` |
| 5 | `.agents/migrations/0012-the-library-shelf.sh` — an existing home gets `hodd/library/research` + its README + a generated INDEX (idempotent, invents nothing) | `ymir-migrate.sh status` lists 0012; nothing existing is touched |

**What is deliberately NOT done here:** the globally installed 0.1.53 copy is **not removed**. It is
the Allfather's machine and there are two honest resolutions — remove it (the checkout is the canon) or
publish 0.2.0 and `npm i -g` fresh. Both are his word; the ward now names which one is owed.

### Files
- `bin/fleet/fleet-version.sh` (content comparison + verdict order) · `bin/gates/guards/fleet-version-guard.sh`
- `bin/gates/guards.sh` (15 wards) · `bin/forge/npm/npm-publish.sh` (release guard)
- `package.json` (0.2.0) · `.agents/migrations/0012-the-library-shelf.sh`
- `hodd/docs/audits/2026-10-23-the-npm-install-audit.md` (the audit, in the home)
- `docs/fixes/runtime/unversioned-2026-10-23-the-channel-froze-at-a-number.md`

### Verified
```
bin/fleet/fleet-version.sh check          "ahead — a RELEASE is owed (doors 533/377 · rules 32/10 · feature pages 69/0)"
bin/gates/guards/fleet-version-guard.sh    PASS, naming the release owed
bin/engine/ymir-migrate.sh status          0012 pending (runs on install/update)
```

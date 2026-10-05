## gate · unversioned · 2026-10-05 — everything adapts to the new `bin/` folders

### Why

`bin/` gained system folders and ~250 doors moved. #288 repointed **the callers
inside `bin/`**. This adapts **everything else** — the 759 files outside it that
still named a door at its old flat address.

### What moved

**4,759 call sites across 759 files**, resolved against the filesystem and never
guessed: a reference was repointed **only where exactly one door on disk carried
that basename**. **951 distinct dead references, 951 unique destinations, zero
ambiguous.**

| area | files |
|---|---|
| `.agents` (skills, tests, assets) | 317 |
| `docs` | 226 |
| `data` | 93 |
| `src` | 40 |
| `RULES`, `apps`, `packaging`, `assets` | 44 |

### Deliberately NOT touched

| | why |
|---|---|
| `.agents/backend/fm-*` · `bin/backend/fm-*` · `assets/reference/` | **upstream vendored material.** It names the upstream shape (`fm-*`, `bin/backends/*`) on purpose, the same way `fm-*` names appear in fix notes as provenance. Repointing it would make a vendored copy lie about its own origin |
| `docs/fixes/**` | **Rule 06.** A fix note records a path as it *was*. Rewriting 11 of them would falsify the record |
| fixtures naming files that must NOT exist | `bin/whatever.sh`, `bin/thing.sh`, `bin/placeholder.sh` — they exist to be absent |

### The finding worth the Allfather's attention

**Six doors that live callers still invoke no longer exist anywhere in `bin/`:**

`bin/brokk-control.sh` · `bin/changelog-guard.sh` · `bin/brokk-watch.sh` ·
`bin/brokk-gate-refuse-lib.sh` · `bin/ymir-visualizer.sh` ·
`bin/brokk-claude-stop-autoarm.sh`

They are referenced by **live doors and live skills** — `bin/agents/brokk-classify-lib.sh`,
`bin/agents/brokk-lease-lib.sh`, `bin/time/brokk-wake-lib.sh`, `bin/desktop/smidja-board.sh`,
`bin/gates/guards/branch-guard.sh`, and the `syn-recovery`, `urdh-hold`, `vor-diagnostics`,
`hvild-afk` and `nornir-schedule` skills.

**Only `changelog-guard.sh` has a recorded deletion** (`ac1131b9`, with no rename).
The other five have no deletion and no rename: they are simply absent.

**That is not a path problem and this sweep cannot fix it.** It is the question the
Allfather asked — *can we lose features from those files?* — and the honest answer is
that the restructure appears to have **removed** several, and a caller pointing at a
removed door fails the same silent way a moved one did: exit 127, no output, and
every listing still correct.

**Not guessed, not restored.** Which of the six is live and which was retired on
purpose is a decision, not a sweep.

### Verified

```
bin/gates/capabilities.sh --check   PASS
bin/gates/inventory.sh --check      PASS
bash bin/pi/syn-watch-arm.sh        started, attached, exit 0
19 extensions · 0 load errors · 32 tools · 0 double-registered
```

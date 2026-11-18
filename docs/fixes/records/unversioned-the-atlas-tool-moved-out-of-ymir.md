## records · unversioned · 2026-11-18 — the atlas tool and its pages moved out of Ymir

### Why
The Allfather: the atlas map is Atlas's, not Ymir's, and neither project carries the other (RULES/58).

### Files
- `bin/records/atlas.py`, `bin/records/atlas.sh`, `docs/features/the-atlas.md`, `docs/features/_catalogue/entries/02-109-the-atlas.md` (moved out)
- `bin/records/INDEX.md`, `.agents/assets/agents/subsystem-docs.md`, `docs/runbooks/agents.md`, `docs/runbooks/send-an-eindri.md`, `bin/agents/eindri-bearings.sh`, `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md`
- `docs/fixes/records/unversioned-the-atlas-tool-moved-out-of-ymir.md`

### What
The four files were moved whole into the home at `hodd/reference/atlas-moved-from-ymir/` (RULES/11: a move, never a delete). Every reference was removed: the register rows, the two runbook phrases, the line in `eindri-bearings.sh` that printed `hodd/ATLAS.md`. The runtime asset gains a dated correction rather than an edit. Older fix notes that name the atlas stay as the record.

### Verified
`git grep -iw atlas` outside fix notes, `apps/` and `systems/` finds only the one historical line in the runtime asset, which the appended correction covers. `bash -n` is clean on `eindri-bearings.sh`. The three `apps/`/`systems/` hits say "Atlassian" (Jira) and are not this.

## CHANGE LOG

- **2026-11-18** — opened.

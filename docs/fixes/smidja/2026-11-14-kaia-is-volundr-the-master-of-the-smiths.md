## smidja · 2026-11-14 — Kaia is Völundr, the master of the smiths, in every window that spells his name

### Why

The Allfather, reading the smithy's chat: *"find everywhere we mention Kaia and update so he's the
master of the smiths."* Asked for the name, he answered **Völundr** — the figure the lore already
carried as *Wayland the Smith*, the smithy's master craftsman. The house had been writing two names
for one figure: **Kaia** (the eye by the well, Ymir-wide orchestration) in the halls, the docs and the
skills, and **Völundr** (the smithy's own master) inside Smíðja. Two names for one hand is how a
person cannot tell who spoke.

Measured before the change: `git grep -iw kaia` returned **471 lines in 136 tracked files** — 37 under
`apps/smidja-factory`, 20 fix notes, 11 in Hlidskjalf, 8 skills, the lore table in `AGENTS.md` and
`docs/lore.md`, four migrations, `bin/bridge`, `bin/records`, `assets/reference`.

### What changed

One figure, one name, in everything a person or an agent reads.

| Surface | Before | After |
|---|---|---|
| OmniChat panel | *Kaia — oracle by the well* | **Völundr — master of the smiths** |
| OmniChat deck and empty state | *Speak with Kaia · she drinks…*, *Ask Kaia anything. She recalls…* | *Speak with Völundr · he drinks…*, *Ask Völundr anything. He recalls…* |
| Hall lane hint | *Kaia · orchestration* | *Völundr · the smiths* |
| Hlidskjalf lore and metadata | *From the well speaks Kaia… She does not act on faith* | *From the well speaks Völundr, the master of the smiths… He does not act on faith* |
| Smíðja chat header | *talk to Kaia · start smidja sessions* | *talk to Völundr · start smidja sessions* |
| Smíðja chat bubbles | author label *Kaia* | author label **Völundr** |
| Smíðja chat persona | `prompts/kaia.md` — *You are Kaia, the voice of the Smíðja* | `prompts/volundr.md` — *You are Völundr, the master of the smiths…* |
| Smíðja settings | *Orchestrator name (Kaia)* | *Orchestrator name (Völundr)* |
| Her memory view | *Kaia's memory* | *Völundr's memory* |
| The smithy's errors | *Kaia (Pi) failed…*, *kaia memory bridge unreachable* | *Völundr (Pi) failed…*, *Völundr's memory bridge unreachable* |
| `AGENTS.md` lore table | *Kaia — the eye that remembers* | *Völundr — the master of the smiths…* |
| `docs/lore.md` §II, §IV, §V, tenets 8–9, the Long Table | *Kaia*, described as two seats and two roles | *Völundr*, one figure: he leads Smíðja, dispatches its smiths, and drinks before every dispatch |
| Skills, templates, `bin/`, `systems/`, `mimirswell`, the mock seeds, the feature page | *Kaia* | *Völundr* |

**The record is appended, never rewritten** (RULES/06). `AGENTS.md` and `docs/lore.md` each gained a
dated section naming the change and listing the identifiers kept on purpose; the live prose above them
names the figure truly, and the old name survives in the dated section as history. Fix notes, the
migrations and `assets/reference/` are the record of what was believed and are untouched.

### The names that keep the old spelling, on purpose

A caller or a file on disk depends on each of these; renaming any of them would break a feature, a
stored row or a well's worth of memory.

| Identifier | Why it keeps `kaia` |
|---|---|
| `hodd/memory/kaia.engram` (+ `-wal`, `-shm`) | the well's store on disk — every episode the house remembers lives in that file |
| `VOLUNDR_MEMORY_URL`, then `KAIA_MEMORY_URL` | read first, then the historical name: the three `volundr-*.py` scripts, the smithy's orchestrator template and the visualizer's server all accept both |
| `VOLUNDR_PERSONA`, then `KAIA_PERSONA` | the explicit persona file: the new name is preferred, the old still works |
| `prompts/volundr.md`, then `prompts/kaia.md`; `.agents/skills/smidja/volundr/persona.md`, then `…/kaia/persona.md` | the persona ladder reads the new path, then the old one, so an existing home or target repo still answers |
| `kaiaPersonaFile` | the exported function's old name, kept as an alias so a wrapper or a test written before today still compiles |
| `SMIDJA_KAIA`, `kaia_tier`, `--kaia`, `--kaia-tier`, `KAIA_CONFIG`, `scripts/smidja kaia`, `kaia_notes.md`, `kaia-handoff.py`, `kaia-memory-bridge.py` | the smithy's own tier contract, verbs and files, already set by rosters, scripts and documented commands |
| `role: "kaia"` / `from: 'kaia'` / `.bubble.kaia` | the stored role of every chat row already written; the UI renders it as Völundr |
| `ENGRAM_AGENT_ID` default `"kaia"` | the agent name every episode in the well already carries |
| `WOTEAMS_AGENT_NAME` default `kaia-chat` | the registration name already in the external Teams registry |

### Proof

- **The real windows, read through the DevTools protocol.**
  - OmniChat, `--remote-debugging-port=9311` over a real Electron window on the worktree's build:
    `.panel-title` reads *ᚴ VÖLUNDR — MASTER OF THE SMITHS*, the deck reads *Speak with Völundr · he
    drinks from the well before every dispatch*, and `document.body.innerText` contains no `Kaia`.
  - Smíðja's chat, `--remote-debugging-port=9312`: the header reads *talk to Völundr · start smidja
    sessions*, the bubble author labels are *You* and *Völundr*, and no heading, crumb, label or
    placeholder contains `Kaia`.
- **One `Kaia` remains visible in an old thread, and it is data, not UI:** a reply stored before today
  says *"I am Kaia, the smithy's voice"*. The chat keeps its history; every new reply speaks as
  Völundr.
- **`git grep -iw kaia`** after the change: **301 lines in 97 files**, every one accounted for — 120 are
  other errands' history (fix notes, `assets/reference`, the migrations, the generated `bin/time/INDEX.md`),
  31 are this note's own record of the old name, 66 are the store path `kaia.engram`, and 84 are the
  documented identifiers and the two dated sections in `AGENTS.md` and `docs/lore.md`.
- **`vue-tsc --noEmit`** clean and **`bun test` 25 pass / 0 fail** in the visualizer (including four
  new cases pinning the aliases: `KAIA_PERSONA` still read, `VOLUNDR_PERSONA` preferred, the
  historical home path still read, the shipped default found).
- **`tsc --noEmit`** clean in Hlidskjalf; the built bundle carries *Völundr — master of the smiths* and
  no `Kaia`; the visualizer's rebuilt `dist/` carries seven `Völundr` and no `Kaia`.

### Owed

A new identifier is spelled `volundr`; the old spellings stay only for what already exists.

`apps/hlidskjalf/src/data/realms.ts` (the lane hint) and `src/state/store.ts` (the stored role) are
also edited by `eindri/hall-follow`, so a rebase of this branch against that errand lands both hunks
by hand — they are one line each.

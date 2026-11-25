Read when: looking for a skill, an asset, the owner of a path, or the rule that governs a task — before editing governed code.

# The manual: skills, assets, governed paths and the rules

Part of the Ymir contract. The prior text is kept verbatim in `docs/contract-history/AGENTS-2026-11-24.md`.

## The skill shelves, and how to find one

**Nothing is preloaded.** A session that reads every skill acts like it read
none. So a skill is *found* on demand and read then:

```bash
bash bin/agents/skill-find.sh "the words you would use"   # search the descriptions
bash bin/agents/skill-find.sh --list                       # every skill, one line each
bash bin/agents/skill-find.sh --where <name>               # the exact path
bash bin/agents/skill-find.sh --check                      # duplicates, unfindable skills
```

**Four shelves, searched in order, first hit wins:**

| # | Shelf | Who it is for |
|---|---|---|
| 1 | `.agents/skills/` | **ships** with the repo and the npm package — the project's craft |
| 2 | `.agents/skills-local/` | **this machine only.** Gitignored, never published, never cloned |
| 3 | `~/Documents/ymirhome/.agents/skills/` | **the Allfather's own projects** — `example-1` and the rest of the business |
| 4 | `~/.pi/agent/skills/` | yours, harness-wide, across projects |

**A shipped skill always beats a local one on purpose.** The project's craft
must be the same on every machine, or two developers get two different answers.

**A skill is unfindable without a one-line `description:` in its front matter.**
`--check` names the ones that have none, and they get fixed before they ship.

For any craft, load the `ymir` skill and follow its index (plan 248, RULES/51). It is the one Ymir skill in the root
(`~/.agents/skills/ymir`; Claude reads it as `~/.claude/skills/ymir`), and its body names every skill on every shelf by
path.

## The manual (load the row the task needs)

| asset | path | load_when |
|---|---|---|
| naming | `.agents/assets/agents/naming.md` | naming any subsystem / component map |
| registry | `.agents/assets/agents/registry.md` | skills, assets, tools, commands inventories |
| runtime | `.agents/assets/agents/runtime.md` | how Ymir boots / supervises the primary |
| toon-tasks | `.agents/assets/agents/toon-tasks-cli.md` | building agent-facing output / tasks-cli |
| installation | `.agents/skills/galdr-ymirsystem/assets/installation.md` | changing bin/engine/ymir-install.sh, engines, first setup |
| ui | `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md` | any change under apps/hlidskjalf |
| hall | `.agents/skills/galdr-ymirsystem/assets/odrerir-hall.md` | any change under apps/odrerir |
| runtime-spec | `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md` | the runtime, digest, lock, supervision, cron |
| harness | `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md` | the Pi/OpenCode surfaces: extensions, commands, shortcuts |

**Ask before you read the code:** `bin/records/where.sh <path>` prints the entry skill, the canonical doc, the books, the
doors and **what this tree is missing** for any governed path (`.agents/assets/agents/subsystem-docs.md`; gated by
`subsystem-docs-guard`). Other doors: `bin/records/mimir.sh recall "<what you are about to do>"` (what the house already
learned) and `bin/gates/fixes.sh list` (the fix notes).

## Governed paths: load the asset before you edit the code

Every subsystem below has an owning asset; a code change not reflected in its asset is an incomplete change. The router
is `.agents/skills/galdr-ymirsystem/SKILL.md` (its `assets[]` table maps every task to its file). Deep doctrine and the
full asset index: `.agents/skills/galdr-ymirsystem/SKILL.md` and `.agents/skills/galdr-ymirsystem/assets/README.md`.
Óðrerir has left for its own repo, so its row (once `apps/odrerir/**`) now names the hall-snapshot job that still
writes its board.

| path | load_first |
|---|---|
| `bin/engine/ymir-install.sh` | `.agents/skills/galdr-ymirsystem/assets/installation.md` |
| `src/ymir_runtime/** \| bin/engine/ymir-engine*.sh \| bin/agents/einherjar-spawn.sh \| bin/agents/eindri-start.sh` | `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md` |
| `apps/hlidskjalf/**` | `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md` |
| `systems/snotra/services/cron/hall-snapshot.sh \| bin/time/nornir-job-hall-snapshot.sh` | `.agents/skills/galdr-ymirsystem/assets/odrerir-hall.md` |
| `bin/records/mimir*.sh \| bin/bridge/mimir-bridge.py` | `.agents/skills/galdr-ymirsystem/assets/memory-well.md` |
| `bin/time/nornir-* \| config/cron.yaml*` | `.agents/skills/galdr-ymirsystem/assets/nornir-jobs.md` |
| `bin/seat/valknut-load.sh \| .pi/** \| .opencode/**` | `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md` |
| `RULES/13-pi-extensions.md` | governs the Pi extension surface: one home, index.ts per multi-file extension, no thin loaders |
| `bin/desktop/smidja* \| scripts/smidja` | `.agents/skills/galdr-ymirsystem/assets/smidja.md` |
| `systems/snotra/services/ear/** \| bin/time/snotra/calendar-write.sh` | `.agents/skills/galdr-ymirsystem/assets/snotra-meeting-ear.md` |
| `tools/snotra/**` | `.agents/skills/galdr-ymirsystem/assets/snotra-meeting-ear.md` |

## The rules (law)

`RULES/` holds the numbered house law; read the rule that governs the task. A change that contradicts a rule must change
the rule first (append-only). These are the rules a task most often needs; `RULES/README.md` indexes them all.

| file | governs |
|---|---|
| `RULES/01-domains.md` | domains (Greinar) · houses · Eindri |
| `RULES/02-agents.md` | agents: .agents/agents is canonical; harness dirs are symlinks; no mock |
| `RULES/03-houses.md` | a house is a company (WayOf); domains are never houses |
| `RULES/05-platforms.md` | one portable core, per-OS installation layers; a core change updates every layer |
| `RULES/06-append-only.md` | the ledger, the changelog, the log and the rules: append, never rewrite, never lose on a move |
| `RULES/07-config.md` | configuration is never hardcoded: ports, hosts, paths, credentials resolve from env/config with one documented default |
| `RULES/13-pi-extensions.md` | Pi extensions: one home per extension, pi's layout (a directory needs index.ts), and valknut-load --check as the gate — two load paths seats nobody |
| `RULES/25-agnostic-by-construction.md` | one core, every device: probe never assume, a clean skip is a pass, a move is a migration |
| `RULES/24-the-ward.md` | the ward: a door is named or closed; nothing public without a credential; keys not passwords; the audit is a cron |
| `RULES/20-the-well-appends.md` | the well appends: an episode is never replaced, rebuilt-over or lost to a restore; the count never falls |
| `RULES/23-no-code-in-app-folders.md` | an application lives in apps/; bin/ holds function-named machine tools — never an application's name in a path |
| `RULES/43-two-tongues.md` | the tongue: English for the work, Old Norse for the names — nothing else inside Ymir; a native project keeps its tongue in its own scope |
| `RULES/44-no-agent-is-brokk.md` | no agent is Brokk — every machine names its own agents, and every agent declares house · fleet · machine · Allfather; unsealed means unnamed |

## CHANGE LOG

- **2026-11-25** — written when the contract was split by topic (plan 369 item 7); its text is folded from the
  sections of the prior `AGENTS.md`, kept verbatim in `docs/contract-history/AGENTS-2026-11-24.md`.
